# Application 层编码指令

## 编码要求

### Command
- 不可变数据结构
- 不含业务逻辑
- 命名：`{操作名}Command`

### 应用服务
- 构造函数注入依赖
- **薄薄一层，只做编排不做计算**
- 一个公有方法对应一个业务用例
- **返回类型使用领域层模型**，禁止创建 DTO 类

### 事务
- 写操作需事务，查询用只读事务
- 事务方法内不做 RPC/消息等耗时 I/O

### 通用
- 构造函数注入依赖
- 禁止包含业务规则
- 禁止直接操作数据库
- 禁止依赖 OHS 层
- 禁止定义 DTO 类

## 项目结构探索

先用 Glob 搜索（根据 CONTEXT 中的 backend_language 选择扩展名）：
- `**/application/**/*.{ext}` — 找到 application 包路径
- `**/domain/**/repository/*.{ext}` — 找到可注入的 Repository
- `**/domain/**/service/*.{ext}` — 找到可注入的 Domain Service

## 完成标准

- Command 和 ApplicationService 都已创建
- 编排步骤与设计文档一致
- 事务注解正确
- 代码可编译/运行，符合 backend-spec application 规范

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "业务规则放这里更方便" | Application 层只做编排；一旦发现业务规则上浮，必须回沉到实体、值对象或领域服务 |
| "直接调 ORM/数据库更快" | 必须通过 Repository，禁止直接操作数据库 |
| "这个方法不需要事务" | 每个公有方法都必须有事务管理，查询用只读事务 |
| "返回值用 DTO 包装更清晰" | Application 层返回领域模型，DTO 封装由 OHS 层负责，禁止在本层创建 DTO |
| "用框架字段注入也行" | 必须构造函数注入依赖 |
