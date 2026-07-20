# Stronix App 整改执行单元拆解

本文把 `DEVELOPMENT_REMEDIATION_PLAN.md` 拆成可执行 ticket。它不是替代总计划，而是作为后续写 spec、建 issue、分配开发、执行验收的工作清单。

## 使用方式

- `Epic` 表示整体整改目标。
- `Phase` 表示按技术风险排序的阶段。
- `Ticket` 表示可独立评审、实现和验收的最小执行单元。
- 高风险 ticket 建议先用 `$to-spec` 生成阶段 spec，再实现。
- 低风险 ticket 可以直接实现，但仍要满足验收和测试要求。

## Epic：Stronix App 整体整改

### 目标

在不整体重写 App 的前提下，分阶段完成本地 SQLite 数据安全、架构边界、业务域收敛、UI 设计系统、资源治理、安全隐私、测试与 CI 的整体整改。

### 总体验收

- 本地 SQLite 升级不覆盖用户数据。
- View 不直接访问 SQLite。
- 关键业务域通过 ViewModel、UseCase、Repository Protocol 组织。
- 模板计划和用户计划长期模型分离。
- 核心流程具备按风险补齐的测试。
- UI token、通用组件、暗色模式、可访问性和本地化进入正式体系。
- 仓库噪音、资源路径和构建配置得到治理。

### 不做事项

- 不整体重写 App。
- 数据库整改先不处理 Supabase 迁移。
- 不一次性替换所有单例。
- 不以早期测试覆盖率百分比作为目标。
- 不在数据库安全稳定前做全仓大重构。

## Phase 0：基线冻结与整改护栏

### Ticket 0.1：创建整改基线

**背景**：后续整改跨度大，需要可回退起点。

**范围**：Git tag、当前提交记录、阶段起点说明。

**不做事项**：不修改业务代码。

**重点文件**：Git 历史、`DEVELOPMENT_REMEDIATION_PLAN.md`。

**实施步骤**：

1. 确认当前工作区干净。
2. 创建整改起点 tag，例如 `remediation-baseline-YYYYMMDD`。
3. 记录当前最新提交 hash。
4. 在执行记录中写明从该 tag 开始整改。

**验收标准**：

- 可以通过 tag 找到整改起点。
- 后续阶段能清楚 diff 到基线。

**测试要求**：无自动化测试要求。

**依赖**：无。

**风险**：tag 打错会影响回滚定位。

### Ticket 0.2：导出 SQLite 基线

**背景**：阶段 1 会处理 schema、外键、迁移，需要先固定旧库事实。

**范围**：schema dump、表列表、外键检查、关键表行数。

**不做事项**：不修复数据库。

**重点文件**：`Stronix-App/Resources/Database/database_stronix.db`。

**实施步骤**：

1. 导出 `.schema`。
2. 导出 `PRAGMA foreign_keys`、`PRAGMA integrity_check`、`PRAGMA foreign_key_check`。
3. 导出关键表行数：用户、动作、训练计划、计划动作、计划组、训练历史、体测。
4. 保存到 `docs/remediation/database-baseline.md` 或同类文件。

**验收标准**：

- 基线文档能说明当前数据库状态。
- 明确记录已有外键违规和脏数据。

**测试要求**：命令输出可复现。

**依赖**：Ticket 0.1。

**风险**：只看 Bundle DB 可能遗漏 Documents DB 用户数据场景；后续测试要补真实用户库样本。

### Ticket 0.3：建立手动回归清单

**背景**：当前自动化测试不足，阶段早期必须靠稳定手动回归兜底。

**范围**：核心用户路径和阶段验收模板。

**不做事项**：不写 UI 自动化测试。

**重点文件**：`docs/remediation/manual-regression.md`。

**实施步骤**：

1. 写明启动、登录、创建计划、编辑计划、开始训练、完成训练、查看历史、新增体测路径。
2. 为每条路径定义预期结果。
3. 增加阶段验收记录模板：日期、设备、构建、通过项、失败项、备注。

**验收标准**：

- 每个阶段完成时都有统一手动验收入口。
- 失败项能被记录为后续 ticket。

**测试要求**：执行一次当前版本冒烟测试并记录结果。

**依赖**：Ticket 0.1。

**风险**：手动清单过宽会拖慢每次提交；初版只保留核心路径。

## Phase 1：本地 SQLite 数据安全与升级策略

### Ticket 1.1：加固 SQLite 连接配置

**背景**：当前数据库连接未明确开启外键约束，`foreign_keys` 查询为 `0`。

**范围**：连接建立后的 PRAGMA 配置和启动诊断日志。

**不做事项**：不修复 schema，不启用整套 migration。

**重点文件**：`DatabaseManager.swift`。

**实施步骤**：

1. 在 `Connection` 创建后执行 `PRAGMA foreign_keys = ON`。
2. 设置 `busy_timeout = 5000`。
3. 评估 `journal_mode = WAL`，如启用需记录原因和影响。
4. 增加启动诊断日志：foreign keys、journal mode、database path。

**验收标准**：

- App 初始化后 foreign keys 状态为开启。
- 数据库连接失败时错误上下文清楚。
- 现有业务路径仍可启动。

**测试要求**：

- 单元或集成测试验证连接配置。
- 手动启动 App 验证数据库可用。

**依赖**：Phase 0。

**风险**：开启外键后旧脏数据可能导致写入失败；需要与 Ticket 1.4 协同。

### Ticket 1.2：停止整库覆盖式升级

**背景**：当前升级逻辑会删除 Documents DB 并复制 Bundle DB，有覆盖用户数据风险。

**范围**：`UpdateService` 的更新策略保护。

**不做事项**：不立即实现全部 migration。

**重点文件**：`UpdateService.swift`、`VersionService.swift`。

**实施步骤**：

1. 禁止默认路径删除 Documents DB。
2. 将强制覆盖逻辑降级为开发调试能力，并加明显保护。
3. 为正式升级入口预留 migration runner 调用点。
4. 保留备份逻辑，但失败必须阻止升级继续执行。

**验收标准**：

- App 更新路径不会自动覆盖用户数据库。
- 强制覆盖只能在明确调试入口触发。
- 失败时不会留下半替换数据库。

**测试要求**：

- 模拟旧 Documents DB 存在时，升级不删除用户数据。
- 模拟备份失败时，升级停止。

**依赖**：Ticket 1.1 可并行，但应在 migration 前完成。

**风险**：版本检查逻辑依赖旧复制路径，修改后可能导致升级状态显示变化。

### Ticket 1.3：建立本地 SQLite Migration Runner

**背景**：需要用事务化增量迁移替代整库替换。

**范围**：migration 表、runner、事务执行、版本更新。

**不做事项**：不在本 ticket 完成所有 schema 修复。

**重点文件**：数据库服务、版本模型、新增 migration 目录。

**实施步骤**：

1. 定义 schema version 来源。
2. 建立 migrations 存放方式。
3. Runner 按版本排序执行 migration。
4. 每个 migration 在事务中执行。
5. 失败回滚并保留原数据库。

**验收标准**：

- 空迁移和单个迁移都能正确执行。
- 重复启动不会重复执行已完成 migration。
- 迁移失败不会更新版本号。

**测试要求**：

- migration runner 单元测试。
- 失败回滚测试。
- 重复执行幂等测试。

**依赖**：Ticket 1.2。

**风险**：版本表设计不当会导致未来迁移困难；这个 ticket 适合先用 `$to-spec` 明确设计。

### Ticket 1.4：修复外键与历史脏数据

**背景**：当前 `foreign_key_check` 存在 `users/actions` 引用错误、`user_id = 0`、孤儿 `action_id` 等问题。

**范围**：首批数据修复 migration。

**不做事项**：不完成模板计划长期分表的全部迁移。

**重点文件**：SQLite migration、计划相关表、动作相关表。

**实施步骤**：

1. 明确每类违规数据处理策略：修正、迁移、删除或隔离。
2. 修复错误外键引用。
3. 清理或迁移 `user_id = 0` 数据。
4. 处理孤儿 `action_id`。
5. 运行 `foreign_key_check` 验证。

**验收标准**：

- 目标库 `foreign_key_check` 无违规。
- 用户计划和模板计划语义不再依赖假用户。
- 迁移后关键业务路径可读。

**测试要求**：

- 基于旧库样本执行 migration。
- 验证计划读取、模板复制、训练入口。

**依赖**：Ticket 1.3。

**风险**：错误清理可能丢弃仍被 UI 依赖的数据；修复策略必须先写清。

### Ticket 1.5：设计模板计划与用户计划分表迁移

**背景**：已确认长期模型中 Template Plan 和 User Plan 分表。

**范围**：目标 schema、迁移路线、兼容读取策略。

**不做事项**：不一定在本 ticket 完成全量实现，可先产出设计和最小迁移。

**重点文件**：计划模型、计划服务、migration。

**实施步骤**：

1. 定义 `template_plans` 与 `training_plans` 的职责边界。
2. 设计模板动作、模板组数与用户动作、用户组数的关系。
3. 明确模板复制为用户计划时的数据复制规则。
4. 设计兼容旧数据的迁移路径。

**验收标准**：

- 模板计划和用户计划边界明确。
- 不再使用 `user_id = 0` 表达模板。
- 后续计划域重构可基于该模型执行。

**测试要求**：

- 模板复制测试。
- 用户编辑不影响模板测试。

**依赖**：Ticket 1.3、Ticket 1.4。

**风险**：这是跨阶段设计点，建议用 `$to-spec` 单独固化。

## Phase 2：架构边界、依赖注入与状态生命周期

### Ticket 2.1：修复 MainTabView ViewModel 生命周期

**背景**：`MainTabView` 在 `body` 路径创建 `PlanViewModel()`，可能导致重复加载和状态抖动。

**范围**：页面级 ViewModel 持有方式。

**不做事项**：不重构整个导航。

**重点文件**：`MainTabView.swift`、`PlanViewModel.swift`。

**实施步骤**：

1. 找出 `PlanViewModel()` 创建点。
2. 改为 `@StateObject` 或父级注入。
3. 避免 init 中重型自动加载。
4. 用 `.task` 或显式 `load()` 控制加载。

**验收标准**：

- 切 Tab 不重复创建计划 ViewModel。
- 训练入口仍能拿到计划数据。

**测试要求**：

- 手动切 Tab、进入训练、返回验证。
- 如可行，给 ViewModel load 行为补单元测试。

**依赖**：Ticket 1.1。

**风险**：加载时机变化可能影响首次进入计划页。

### Ticket 2.2：移除 ActionHistroyView 直连 DB

**背景**：View 直接调用 `DatabaseManager.shared.getConnection()`，破坏目标依赖方向。

**范围**：Action history 查询路径。

**不做事项**：不重构整个历史域。

**重点文件**：`ActionHistroyView.swift`、历史服务或新 ViewModel。

**实施步骤**：

1. 提取当前 SQL 查询语义。
2. 将查询迁移到 ViewModel 或历史 Repository Adapter。
3. View 只展示状态和触发 intent。
4. 保留当前 UI 行为。

**验收标准**：

- View 文件不再直接访问数据库连接。
- 动作历史展示结果不变。

**测试要求**：

- 查询结果单元测试或服务测试。
- 手动验证动作历史页面。

**依赖**：Ticket 2.1 可并行。

**风险**：历史查询字段映射容易出现遗漏。

### Ticket 2.3：建立 Repository Protocol 与 Adapter 样板

**背景**：目标架构需要 Repository Protocol，但旧 Service 不能一次性删除。

**范围**：计划域优先，形成样板后扩展。

**不做事项**：不一次性覆盖所有业务域。

**重点文件**：计划服务、计划 ViewModel、新增 Repository 文件。

**实施步骤**：

1. 定义 `PlanRepository` 协议。
2. 实现包装 `LocalPlanService` 的 Adapter。
3. 让 `PlanViewModel` 支持注入 Repository。
4. 给测试提供 Mock Repository。

**验收标准**：

- 计划 ViewModel 不再硬依赖 `LocalPlanService.shared`。
- 旧计划服务仍作为 Adapter 内部实现。

**测试要求**：

- ViewModel 使用 Mock Repository 测试。
- Adapter 冒烟测试。

**依赖**：Ticket 2.1。

**风险**：协议过早设计过大；只暴露当前阶段需要的能力。

### Ticket 2.4：建立统一错误模型

**背景**：当前错误处理存在 print、泛化错误和 UI 直接展示底层错误的问题。

**范围**：核心 AppError / DatabaseError 定义和计划域试点。

**不做事项**：不全仓替换所有错误。

**重点文件**：新增 Core error 文件、计划 ViewModel、数据库服务。

**实施步骤**：

1. 定义用户可理解的业务错误。
2. 定义保留上下文的数据库错误。
3. 计划域先接入错误映射。
4. UI 只展示用户级错误文案。

**验收标准**：

- 计划域错误路径不直接泄露 SQLite 细节。
- 日志仍保留调试上下文。

**测试要求**：

- 校验失败、未登录、数据库失败测试。

**依赖**：Ticket 2.3。

**风险**：错误抽象过重会拖慢迁移；先小范围试点。

## Phase 3：计划域整改

### Ticket 3.1：定义 PlanDraft 强类型模型

**背景**：计划链路存在 `[String: Any]`，容易运行时出错。

**范围**：计划创建/编辑所需 draft 类型。

**不做事项**：不立即替换所有旧模型。

**重点文件**：计划模型、计划 ViewModel、创建/编辑页面。

**实施步骤**：

1. 定义 `PlanDraft`、`PlanActionDraft`、`PlanSetDraft`。
2. 增加校验方法或校验 UseCase。
3. 创建旧请求结构到 draft 的转换。
4. 在创建计划路径试点。

**验收标准**：

- 创建计划保存路径不再依赖裸字典。
- draft 校验能返回明确错误。

**测试要求**：

- draft 校验测试。
- 空名称、空动作、非法组数测试。

**依赖**：Ticket 2.3、Ticket 2.4。

**风险**：旧字段含义不统一；转换逻辑必须可测试。

### Ticket 3.2：抽出 CreatePlanViewModel 和保存 UseCase

**背景**：`CreatePlanView.swift` 文件大且混合 UI、状态、保存逻辑。

**范围**：创建计划保存链路。

**不做事项**：不一次性拆完整 UI。

**重点文件**：`CreatePlanView.swift`、新增 ViewModel、计划 UseCase。

**实施步骤**：

1. 提取页面状态到 `CreatePlanViewModel`。
2. 提取保存逻辑到 `CreatePlanUseCase`。
3. View 只绑定状态并触发保存 intent。
4. 保持 UI 行为不变。

**验收标准**：

- 创建计划成功路径不变。
- 保存逻辑可单独测试。
- `CreatePlanView` 行数开始下降。

**测试要求**：

- 创建成功测试。
- 校验失败测试。
- Repository 失败测试。

**依赖**：Ticket 3.1。

**风险**：SwiftUI binding 改动可能影响表单输入。

### Ticket 3.3：抽出 EditPlanViewModel 并复用计划保存逻辑

**背景**：创建和编辑页面存在重复逻辑，长期会分叉。

**范围**：编辑计划保存链路。

**不做事项**：不重做页面视觉。

**重点文件**：`EditPlanView.swift`、计划 UseCase、PlanDraft。

**实施步骤**：

1. 提取编辑页面状态。
2. 复用 PlanDraft 和校验逻辑。
3. 建立 `UpdatePlanUseCase`。
4. 保留已有编辑交互。

**验收标准**：

- 编辑计划可保存。
- 创建/编辑共享校验规则。
- 编辑页面不直接调用 `LocalPlanService.shared`。

**测试要求**：

- 编辑成功测试。
- 删除动作、修改组数测试。

**依赖**：Ticket 3.2。

**风险**：创建和编辑存在隐含差异，需要逐条确认行为。

### Ticket 3.4：拆分计划表单 UI 组件

**背景**：计划页面文件过大，组件边界不清。

**范围**：计划名称区、动作列表区、组数编辑器、保存按钮状态。

**不做事项**：不引入完整设计系统。

**重点文件**：创建/编辑计划页面。

**实施步骤**：

1. 抽出无业务副作用的展示组件。
2. 使用 binding 或 view state 输入。
3. 保持创建和编辑共用组件。
4. 移除重复 UI 代码。

**验收标准**：

- 创建/编辑页面视觉和交互基本保持。
- 重复组件被复用。

**测试要求**：

- 手动验证创建/编辑完整流程。

**依赖**：Ticket 3.2、Ticket 3.3。

**风险**：组件拆分可能让 binding 层级复杂；优先拆纯展示。

### Ticket 3.5：模板计划复制链路整改

**背景**：模板计划和用户计划长期分表，复制语义需要明确。

**范围**：模板复制为用户计划。

**不做事项**：不重做模板 UI。

**重点文件**：计划列表、计划 Repository、计划 UseCase、migration。

**实施步骤**：

1. 定义 `CopyTemplatePlanUseCase`。
2. 明确复制时字段映射。
3. 用户编辑只影响复制后的用户计划。
4. 补模板复制回归。

**验收标准**：

- 复制模板后产生用户计划。
- 用户修改不污染模板。

**测试要求**：

- 模板复制测试。
- 用户编辑隔离测试。

**依赖**：Ticket 1.5、Ticket 3.1。

**风险**：旧模板和用户计划混在一张表时，过渡期查询要兼容。

## Phase 4：训练域与历史域整改

### Ticket 4.1：拆分 TrainingView 纯展示组件

**背景**：`TrainingView.swift` 约 1280 行，承担太多职责。

**范围**：头部、动作列表、组数记录、休息计时器、完成弹窗。

**不做事项**：不先迁移训练状态机。

**重点文件**：`TrainingView.swift`。

**实施步骤**：

1. 标记纯 UI 子块。
2. 逐个提取组件。
3. 保持输入输出简单。
4. 每次提取后手动验证训练页面。

**验收标准**：

- `TrainingView.swift` 行数明显下降。
- 训练页面视觉和基础交互不变。

**测试要求**：手动验证训练页面。

**依赖**：Ticket 2.1。

**风险**：过早提取状态逻辑会扩大回归面。

### Ticket 4.2：建立 TrainingViewModel

**背景**：训练执行状态应由 ViewModel 承载，View 只渲染和触发 intent。

**范围**：训练中的动作、组数、计时、完成状态。

**不做事项**：不一次性替换 `TrainingSessionManager` 全部职责。

**重点文件**：训练 View、训练状态管理。

**实施步骤**：

1. 定义训练页面状态模型。
2. 将可测试的状态变更移入 ViewModel。
3. 保留 `TrainingSessionManager` 作为过渡依赖。
4. 给关键状态变更补测试。

**验收标准**：

- View 不直接组装复杂训练状态。
- 状态变更可测试。

**测试要求**：

- 添加组、修改组、完成动作、休息计时状态测试。

**依赖**：Ticket 4.1。

**风险**：训练状态迁移容易影响正在训练中的体验。

### Ticket 4.3：建立 CompleteTrainingUseCase

**背景**：完成训练涉及历史保存和计划回写，当前逻辑散在 View 和 Service。

**范围**：完成训练提交链路。

**不做事项**：不重构所有历史查询。

**重点文件**：训练 ViewModel、训练历史服务、计划 Repository。

**实施步骤**：

1. 定义完成训练输入模型。
2. 保存训练历史。
3. 按规则回写计划。
4. 统一错误和成功结果。

**验收标准**：

- 完成训练后历史可见。
- 计划回写行为与旧版一致或差异有说明。

**测试要求**：

- 完成训练成功测试。
- 历史保存失败测试。
- 计划回写失败处理测试。

**依赖**：Ticket 3.3、Ticket 4.2。

**风险**：历史保存和计划回写事务边界要明确。

### Ticket 4.4：历史域 Repository 与分页查询

**背景**：历史列表、详情、统计依赖共享服务和查询逻辑，后续会膨胀。

**范围**：历史读取、详情读取、基础分页。

**不做事项**：不重做统计 UI。

**重点文件**：历史 View、历史服务、历史 Repository。

**实施步骤**：

1. 定义 `TrainingHistoryRepository`。
2. 包装现有历史服务。
3. 将历史 View 接入 ViewModel。
4. 为列表查询预留分页参数。

**验收标准**：

- 历史 View 不直接接触底层服务细节。
- 历史列表和详情显示正常。

**测试要求**：

- 历史列表读取测试。
- 历史详情读取测试。

**依赖**：Ticket 4.3。

**风险**：历史统计依赖聚合数据，分页引入后要避免统计口径变化。

## Phase 5：用户、体测、安全与隐私整改

### Ticket 5.1：审查并整改本地凭证存储

**背景**：需要确认本地密码是否明文或弱 hash，并制定安全策略。

**范围**：本地用户凭证、登录校验、兼容旧数据。

**不做事项**：不引入完整远端账号系统。

**重点文件**：`LocalUserService.swift`。

**实施步骤**：

1. 审查现有密码存储。
2. 选择 Keychain、salted hash 或本地-only 策略。
3. 设计旧凭证迁移。
4. 登录成功后升级旧凭证格式。

**验收标准**：

- 不再明文存储新密码。
- 旧用户有兼容登录路径。

**测试要求**：

- 注册、登录、旧凭证升级、错误密码测试。

**依赖**：Ticket 1.3。

**风险**：凭证迁移失败会影响用户登录。

### Ticket 5.2：处理客户端邮件服务密钥风险

**背景**：客户端不应持有生产云服务密钥。

**范围**：邮件验证码发送策略。

**不做事项**：不实现完整服务端，除非另行立项。

**重点文件**：`AliCloudEmailService.swift`、`EmailService.swift`。

**实施步骤**：

1. 审查是否存在真实 AccessKey/Secret。
2. 区分开发、本地、生产配置。
3. 生产路径改为服务端发送或禁用客户端密钥。
4. 文档化限制。

**验收标准**：

- 客户端不包含生产密钥。
- 开发路径有明确配置。

**测试要求**：

- 邮件配置缺失时错误可理解。
- 注册/找回密码流程不崩溃。

**依赖**：Ticket 5.1 可并行。

**风险**：没有服务端时生产验证码能力需要另行实现。

### Ticket 5.3：建立 AuthViewModel 与 UserSession

**背景**：登录态当前散落在多个 View 和 Service 中。

**范围**：登录、注册、退出、当前用户状态。

**不做事项**：不重做 Profile 全部 UI。

**重点文件**：登录、注册、Profile、用户服务。

**实施步骤**：

1. 定义 `UserSession` 状态源。
2. 抽出 `AuthViewModel`。
3. 登录/注册页面接入 ViewModel。
4. 统一 loading 和 error 状态。

**验收标准**：

- 登录态来源清晰。
- 退出后受限页面状态正确。

**测试要求**：

- 登录成功、登录失败、退出测试。

**依赖**：Ticket 5.1。

**风险**：登录态变化会影响计划、训练、体测当前用户读取。

### Ticket 5.4：体测域 Repository 与时间格式收敛

**背景**：体测服务存在缓存和多种时间格式兼容问题。

**范围**：体测新增、编辑、列表、详情。

**不做事项**：不重做营养计算 UI。

**重点文件**：体测 ViewModel、体测服务、体测 Views。

**实施步骤**：

1. 定义 `BodyMeasurementRepository`。
2. 包装现有本地服务。
3. 收敛时间解析和格式化。
4. 体测页面接入 ViewModel。

**验收标准**：

- 体测新增、编辑、读取正常。
- 时间格式规则明确。

**测试要求**：

- 新增、编辑、读取测试。
- 多时间格式兼容测试。

**依赖**：Ticket 5.3。

**风险**：旧数据时间格式可能不一致。

## Phase 6：UI 设计系统、可访问性与本地化

### Ticket 6.1：建立基础 UI Token

**背景**：颜色、字体、间距、圆角硬编码散落在页面中。

**范围**：AppColors、AppTypography、AppSpacing、AppRadius。

**不做事项**：不全仓替换。

**重点文件**：Theme 目录。

**实施步骤**：

1. 定义 token。
2. 修正暗色主题基础颜色。
3. 在登录、注册、计划列表试点。

**验收标准**：

- 第一批页面引用 token。
- 暗色模式主要文本可读。

**测试要求**：

- 浅色/深色手动检查。

**依赖**：Phase 2 后可启动。

**风险**：视觉变化过大；先保持现有风格。

### Ticket 6.2：抽出通用 UI 组件

**背景**：按钮、输入框、卡片、空态重复明显。

**范围**：PrimaryButton、SecondaryButton、AppTextField、PasswordField、EmptyStateView 等。

**不做事项**：不重做所有页面。

**重点文件**：Shared/Components、新旧页面试点。

**实施步骤**：

1. 从登录/注册抽输入框和按钮。
2. 从计划列表抽空态和加载态。
3. 给组件添加可访问性默认支持。

**验收标准**：

- 组件至少被两个页面复用。
- 页面重复样式减少。

**测试要求**：

- 登录、注册、计划列表手动验证。

**依赖**：Ticket 6.1。

**风险**：组件过度抽象；只抽真实重复项。

### Ticket 6.3：建立本地化资源

**背景**：大量中文文案直写，不利于长期维护。

**范围**：Tab、页面标题、按钮、错误、空态、placeholder。

**不做事项**：不一次性翻译全 App。

**重点文件**：资源本地化文件、第一批页面。

**实施步骤**：

1. 建立 `Localizable.xcstrings`。
2. 抽取核心导航和按钮文案。
3. 第一批页面接入。

**验收标准**：

- 核心文案从资源读取。
- 不破坏现有中文显示。

**测试要求**：

- 中文环境手动检查。

**依赖**：Ticket 6.1。

**风险**：key 命名混乱；先制定命名规则。

### Ticket 6.4：可访问性与响应式布局整改试点

**背景**：图标按钮语义、动态字体、固定尺寸和 offset 布局存在风险。

**范围**：MainTab、计划列表、登录注册、训练关键按钮。

**不做事项**：不全页面无差别扫描修复。

**重点文件**：主导航、计划、登录、训练页面。

**实施步骤**：

1. 为关键图标按钮补 accessibility label/hint。
2. 检查动态字体大字号。
3. 替换明显高风险 offset 和固定占位。

**验收标准**：

- 关键操作 VoiceOver 可理解。
- 大字号下主要按钮文本不截断。

**测试要求**：

- VoiceOver 抽查。
- 大字号手动检查。

**依赖**：Ticket 6.2。

**风险**：布局修复可能影响视觉，需要逐页小步替换。

## Phase 7：工程卫生、资源治理与构建维护

### Ticket 7.1：清理 .DS_Store 与文件权限噪音

**背景**：仓库存在 `.DS_Store`，大量文件权限曾变为可执行，容易污染提交。

**范围**：系统文件、文件权限、`.gitignore`。

**不做事项**：不重排资源目录。

**重点文件**：`.gitignore`、资源目录、源码目录。

**实施步骤**：

1. 加入 `.DS_Store` ignore。
2. 从仓库移除已跟踪 `.DS_Store`。
3. 修复非脚本文件可执行权限。
4. 验证 git status 干净。

**验收标准**：

- 系统文件不再进入提交。
- 非脚本源码和资源文件不是可执行权限。

**测试要求**：

- 构建验证。

**依赖**：Phase 0。

**风险**：权限批量修改要避免误伤真实脚本。

### Ticket 7.2：建立动作图片资源 Manifest

**背景**：动作图片数量大，运行时靠目录和字符串猜路径不稳定。

**范围**：manifest 生成、校验、旁路读取。

**不做事项**：不立即替换所有图片加载。

**重点文件**：动作图片资源、图片加载工具。

**实施步骤**：

1. 生成动作图片 manifest。
2. 增加资源存在性校验。
3. 在开发日志中报告缺失图片。
4. 试点一个图片加载路径。

**验收标准**：

- manifest 覆盖主要动作图片。
- 缺失资源可被检测。

**测试要求**：

- manifest 校验测试。
- 动作详情图片手动抽查。

**依赖**：Ticket 7.1。

**风险**：manifest 与数据库 action id 对不上；先旁路校验。

### Ticket 7.3：检查 AppIcon / Logo 资源完整性

**背景**：Logo 和 AppIcon 配置不完整会影响发布质量。

**范围**：AppIcon dark/tinted、Logo 1x/2x/3x。

**不做事项**：不重新设计品牌。

**重点文件**：Assets.xcassets。

**实施步骤**：

1. 检查 asset catalog 配置。
2. 列出缺失尺寸。
3. 补齐或记录待设计资源。

**验收标准**：

- 资源缺口明确。
- 构建无 asset 警告。

**测试要求**：

- Xcode 构建。
- 模拟器检查图标和 Logo。

**依赖**：Ticket 7.1。

**风险**：缺少源图时只能先记录待补。

### Ticket 7.4：清理重复与过时配置

**背景**：重复服务和过时 localhost API 配置会误导维护者。

**范围**：重复 WechatLoginService、API/DB 配置说明。

**不做事项**：不删除仍被编译引用的代码。

**重点文件**：Wechat 服务、APIConfig、DBConfig。

**实施步骤**：

1. 搜索重复服务定义和引用。
2. 标记主链和废弃路径。
3. 删除或注释过时配置。
4. 更新 README 或开发说明。

**验收标准**：

- 维护者能判断当前主数据链路是本地 SQLite。
- 无重复服务导致的歧义。

**测试要求**：

- 构建验证。

**依赖**：Ticket 7.1。

**风险**：删除过快会影响隐藏引用；先搜索和构建确认。

## Phase 8：质量体系、CI 与代码规范

### Ticket 8.1：建立测试 Target 与测试夹具

**背景**：核心逻辑缺测试，后续整改需要自动化兜底。

**范围**：测试 target、临时数据库、Mock Repository。

**不做事项**：不追求全覆盖。

**重点文件**：Xcode project、测试目录。

**实施步骤**：

1. 确认或创建测试 target。
2. 建立临时 SQLite 测试库工具。
3. 建立 Mock Repository 样板。
4. 接入计划域首批测试。

**验收标准**：

- 可以本地运行测试。
- 测试不污染真实数据库。

**测试要求**：测试 target 自测通过。

**依赖**：Ticket 1.3、Ticket 2.3。

**风险**：Xcode project 修改易产生噪音；单独提交。

### Ticket 8.2：补 P0/P1 自动化测试

**背景**：数据库迁移、计划保存、训练完成是最高风险路径。

**范围**：migration、Plan UseCase、CompleteTraining UseCase、Auth。

**不做事项**：不覆盖所有 UI。

**重点文件**：测试目录、UseCase、Repository。

**实施步骤**：

1. 补 migration 测试。
2. 补计划创建/编辑测试。
3. 补训练完成保存历史测试。
4. 补登录注册核心测试。

**验收标准**：

- P0/P1 风险路径有自动化测试。
- 测试可重复运行。

**测试要求**：新增测试本身通过。

**依赖**：Ticket 8.1。

**风险**：测试依赖旧单例会不稳定；优先测试 UseCase 和 Repository seam。

### Ticket 8.3：接入 CI build/test/lint

**背景**：整改成果需要持续防回退。

**范围**：CI 构建、测试、基础 lint。

**不做事项**：不一次性强制严格格式。

**重点文件**：CI 配置、lint 配置。

**实施步骤**：

1. 增加 build job。
2. 增加 test job。
3. 增加 SwiftLint 或 SwiftFormat 检查。
4. 先警告后强制。

**验收标准**：

- CI 能稳定跑 build/test。
- lint 不制造大规模无关改动。

**测试要求**：

- CI 首次通过或记录阻塞项。

**依赖**：Ticket 8.1。

**风险**：CI 环境和本地 Xcode 版本不一致。

## 推荐第一批执行序列

1. Ticket 0.1：创建整改基线
2. Ticket 0.2：导出 SQLite 基线
3. Ticket 0.3：建立手动回归清单
4. Ticket 1.1：加固 SQLite 连接配置
5. Ticket 1.2：停止整库覆盖式升级
6. Ticket 1.3：建立本地 SQLite Migration Runner
7. Ticket 2.1：修复 MainTabView ViewModel 生命周期
8. Ticket 2.2：移除 ActionHistroyView 直连 DB
9. Ticket 2.3：建立 Repository Protocol 与 Adapter 样板
10. Ticket 3.1：定义 PlanDraft 强类型模型

## 建议使用 `$to-spec` 的 ticket

以下 ticket 影响范围大或设计决策重，建议实现前先生成 spec：

- Ticket 1.3：建立本地 SQLite Migration Runner
- Ticket 1.4：修复外键与历史脏数据
- Ticket 1.5：设计模板计划与用户计划分表迁移
- Ticket 2.3：建立 Repository Protocol 与 Adapter 样板
- Ticket 3.2：抽出 CreatePlanViewModel 和保存 UseCase
- Ticket 4.3：建立 CompleteTrainingUseCase
- Ticket 5.1：审查并整改本地凭证存储

## 可以直接实现的 ticket

以下 ticket 边界较清晰，可以在确认后直接实现：

- Ticket 0.1：创建整改基线
- Ticket 0.2：导出 SQLite 基线
- Ticket 0.3：建立手动回归清单
- Ticket 1.1：加固 SQLite 连接配置
- Ticket 2.1：修复 MainTabView ViewModel 生命周期
- Ticket 2.2：移除 ActionHistroyView 直连 DB
- Ticket 7.1：清理 `.DS_Store` 与文件权限噪音

