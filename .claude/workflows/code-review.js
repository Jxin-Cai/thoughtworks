export const meta = {
  name: 'code-review',
  description: '对 Worker 产出的代码进行多维对抗审查和自动修复（compliance + correctness + testability + convention）',
  phases: [
    { title: 'CR', detail: '4 维度并行 code review' },
    { title: 'Verify', detail: '逐 finding 对抗验证' },
    { title: 'Fix', detail: '串行修复 + 回归检查' },
  ],
}

const CR_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    dimension: { type: 'string' },
    result: { type: 'string', enum: ['pass', 'has_findings'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          id: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'major', 'minor'] },
          file: { type: 'string' },
          line: { type: 'string' },
          summary: { type: 'string' },
          failureScenario: { type: 'string' },
        },
        required: ['id', 'severity', 'file', 'summary'],
      },
    },
  },
  required: ['dimension', 'result', 'findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    findingId: { type: 'string' },
    verdict: { type: 'string', enum: ['TRUE_POSITIVE', 'FALSE_POSITIVE', 'UNCERTAIN'] },
    evidence: { type: 'string' },
  },
  required: ['findingId', 'verdict', 'evidence'],
}

const REGRESSION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    verdict: { type: 'string', enum: ['CLEAN', 'REGRESSION_FOUND', 'UNCERTAIN'] },
    issues: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict'],
}

const {
  designPath,
  codePaths = [],
  conventionsPath,
  subdomain,
  language,
  mode = 'standard',
  ideaDir,
} = args ?? {}

if (!designPath || !subdomain || !language) {
  throw new Error('args.designPath, args.subdomain, and args.language are required')
}

const codeGlobs = codePaths.length > 0
  ? codePaths.join(', ')
  : `**/domain/**/*.*, **/infr/**/*.*, **/application/**/*.*, **/ohs/**/*.*`

const DIMENSIONS = [
  {
    key: 'compliance',
    prompt: `You are a design-compliance reviewer. Your SOLE focus: does the code faithfully implement the design document?

Read the design document at: ${designPath}
Then use Glob/Grep to find and read the implementation files matching: ${codeGlobs}

Check:
1. Every class/interface in the design's implementation checklist has a corresponding source file
2. Method signatures match the design (name, parameters, return type)
3. Files are in the correct package/module matching their layer (domain/, infr/, application/, ohs/)
4. Import/dependency direction follows P7 (no upward imports: domain must not import infr/application/ohs)
5. Application layer orchestration matches the designed flow

Report ONLY concrete deviations. Do NOT report things that are intentionally left for Worker to infer (field details, DDL specifics).
Issue IDs: compl:001, compl:002, etc.`,
  },
  {
    key: 'correctness',
    prompt: `You are a correctness reviewer. Your SOLE focus: runtime defects that would cause failures.

Use Glob/Grep to find and read implementation files matching: ${codeGlobs}

Look for:
1. Null/nil pointer risks — returned values that could be null used without checking
2. Boundary conditions — empty collections passed to operations expecting non-empty, zero/negative values
3. Resource leaks — database connections, file handles, HTTP clients not properly closed
4. Concurrency issues — shared mutable state without synchronization (if applicable)
5. Logic errors — conditions that don't match the intended business rule

For each finding, describe a CONCRETE failure scenario: specific inputs → specific wrong behavior.
Do NOT report style issues, naming preferences, or theoretical concerns without a concrete failure path.
Issue IDs: corr:001, corr:002, etc.`,
  },
  {
    key: 'testability',
    prompt: `You are a testability reviewer. Your SOLE focus: can the code be unit-tested without heroics?

Use Glob/Grep to find and read implementation files matching: ${codeGlobs}

Check:
1. Domain layer classes have NO framework annotations/decorators that prevent plain instantiation
2. All dependencies are injected via constructor (not field injection, not static access, not service locator)
3. No hidden dependencies (calling static methods that reach external systems)
4. Application services can be tested by mocking only Repository interfaces
5. No God-objects that combine too many responsibilities to test in isolation

Report only STRUCTURAL issues that make testing genuinely difficult. Do NOT report "no tests exist" (that's Worker's next step, not a finding).
Issue IDs: test:001, test:002, etc.`,
  },
  {
    key: 'convention',
    prompt: `You are a ${language} convention reviewer. Your SOLE focus: language-specific conventions and framework best practices.

Read the conventions document at: ${conventionsPath || `skills/backend-principles/references/${language}/conventions.md`}
Then use Glob/Grep to find and read implementation files matching: ${codeGlobs}

Check against the conventions document:
1. Naming patterns (package/module names, class names, method names, variable names)
2. Exception handling (correct exception hierarchy, proper use of framework exception handling)
3. Transaction management (annotations/decorators in correct layer and scope)
4. API conventions (RESTful patterns, response wrapping, status codes)
5. Framework-specific patterns (DI configuration, ORM usage, middleware setup)

Only report violations of explicitly stated conventions in the conventions document. Do NOT invent new rules.
Issue IDs: conv:001, conv:002, etc.`,
  },
]

log(`code-review: ${subdomain} [${language}] [${mode}] — starting ${DIMENSIONS.length}-dimension CR`)

// Phase 1: Parallel Code Review
phase('CR')
const crResults = await parallel(DIMENSIONS.map(d => () =>
  agent(d.prompt, {
    label: `cr:${d.key}`,
    phase: 'CR',
    schema: CR_SCHEMA,
    effort: 'high',
  })
))

const validCr = crResults.filter(Boolean)
const allFindings = validCr.flatMap(r => r.findings || [])
const criticalOrMajor = allFindings.filter(f => f.severity === 'critical' || f.severity === 'major')

log(`CR complete: ${allFindings.length} total findings, ${criticalOrMajor.length} critical/major`)

if (allFindings.length === 0) {
  return { status: 'pass', summary: 'All 4 dimensions passed with no findings.' }
}

// Phase 2: Adversarial Verification (skip in light mode or low budget)
if (mode === 'light' || budget.remaining() < 50000) {
  log(mode === 'light' ? 'light mode: skipping verification' : 'budget low: skipping verification')
  if (criticalOrMajor.length === 0) {
    return { status: 'pass', summary: `${allFindings.length} minor findings only — passing.` }
  }
  return {
    status: 'needs_fix',
    findings: criticalOrMajor,
    summary: `${criticalOrMajor.length} unverified findings (verification skipped).`,
  }
}

phase('Verify')
const verified = await pipeline(criticalOrMajor, finding =>
  agent(
    `You are an adversarial verifier. Your job is to REFUTE this finding if possible.

Finding: "${finding.summary}"
File: ${finding.file}${finding.line ? ` (around line ${finding.line})` : ''}
Claimed failure scenario: ${finding.failureScenario || 'not specified'}

ACTIVELY search for REFUTING evidence:
- Does the framework handle this automatically? (e.g., Spring's @Transactional rollback, FastAPI's dependency injection)
- Is there a parent class/interface that provides this behavior?
- Is there configuration elsewhere that addresses this?
- Is the "failure scenario" actually prevented by a guard in another layer?

Read the actual source file and its dependencies. Return:
- TRUE_POSITIVE: You found no refuting evidence, the issue is real
- FALSE_POSITIVE: You found clear evidence the issue doesn't exist or is handled
- UNCERTAIN: Ambiguous — retain conservatively`,
    {
      label: `verify:${finding.id}`,
      phase: 'Verify',
      schema: VERDICT_SCHEMA,
    }
  )
)

const validVerified = verified.filter(Boolean)
const dismissed = validVerified.filter(v => v.verdict === 'FALSE_POSITIVE').map(v => v.findingId)
const confirmed = criticalOrMajor.filter(f => !dismissed.includes(f.id))

log(`verification: ${dismissed.length} dismissed, ${confirmed.length} confirmed`)

if (confirmed.length === 0) {
  return { status: 'pass', summary: `All ${criticalOrMajor.length} findings dismissed after adversarial verification.` }
}

// Phase 3: Auto-Fix (skip if budget too low)
if (budget.remaining() < 80000) {
  log('budget below fix threshold; reporting without fixing')
  return {
    status: 'needs_fix',
    findings: confirmed,
    summary: `${confirmed.length} confirmed findings, budget insufficient for auto-fix.`,
  }
}

phase('Fix')
const fixResults = []

for (const finding of confirmed) {
  const fix = await agent(
    `Fix the following confirmed code issue.

Issue: ${finding.summary}
File: ${finding.file}${finding.line ? ` (line ${finding.line})` : ''}
Dimension: ${finding.id.split(':')[0]}
Failure scenario: ${finding.failureScenario || 'see summary'}

Rules:
- Read the file, understand the context, make the MINIMAL change to fix this specific issue
- Do NOT refactor beyond what's needed for the fix
- Do NOT change public API signatures unless the design document requires it
- If the fix requires changing the design, do NOT proceed — report that this needs escalation

Read the design document at ${designPath} to ensure your fix stays aligned with the intended design.
After fixing, verify the file is syntactically valid.`,
    { label: `fix:${finding.id}`, phase: 'Fix' }
  )

  const regression = await agent(
    `Check whether the fix for ${finding.id} introduced any regression.

Read the modified file: ${finding.file}
Read nearby files that depend on or are depended by this file (check imports/exports).

Verify:
1. The fix addresses the original issue (${finding.summary})
2. No new compilation/syntax errors introduced
3. No behavioral change to OTHER functionality in the same file
4. Import/export relationships still valid
5. If tests exist for this file, they would still pass conceptually

Return CLEAN if the fix is safe. Return REGRESSION_FOUND with specific issues if not.
When uncertain, lean toward CLEAN — minor issues are acceptable.`,
    { label: `check:${finding.id}`, phase: 'Fix', schema: REGRESSION_SCHEMA }
  )

  if (regression && regression.verdict === 'REGRESSION_FOUND') {
    fixResults.push({ findingId: finding.id, status: 'blocked', issues: regression.issues })
    log(`regression found after fixing ${finding.id} — stopping fix chain`)
    break
  }
  fixResults.push({ findingId: finding.id, status: 'fixed' })
}

const blocked = fixResults.some(r => r.status === 'blocked')
const fixedCount = fixResults.filter(r => r.status === 'fixed').length

return {
  status: blocked ? 'blocked' : 'fixed',
  fixedCount,
  totalConfirmed: confirmed.length,
  fixResults,
  summary: blocked
    ? `Fixed ${fixedCount}/${confirmed.length}, blocked by regression on ${fixResults.find(r => r.status === 'blocked').findingId}`
    : `All ${fixedCount} confirmed findings fixed successfully.`,
}
