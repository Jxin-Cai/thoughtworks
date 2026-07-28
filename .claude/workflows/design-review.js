export const meta = {
  name: 'design-review',
  description: '对 Thinker 产出的设计文档进行多维对抗审查（architecture + completeness + implementability）',
  phases: [
    { title: 'Review', detail: '3 维度并行独立评审' },
    { title: 'Verify', detail: '盲验证消除确认偏差' },
    { title: 'Verdict', detail: '综合裁决产出修改指令' },
  ],
}

const REVIEW_SCHEMA = {
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
          location: { type: 'string' },
          summary: { type: 'string' },
          detail: { type: 'string' },
        },
        required: ['id', 'severity', 'location', 'summary'],
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

const VERDICT_RESULT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    status: { type: 'string', enum: ['pass', 'revise'] },
    modifications: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          target: { type: 'string' },
          action: { type: 'string' },
          reason: { type: 'string' },
        },
        required: ['target', 'action', 'reason'],
      },
    },
    summary: { type: 'string' },
  },
  required: ['status', 'modifications', 'summary'],
}

const { designPath, requirementPath, principlesPath, subdomain, language, mode = 'standard' } = args ?? {}

if (!designPath || !subdomain) {
  throw new Error('args.designPath and args.subdomain are required')
}

const DIMENSIONS = [
  {
    key: 'architecture',
    prompt: `You are a DDD architecture compliance reviewer. Your SOLE focus is whether the design violates DDD architectural principles (P1-P7).

Read the design document at: ${designPath}
Read the architecture principles at: ${principlesPath || 'skills/backend-principles/references/architecture.md'}

For each of the 7 principles (P1 Domain Independence, P2 Dependency Inversion, P3 Rich Domain Model, P4 Thin Application Layer, P5 Infrastructure as Servant, P6 OHS as Translator, P7 Unidirectional Flow):
- Check if the design violates the principle
- A violation means the design INSTRUCTS something that would break the principle when implemented

Only report actual violations with specific evidence from the design text. Do NOT report style preferences or optimization suggestions.
Issue IDs must use format: arch:001, arch:002, etc.`,
  },
  {
    key: 'completeness',
    prompt: `You are a requirements coverage reviewer. Your SOLE focus is whether the design covers all required functionality.

Read the design document at: ${designPath}
Read the requirement document at: ${requirementPath || 'requirement.md'}

Check:
1. Every business capability in the requirement has a corresponding design element (domain model, use case, or API endpoint)
2. The implementation checklist at the end covers ALL classes/interfaces mentioned in the design body
3. Repository interfaces have corresponding usage in Application layer
4. Domain events (if any) have both publish and consume paths designed
5. Cross-subdomain dependencies reference concrete interface signatures

Report ONLY genuinely missing items — not items that are implicitly covered or can be trivially inferred.
Issue IDs must use format: comp:001, comp:002, etc.`,
  },
  {
    key: 'implementability',
    prompt: `You are a Worker agent simulator. Your SOLE focus is: can a code-implementing agent produce correct code from this design WITHOUT guessing?

Read the design document at: ${designPath}

Pretend you must implement each item in the implementation checklist. For each one, mentally write the code. Flag anything where you would be FORCED to guess:
1. Method signatures missing parameter types or return types
2. Boundary conditions not specified (what happens on null input? empty collection? concurrent access?)
3. Cross-subdomain dependencies referencing interfaces whose signatures are not defined anywhere accessible
4. Database design lacking enough info to write DDL (missing field types, constraints, or relationships)
5. Application orchestration flows with ambiguous step ordering or missing error handling paths

Do NOT flag things a competent developer can reasonably infer from context (e.g., standard CRUD patterns, obvious field types).
Issue IDs must use format: impl:001, impl:002, etc.`,
  },
]

log(`design-review: ${subdomain} [${mode}] — starting ${DIMENSIONS.length}-dimension review`)

// Phase 1: Parallel Review
phase('Review')
const reviews = await parallel(DIMENSIONS.map(d => () =>
  agent(d.prompt, {
    label: `review:${d.key}`,
    phase: 'Review',
    schema: REVIEW_SCHEMA,
    effort: 'high',
  })
))

const validReviews = reviews.filter(Boolean)
const allFindings = validReviews.flatMap(r => r.findings || [])
const criticalOrMajor = allFindings.filter(f => f.severity === 'critical' || f.severity === 'major')

log(`review complete: ${allFindings.length} total findings, ${criticalOrMajor.length} critical/major`)

if (allFindings.length === 0) {
  return { status: 'pass', summary: 'All 3 dimensions passed with no findings.' }
}

// Phase 2: Blind Verification (skip in light mode or low budget)
if (mode === 'light' || budget.remaining() < 50000) {
  log(mode === 'light' ? 'light mode: skipping verification' : 'budget low: skipping verification')
  if (criticalOrMajor.length === 0) {
    return { status: 'pass', summary: `${allFindings.length} minor findings only — passing.` }
  }
  const confirmed = criticalOrMajor
  phase('Verdict')
  const verdict = await agent(
    `You are a design review judge. Based on these confirmed findings, decide whether the design needs revision.

Findings:
${JSON.stringify(confirmed, null, 2)}

Rules:
- If ANY critical finding exists → status: "revise"
- If 2+ major findings exist → status: "revise"
- Otherwise → status: "pass"

For each finding that requires revision, produce a modification instruction:
- target: which section of the design to change
- action: what specifically to do (add/change/remove)
- reason: why (one sentence)`,
    { label: 'verdict', phase: 'Verdict', schema: VERDICT_RESULT_SCHEMA }
  )
  return verdict || { status: 'pass', modifications: [], summary: 'Judge returned no result.' }
}

phase('Verify')
const verified = await pipeline(criticalOrMajor, finding =>
  agent(
    `You are an independent verifier. You must determine whether this finding is real or a false positive.

Finding claim: "${finding.summary}"
Location in design: "${finding.location}"
Severity claimed: ${finding.severity}

IMPORTANT: You have NOT seen the reviewer's reasoning. You must independently verify by reading the design.

Read the design document at: ${designPath}
Go to the location mentioned and determine:
1. Does the claimed issue actually exist in the design text?
2. Is it actually a problem (not just a style preference)?
3. Would it cause real harm if implemented as-is?

Default to TRUE_POSITIVE if genuinely uncertain. Only mark FALSE_POSITIVE if you have clear evidence the finding is wrong.`,
    {
      label: `verify:${finding.id}`,
      phase: 'Verify',
      schema: VERDICT_SCHEMA,
      effort: 'high',
    }
  )
)

const validVerified = verified.filter(Boolean)
const dismissed = validVerified.filter(v => v.verdict === 'FALSE_POSITIVE').map(v => v.findingId)
const confirmed = criticalOrMajor.filter(f => !dismissed.includes(f.id))

log(`verification complete: ${dismissed.length} dismissed, ${confirmed.length} confirmed`)

if (confirmed.length === 0) {
  return { status: 'pass', summary: `All ${criticalOrMajor.length} findings dismissed as false positives.` }
}

// Phase 3: Verdict
phase('Verdict')
const verdict = await agent(
  `You are the final judge for a design review of subdomain "${subdomain}".

Confirmed findings (survived blind verification):
${JSON.stringify(confirmed, null, 2)}

Produce a verdict:
- status "revise" if any critical finding exists OR 2+ major findings exist
- status "pass" otherwise

For "revise": produce specific modification instructions that a Thinker agent can execute.
Each modification must be actionable — tell the Thinker exactly what to change, not just "fix the issue".

Summarize in one sentence what the overall quality assessment is.`,
  { label: 'verdict', phase: 'Verdict', schema: VERDICT_RESULT_SCHEMA }
)

return verdict || { status: 'pass', modifications: [], summary: 'No actionable revisions needed.' }
