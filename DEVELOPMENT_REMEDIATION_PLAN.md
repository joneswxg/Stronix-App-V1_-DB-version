# Stronix App 开发整改计划

本文基于 `PROJECT_IMPROVEMENT_REPORT.md`、`REFACTORING_PLAN.md` 以及本次确认的决策整理。整改路线采用整体规划、分阶段落地；先按技术风险层分阶段，再在每个阶段内按业务域执行。数据库整改范围仅包含当前 iOS 本地 SQLite，先忽略 Supabase 相关迁移内容。

## 已确认原则

- 不整体重写 App，采用渐进式整体整改。
- 整改覆盖数据安全、架构边界、状态管理、业务域拆分、UI 设计系统、资源治理、安全隐私、测试和 CI。
- 阶段排序按技术风险优先，不按页面逐个清理。
- 模板计划和用户计划长期分表管理。
- 数据库长期统一为复数表名。
- 架构目标为 `View -> ViewModel -> UseCase -> Repository Protocol -> Local Service / Database Client -> SQLite`，旧 Service 通过 Repository Adapter 渐进过渡。
- 测试嵌入每个阶段，按风险补，不以早期覆盖率数字为目标。

## 阶段 0：基线冻结与整改护栏

### 目标

建立可回退、可比较、可验收的整改基线，避免后续大范围改动失控。

### 范围

- Git 基线
- 数据库基线
- 构建基线
- 手动回归路径

### 重点文件

- `PROJECT_IMPROVEMENT_REPORT.md`
- `REFACTORING_PLAN.md`
- `Stronix-App/Resources/Database/database_stronix.db`
- `Stronix-App-V1.xcodeproj/project.pbxproj`

### 具体任务

- 创建整改起点提交或 tag。
- 导出当前 SQLite schema、表列表、外键检查结果、关键表行数。
- 记录当前可运行的 Xcode scheme、最低 iOS 版本、依赖版本。
- 定义核心手动回归路径：启动、登录、创建计划、编辑计划、开始训练、完成训练、查看历史、新增体测。
- 建立整改任务看板，按 P0/P1/P2/P3 标记。

### 验收标准

- 有明确整改起点，可随时 diff。
- 有数据库基线文件或记录。
- 有最小手动回归清单。
- 后续每阶段都能说明相对基线的变化。

### 测试要求

- 至少完成一次当前 App 手动冒烟测试。
- 记录已知失败项，不要求阶段 0 修复。

### 风险与回滚策略

- 风险：基线不准会导致后续无法判断是新问题还是旧问题。
- 回滚：任何阶段失败时，回退到阶段 0 tag 或保存提交。

### 依赖顺序

无。该阶段必须先于所有代码整改。

## 阶段 1：本地 SQLite 数据安全与升级策略

### 目标

优先消除数据丢失、外键错误、升级覆盖和 SQLite 运行配置风险。

### 范围

- 本地 SQLite 初始化
- Documents DB 与 Bundle DB 升级策略
- 外键与脏数据修复
- schema 版本管理
- 数据库索引

### 重点文件

- `Stronix-App/Sources/Services/Database/DatabaseManager.swift`
- `Stronix-App/Sources/Services/Update/UpdateService.swift`
- `Stronix-App/Sources/Services/Update/VersionService.swift`
- `Stronix-App/Sources/Models/Database/VersionControl.swift`
- `Stronix-App/Resources/Database/database_stronix.db`

### 具体任务

- 在数据库连接建立后配置 `PRAGMA foreign_keys = ON`、`PRAGMA busy_timeout = 5000`，并评估启用 `WAL`。
- 禁止升级流程删除 Documents DB 后整库复制 Bundle DB。
- 设计本地 SQLite migration 入口，按版本事务化执行。
- 建立 schema 版本表或统一版本读取逻辑。
- 输出首批 migration：修复 `users/actions` 外键引用错误，清理 `user_id = 0` 和孤儿 `action_id`。
- 设计模板计划与用户计划分表的迁移路线。
- 补充训练历史、历史详情、动作肌肉关联等高频查询索引。
- 增加数据库启动诊断日志：schema version、foreign key 状态、journal mode、foreign key check 摘要。

### 验收标准

- App 启动后 SQLite 外键检查开启。
- 数据库升级不会覆盖已有用户数据。
- `PRAGMA foreign_key_check` 对目标迁移库无违规记录。
- 用户计划、训练历史、体测数据在升级后保留。
- Supabase 迁移不进入本阶段范围。

### 测试要求

- migration 单元测试：旧库升级到新 schema。
- 用户数据保留测试：升级前创建用户计划、训练历史、体测记录，升级后可读取。
- 外键测试：违规数据应被 migration 修复或阻止。
- 数据库重复启动测试：多次初始化不会重复迁移或破坏数据。

### 风险与回滚策略

- 风险：外键修复可能暴露历史脏数据，导致写入失败。
- 风险：WAL 改动可能影响备份/复制策略。
- 回滚：升级前保留用户 DB 备份；migration 失败必须事务回滚；保留旧 schema 兼容读取路径直到迁移验证通过。

### 依赖顺序

依赖阶段 0。该阶段应先于大规模 Service 和 ViewModel 重构。

## 阶段 2：架构边界、依赖注入与状态生命周期

### 目标

建立清晰依赖方向，减少 View 直连 DB/Service、单例耦合和 SwiftUI 生命周期问题。

### 范围

- ViewModel 生命周期
- Repository Protocol
- UseCase 边界
- 旧 Local Service 适配
- 错误模型

### 重点文件

- `Stronix-App/Sources/Views/MainTabView.swift`
- `Stronix-App/Sources/ViewModels/PlanViewModel.swift`
- `Stronix-App/Sources/ViewModels/BodyMeasurementViewModel.swift`
- `Stronix-App/Sources/Views/History/ActionHistroyView.swift`
- `Stronix-App/Sources/Services/Local/LocalPlanService.swift`
- `Stronix-App/Sources/Services/Local/LocalTrainingHistoryService.swift`
- `Stronix-App/Sources/Services/Local/LocalUserService.swift`

### 具体任务

- 修复 `MainTabView` 中在 `body` 路径创建 `PlanViewModel()` 的问题，改为 `@StateObject` 或父级注入。
- 移除 `ActionHistroyView` 直接访问 `DatabaseManager.shared.getConnection()` 的查询逻辑。
- 为计划、训练历史、用户、体测建立 Repository Protocol。
- 建立 Repository Adapter，短期包装现有 `LocalPlanService` 等服务。
- 新增关键 UseCase：保存计划、编辑计划、完成训练、保存训练历史、执行数据库迁移。
- 定义 `AppError` / `DatabaseError` 分层，禁止 View 直接展示底层 SQLite 错误。
- ViewModel 初始化不自动发起重型加载，加载由 `.task` 或显式 `load()` 控制。

### 验收标准

- 新整改模块不再由 View 直接访问 SQLite。
- `MainTabView` 切 Tab 不触发异常重复加载。
- ViewModel 可注入测试 Repository。
- 旧 Service 仍可工作，但对 ViewModel 不再是唯一直接依赖。

### 测试要求

- ViewModel 单元测试使用 Mock Repository。
- UseCase 单元测试覆盖成功、校验失败、数据库失败。
- MainTabView 手动验证：进入训练、返回、切 Tab，状态不抖动。

### 风险与回滚策略

- 风险：过早替换所有单例会引入大量行为差异。
- 回滚：保留旧 Service，实现先通过 Adapter 调用旧逻辑；每个业务域单独切换。

### 依赖顺序

依赖阶段 1 的数据库初始化稳定。阶段 2 是后续业务域重构的前置条件。

## 阶段 3：计划域整改

### 目标

以计划域作为第一批业务域整改样板，收敛创建、编辑、复制、读取、进入训练的完整链路。

### 范围

- 计划列表
- 创建计划
- 编辑计划
- 模板计划复制
- 用户计划保存
- 计划 Repository / UseCase / DTO

### 重点文件

- `Stronix-App/Sources/Views/Plans/PlanListView.swift`
- `Stronix-App/Sources/Views/Plans/CreatePlanView.swift`
- `Stronix-App/Sources/Views/Plans/EditPlanView.swift`
- `Stronix-App/Sources/Views/Plans/PlanActionSelectView.swift`
- `Stronix-App/Sources/ViewModels/PlanViewModel.swift`
- `Stronix-App/Sources/Models/Local/LocalPlanModels.swift`
- `Stronix-App/Sources/Services/Local/LocalPlanService.swift`

### 具体任务

- 定义 `PlanDraft`、`PlanActionDraft`、`PlanSetDraft`，逐步替代 `[String: Any]`。
- 抽出 `CreatePlanViewModel` 和 `EditPlanViewModel`。
- 抽出复用组件：计划名称区、动作列表区、组数编辑器、保存按钮状态。
- 建立 `PlanRepository` 与 `SQLitePlanRepository`。
- 建立 `CreatePlanUseCase`、`UpdatePlanUseCase`、`CopyTemplatePlanUseCase`。
- 创建与编辑共用校验逻辑，避免两套保存规则分叉。
- 处理模板计划与用户计划的边界，禁止继续依赖 `user_id = 0` 表达模板语义。

### 验收标准

- 创建计划、编辑计划、复制模板计划、复制个人计划均正常。
- 创建/编辑页面保存逻辑不直接调用 `LocalPlanService.shared`。
- 计划保存数据结构为强类型 draft。
- 计划域成为后续训练域、历史域整改模板。

### 测试要求

- PlanDraft 校验测试。
- 创建计划 UseCase 测试。
- 编辑计划 UseCase 测试。
- 模板复制测试：模板数据不被用户编辑污染。
- 手动回归：添加/删除动作、修改组数、重量、次数、休息时间。

### 风险与回滚策略

- 风险：创建与编辑共享逻辑后，旧页面的边界行为可能改变。
- 回滚：先保留旧保存路径，通过 feature flag 或小步提交逐个页面切换。

### 依赖顺序

依赖阶段 2 的 Repository / UseCase 基础。模板计划分表依赖阶段 1 的 migration 方案。

## 阶段 4：训练域与历史域整改

### 目标

拆解训练执行和历史保存链路，把训练状态、历史写入、计划回写从巨型 View 和服务中分离出来。

### 范围

- 训练执行
- 休息计时
- 完成训练
- 历史保存
- 历史列表与详情
- 统计与分析

### 重点文件

- `Stronix-App/Sources/Views/Training/TrainingView.swift`
- `Stronix-App/Sources/Views/Training/TrainingPlanDetailView.swift`
- `Stronix-App/Sources/Services/Local/TrainingSessionManager.swift`
- `Stronix-App/Sources/Services/TrainingHistoryService.swift`
- `Stronix-App/Sources/Services/Local/LocalTrainingHistoryService.swift`
- `Stronix-App/Sources/Views/History/HistoryView.swift`
- `Stronix-App/Sources/Views/History/HistoryListView.swift`
- `Stronix-App/Sources/Views/History/TrainingHistoryDetailView.swift`
- `Stronix-App/Sources/Views/History/StatisticsView.swift`

### 具体任务

- 拆分 `TrainingView.swift`：头部、动作列表、组数记录、休息计时器、完成弹窗、键盘处理。
- 建立 `TrainingViewModel`，集中训练执行状态。
- 建立 `CompleteTrainingUseCase`，统一训练历史保存和计划回写。
- 建立 `TrainingHistoryRepository`，包装现有历史服务。
- 历史列表、详情、统计统一走 ViewModel，不在 View 中拼 SQL 或调用底层 DB。
- 为历史查询增加分页或懒加载策略。
- 清理 `LocalTrainingHistoryService.swift` 内查询、映射、业务规则混杂的问题。

### 验收标准

- 训练流程不因 View 重建丢失关键状态。
- 完成训练后历史保存和计划回写一致。
- 历史列表、详情、统计数据可正常读取。
- `TrainingView.swift` 和 `LocalTrainingHistoryService.swift` 明显拆小。

### 测试要求

- 完成训练 UseCase 测试。
- 历史保存/读取 Repository 测试。
- 计划回写测试。
- 手动回归：开始训练、记录多组、休息倒计时、后台切换、完成训练、查看历史。

### 风险与回滚策略

- 风险：训练中状态迁移最容易引入用户体验回归。
- 回滚：先提取纯展示组件，再迁移状态逻辑；训练保存链路单独提交。

### 依赖顺序

依赖阶段 2。计划回写相关任务依赖阶段 3 的计划 Repository 稳定。

## 阶段 5：用户、体测、安全与隐私整改

### 目标

收敛用户会话、登录注册、体测数据和安全隐私风险。

### 范围

- 本地用户账号
- 登录注册
- 密码/凭证存储
- 邮件验证码
- 体测记录
- 用户会话状态

### 重点文件

- `Stronix-App/Sources/Services/Local/LocalUserService.swift`
- `Stronix-App/Sources/Views/Profile/LoginView.swift`
- `Stronix-App/Sources/Views/Profile/RegisterView.swift`
- `Stronix-App/Sources/Views/Profile/ProfileMainView.swift`
- `Stronix-App/Sources/Services/Email/AliCloudEmailService.swift`
- `Stronix-App/Sources/Services/Email/EmailService.swift`
- `Stronix-App/Sources/ViewModels/BodyMeasurementViewModel.swift`
- `Stronix-App/Sources/Services/Local/LocalBodyMeasurementService.swift`
- `Stronix-App/Sources/Views/BodyMeasurement/*`

### 具体任务

- 审查 `LocalUserService` 是否明文或弱 hash 存储密码。
- 引入更安全的本地凭证策略：Keychain、salted hash，或明确本地-only 账号边界。
- 审查 `AliCloudEmailService` 是否包含真实云密钥；生产验证码发送应迁移到服务端。
- 抽出 `AuthViewModel` 和 `UserSession` 状态源。
- 登录、注册、退出统一错误模型和加载状态。
- 为体测建立 Repository / UseCase，减少 ViewModel 对单例服务的直接依赖。
- 统一体测时间格式解析与展示。

### 验收标准

- 登录态来源清晰，页面不各自维护隐式状态。
- 本地密码或凭证存储策略有明确实现和文档。
- 客户端不持有生产级云服务密钥。
- 体测新增、编辑、列表、详情正常。

### 测试要求

- 用户注册/登录/退出测试。
- 密码校验和错误场景测试。
- 体测新增、更新、读取测试。
- 手动回归：登录后创建计划、退出后访问受限页面、体测新增和查看。

### 风险与回滚策略

- 风险：账号数据迁移可能影响已有本地用户登录。
- 回滚：凭证迁移需兼容旧数据一次性升级；失败时保留用户可重新登录路径。

### 依赖顺序

依赖阶段 1 的数据库安全。用户会话整改会影响计划、训练、体测读取当前用户的方式。

## 阶段 6：UI 设计系统、可访问性与本地化

### 目标

建立正式 UI 设计系统，统一视觉语言、组件行为、暗色模式、可访问性和本地化。

### 范围

- 颜色 token
- 字体、间距、圆角
- 通用组件
- 暗色模式
- 可访问性
- 本地化
- 导航规范

### 重点文件

- `Stronix-App/Sources/Theme/AppTheme.swift`
- `Stronix-App/Sources/Theme/ThemeManager.swift`
- `Stronix-App/Sources/Theme/Color+Theme.swift`
- `Stronix-App/Sources/Views/Profile/LoginView.swift`
- `Stronix-App/Sources/Views/Profile/RegisterView.swift`
- `Stronix-App/Sources/Views/Plans/PlanListView.swift`
- `Stronix-App/Sources/Views/BodyMeasurement/BodyMeasurementOverview.swift`
- `Stronix-App/Sources/Views/Actions/ActionListView.swift`

### 具体任务

- 定义 `AppColors`、`AppTypography`、`AppSpacing`、`AppRadius`。
- 修正暗色主题中仍使用白底黑字的问题。
- 抽出 `PrimaryButton`、`SecondaryButton`、`AppTextField`、`PasswordField`、`CardSurface`、`EmptyStateView`、`SectionHeader`、`LoadingStateView`、`ErrorStateView`。
- 将登录、注册、计划列表、体测概览作为第一批 UI token 落地点。
- 统一 `NavigationStack` 使用规范，明确 push、sheet、fullScreenCover 的使用边界。
- 为图标按钮、关键状态、表单错误补 `accessibilityLabel` / `accessibilityHint`。
- 建立 `Localizable.xcstrings`，先抽 Tab、页面标题、按钮、错误、空态、placeholder。
- 移除用 `offset`、固定键盘占位高度、魔法比例修布局的高风险写法。

### 验收标准

- 第一批页面不再大量硬编码颜色、字体、间距、圆角。
- 暗色模式下主要页面可读。
- 关键按钮有可访问性语义。
- 主要文案开始走本地化资源。
- 通用组件在多个页面复用。

### 测试要求

- 手动检查浅色/深色模式。
- 动态字体至少检查大字号可读性。
- VoiceOver 抽查登录、计划、训练关键按钮。
- UI 冒烟：登录、计划列表、创建计划、体测概览。

### 风险与回滚策略

- 风险：统一组件可能改变页面布局细节。
- 回滚：按页面分批替换，组件保持旧视觉兼容参数。

### 依赖顺序

可与阶段 4/5 部分并行，但核心业务流稳定后再大面积替换 UI 更稳。

## 阶段 7：工程卫生、资源治理与构建维护

### 目标

降低仓库噪音、资源加载不确定性和构建配置维护成本。

### 范围

- `.DS_Store`
- 文件权限
- 图片资源 manifest
- AppIcon / Logo
- 重复配置
- Xcode 用户态文件

### 重点文件

- `.gitignore`
- `Stronix-App/Resources/Images`
- `Stronix-App/Resources/Assets.xcassets`
- `Stronix-App-V1.xcodeproj/project.pbxproj`
- `Stronix-App-V1.xcodeproj/xcuserdata/*`
- `Stronix-App/Sources/Utilities/Constants/APIConfig.swift`
- `Stronix-App/Sources/Utilities/Constants/DBConfig.swift`

### 具体任务

- 移除仓库中的 `.DS_Store`，加入 `.gitignore`。
- 修复大量源码、图片、配置文件被标记为可执行权限的问题。
- 评估是否应忽略 Xcode 用户态文件。
- 为动作图片建立 manifest，避免运行时靠目录扫描和字符串拼接猜路径。
- 检查 AppIcon dark/tinted、Logo 1x/2x/3x 资源完整性。
- 清理重复服务文件，例如同名或功能重叠的 `WechatLoginService`。
- 标注或移除不再作为主链的 localhost API 配置，避免误导维护者。

### 验收标准

- `git status` 不再因系统文件和权限变化产生大量噪音。
- 动作图片加载路径有 manifest 或明确索引。
- AppIcon / Logo 资源完整性可检查。
- 工程配置中用户态文件不再频繁污染提交。

### 测试要求

- 构建测试。
- 动作图片加载抽查。
- AppIcon / Logo 在模拟器或预览中检查。

### 风险与回滚策略

- 风险：资源 manifest 错误会导致动作图片缺失。
- 回滚：manifest 先作为旁路校验，再替换运行时加载。

### 依赖顺序

可在阶段 1 后开始，但动作图片 manifest 替换应避开训练/动作域大改期间。

## 阶段 8：质量体系、CI 与代码规范

### 目标

把构建、测试、格式和质量检查固化，防止整改成果回退。

### 范围

- 单元测试
- 集成测试
- UI 流程测试
- CI
- SwiftLint / SwiftFormat
- PR 检查规则

### 重点文件

- Xcode test target
- CI 配置文件
- SwiftLint / SwiftFormat 配置
- 业务域测试目录

### 具体任务

- 建立测试 target 或修复现有测试 target。
- 为数据库 migration、Repository、UseCase 建立测试夹具。
- 为计划、训练、历史、用户、体测补核心路径测试。
- 建立 CI：build、test、lint。
- 引入 SwiftLint / SwiftFormat，先使用温和规则，避免一次性产生大规模格式 churn。
- 定义提交前检查清单。

### 验收标准

- CI 能稳定执行 build/test/lint。
- 核心 P0/P1 风险有自动化测试覆盖。
- 新增业务逻辑默认带测试。
- 代码规范不会阻塞既有整改节奏。

### 测试要求

- CI 测试本身必须可重复。
- 每个已整改业务域至少有核心 UseCase 测试。
- migration 测试必须覆盖旧库到新库升级。

### 风险与回滚策略

- 风险：过严 lint 会让整改变成格式工程。
- 回滚：先警告后强制；先限制新文件和整改文件，再扩展全仓。

### 依赖顺序

贯穿所有阶段，但完整 CI 强制门槛建议在阶段 3 后逐步启用。

## 推荐执行顺序

1. 阶段 0：基线冻结与整改护栏
2. 阶段 1：本地 SQLite 数据安全与升级策略
3. 阶段 2：架构边界、依赖注入与状态生命周期
4. 阶段 3：计划域整改
5. 阶段 4：训练域与历史域整改
6. 阶段 5：用户、体测、安全与隐私整改
7. 阶段 6：UI 设计系统、可访问性与本地化
8. 阶段 7：工程卫生、资源治理与构建维护
9. 阶段 8：质量体系、CI 与代码规范

阶段 6、7、8 可以局部穿插，但不能破坏阶段 1 到阶段 4 的主线稳定性。

## 第一批建议开工任务

1. 建立整改 tag、数据库 schema dump、手动回归清单。
2. 修改数据库初始化配置，开启外键和 busy timeout，记录 WAL 评估结论。
3. 改造 `UpdateService`，停止整库覆盖式升级，建立 migration 入口。
4. 修复 `MainTabView` 中 `PlanViewModel()` 生命周期问题。
5. 移除 `ActionHistroyView` 直连 DB 查询。
6. 为计划域建立 `PlanRepository`、Repository Adapter 和 `PlanDraft`。
7. 开始拆 `CreatePlanView`，先抽保存逻辑和 ViewModel。

## 不做事项

- 不整体重写 App。
- 不在当前数据库整改中处理 Supabase 迁移。
- 不一开始追求全量测试覆盖率。
- 不在数据库安全完成前大规模改动所有业务域。
- 不一次性替换所有单例，优先通过 Repository Adapter 渐进迁移。
