# 审查维度定义

本文件定义设计审查和代码审查的评审维度。Workflow 中的 reviewer agent 按此处的焦点和评判标准执行独立评审。

---

## 设计审查维度（design-review）

### architecture — DDD 架构合规性

**焦点**：设计是否遵守 DDD 7 条架构原则（P1-P7）。

**评判标准**：
- P1 Domain Independence：Domain 层设计是否含有任何框架依赖、基础设施引用
- P2 Dependency Inversion：仓储接口是否定义在 Domain 层、上层是否依赖 Domain 声明的抽象
- P3 Rich Domain Model：业务规则是否放在领域对象内，是否存在贫血模型迹象
- P4 Thin Application Layer：用例是否只做编排，是否混入了计算逻辑
- P5 Infrastructure as Servant：基础设施策略是否只实现 Domain 接口
- P6 OHS as Translator：接口层是否只做格式转换，是否混入业务判断
- P7 Unidirectional Flow：层间依赖方向是否严格向下

**输出**：对每条原则判定 pass/violation，violation 需标注具体位置和违反内容。

---

### completeness — 需求覆盖度

**焦点**：MISSION 工作项是否都有对应设计，实现清单是否覆盖完整。

**评判标准**：
- 每个 MISSION 工作项至少有一处设计对应（Domain 建模 / 用例 / API 端点）
- 实现清单表格是否覆盖了设计中提到的所有类/接口
- 领域事件是否有对应的发布和消费设计
- 仓储接口中声明的方法是否都有使用场景（不存在悬空接口）
- 导出契约表是否完整（跨子域依赖是否有对应签名）

**输出**：缺失项列表，每项标注缺失类型（missing_design / missing_in_checklist / orphan_interface）。

---

### implementability — Worker 可执行性

**焦点**：以 Worker 视角审查——拿到这份设计能否直接编码，无需猜测。

**评判标准**：
- 接口签名是否包含完整的入参和返回类型
- 边界条件是否有明确说明（空值、并发、幂等）
- 跨子域依赖是否可解析（依赖的接口签名是否已定义或可从其他设计文档获取）
- 数据库设计要点是否足以推导出完整 DDL（核心字段、约束、索引）
- 编排流描述是否明确步骤顺序和异常路径

**输出**：模糊点列表，每项标注模糊类型（ambiguous_signature / missing_boundary / unresolvable_dependency / insufficient_db_design）。

---

## 代码审查维度（code-review）

### compliance — 设计合规性

**焦点**：代码实现是否忠实于设计文档。

**评判标准**：
- 类名、方法签名是否与设计文档中的实现清单一致
- 层级归属是否正确（Domain 类在 domain 包、Infr 类在 infr 包）
- 依赖方向是否符合 P7（import 路径检查）
- 设计中的每个接口/类是否都有对应实现
- 设计中的编排流是否被正确翻译为代码

**输出**：偏差列表（deviation），每项标注类型（signature_mismatch / wrong_package / missing_impl / flow_deviation）。

---

### correctness — 逻辑正确性

**焦点**：代码是否存在可能导致运行时错误的逻辑缺陷。

**评判标准**：
- 空指针/空引用风险（可能为 null 的返回值未检查）
- 边界条件处理（空集合、零值、超长输入）
- 并发安全（共享可变状态、非线程安全集合）
- 资源泄漏（未关闭的连接/流、缺少 try-with-resources）
- 业务逻辑正确性（条件判断是否反映了领域规则）

**输出**：缺陷列表，每项含文件路径、行号范围、具体故障场景（inputs → wrong output）。

---

### testability — 可测试性

**焦点**：代码结构是否支持单元测试和集成测试。

**评判标准**：
- Domain 层是否可脱离框架独立测试（无 Spring/FastAPI/Gin 注解依赖）
- 依赖是否通过构造器注入（可 mock）
- 是否存在难以测试的静态方法调用或隐藏依赖
- Application Service 是否可通过替换 Repository mock 测试编排逻辑
- 领域事件是否可验证发布

**输出**：可测试性风险列表，每项含类名、具体难以测试的原因。

---

### convention — 语言约定合规

**焦点**：代码是否符合对应语言的技术栈约定（conventions.md）。

**评判标准**：
- 命名规范（包名/模块名、类名、方法名、变量名）
- 异常处理策略（是否遵循全局异常处理 + 业务异常体系）
- 事务管理（@Transactional / session 管理是否放在正确位置）
- API 风格（RESTful 规范、统一响应包装、状态码使用）
- 框架用法（注解/装饰器是否正确、DI 配置是否规范）
- 日志规范（是否使用结构化日志、级别是否恰当）

**输出**：违规列表，每项含具体规则引用（来自 conventions.md 的条目）。
