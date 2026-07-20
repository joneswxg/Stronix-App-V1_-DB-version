D1 技术框架选型
1.iOS App ←→ 本地Swift服务层 ←→ 本地SQLite数据库
2.后端数据库: SQLite

D2 APP功能描述: 一款健身训练记录的软件,针对健身房的workout训练, 提供各种训练的动作, 训练计划制定, 训练过程记录, 训练历史查看等功能,主要分以下几个模块:

1.训练动作
训练动作功能如下: 从准备好的数据创建训练的数据库读取数据来形成训练动作的展示
1.1第一个页面展现列出身体不同部位的训练动作. 每个动作只简要的说明, 包括动作名称,缩略动图展示
1.2第二个页面点击每个动作缩略图片后, 会进入导航到新的页面,新的页面展现每个动作的放大动图, 具体讲解以及身体部位展示图等和动作的讲解.

2.训练计划
训练计划包括以下功能:
2.1 个人训练计划
2.1.1 训练计划的创建, 新建,命名,编辑等个能. 创建完成后,可以从“训练动作”添加训练动作到计划中, 提供增加,删除,编辑,等功能. 添加功能, 跳转到训练动第一个页面,选择某个训练动作, 将某个动作加入到自己的训练计划中,添加每个动作的训练组数和次数,间歇时间等.
2.1.2 一个训练计划包括1到多个动作,每个动作包含个字的组数,次数信息
2.1.3 训练计划创建完成后, 展示在“训练记录模块”页面, 该页面可以选择某个计划进行训练. 
3.1 训练模版参考: 提供app自带训练计划,可以直接复制到个人训练计划中进行编辑,修改,或直接使用

3.训练记录模块
3.1 选择训练计划中的某个训练计划进行训练, 在每个动作中,记录每个训练动作的重量,次数,组间的休息时间等, 并标记完成.
3.2 训练记录的过程,可根据训练的实际情况,记录实际的重量和次数,调整间歇时间.
3.3 实时展示当前执行的训练计划的训练容量(训练容量定义为:组数x次数) 
3.4.提供执行训练计划开始,结束等功能. 结束后,会把此次训练记录,训练时长等信息,展现在训练历史中.
3.5.分享训练记录到微信朋友圈

4.训练历史
4.1 训练日程: 显示日历,在每个日历的每一天显示当天执行的训练计划以及训练容量信息
4.2 点击某一天,进入到训练历史详情页面,展现训练的详细信息
4.3 训练信息统计功能,统计每周每月每年的训练情况, 功能待定
4.4 AI分析功能 (待定)

5. 其他
5.1 科普: 提供新发布的文章标题, app内只提供链接到微信公众号发表的文章 
5.2 用户信息:该模块用于记录用户的信息,身体数据(身高体重)等
5.3 登录功能模块,邮箱注册功能或者微信(wechat)实现登录
5.4 设置功能: 例如语言,界面风格等
5.5 分享功能,可以将app分享到朋友圈或者微信中
5.6 操作指南
5.7 小工具页面: 预测1RM重量的工具, 其他工具待定

6. 体测
6.1 页面1: 体测数据
6.1.1 页面1:第1个子页面,名称 体测概览, 提供输入身高,体重,年龄, 脂肪百分比,骨骼肌重量, 内脏脂肪等级信息功能,显示最新数据的图表信息
6.1.2 页面1:第2个子页面,名称 详情数据:显示体重,骨骼肌,体脂肪的图表,肥胖分析图表,腹部肥胖分析图表,综合分析结论输出基础代谢率. 饮食建议: 根据基础代谢率,计算不同目标下的热量需求以及三大营养素的需求比例
6.1.3 页面,名称: 变化,提供体测数据变化图表
6.2 页面二: 普通数据
6.2.1 输入身高,体重,年龄, 估算基础代谢率,计算不同目标下的热量需求以及三大营养素的需求比例



具体的项目结构：
Stronix-App-V1/
├── 📁 Stronix-App-V1.xcodeproj/           # Xcode项目文件
├── 📁 Stronix-App/                        # 主应用目录
│   ├── 📁 Sources/                        # 源代码目录
│   │   ├── 📁 App/                        # 应用入口
│   │   │   └── Stronix_App_V1App.swift   # SwiftUI App入口
│   │   │
│   │   ├── 📁 Extensions/                 # 扩展
│   │   │   └── Array+SafeAccess.swift
│   │   │
│   │   ├── 📁 Models/                     # 数据模型层
│   │   │   ├── 📁 Database/               # 数据库模型
│   │   │   │   ├── UpdateData.swift      # 更新数据
│   │   │   │   └── VersionControl.swift  # 版本控制
│   │   │   │
│   │   │   └── 📁 Local/                  # ✅ 本地模型（已合并和统一）
│   │   │       ├── LocalActionModels.swift           # 动作模型 (已合并ActionInfo)
│   │   │       ├── LocalBodyMeasurementModels.swift  # 体测模型
│   │   │       ├── LocalMutableTrainingModels.swift  # 可变训练模型 (已合并MutableTrainingModels)
│   │   │       ├── LocalPlanModels.swift             # 计划模型
│   │   │       ├── LocalTrainingHistoryModels.swift  # 训练历史模型 (已合并TrainingHistoryModels)
│   │   │       └── LocalTrainingModels.swift         # 训练模型 (已合并TrainingModels)
│   │   │
│   │   ├── 📁 Services/                   # 服务层（数据获取与业务逻辑）
│   │   │   ├── 📁 Database/               # 数据库服务
│   │   │   │   └── DatabaseManager.swift # 数据库管理
│   │   │   │
│   │   │   ├── 📁 Local/                  # ✅ 本地服务（已替代旧API服务）
│   │   │   │   ├── LocalActionService.swift
│   │   │   │   ├── LocalBodyMeasurementService.swift
│   │   │   │   ├── LocalPlanService.swift
│   │   │   │   ├── LocalTrainingHistoryService.swift
│   │   │   │   ├── LocalUserService.swift
│   │   │   │   └── TrainingSessionManager.swift
│   │   │   │
│   │   │   └── 📁 Update/                 # 更新服务
│   │   │       ├── UpdateService.swift
│   │   │       └── VersionService.swift
│   │   │
│   │   ├── 📁 Utilities/                  # 工具类
│   │   │   └── 📁 Constants/              # 常量定义
│   │   │       ├── APIConfig.swift       # API配置（虽然已迁移，但文件可能保留用于其他常量）
│   │   │       └── DBConfig.swift        # 数据库配置
│   │   │
│   │   ├── 📁 ViewModels/                 # 视图模型层
│   │   │   ├── BodyMeasurementViewModel.swift
│   │   │   └── PlanViewModel.swift
│   │   │
│   │   └── 📁 Views/                      # 视图层（UI界面）
│   │       ├── 📁 Actions/
│   │       ├── 📁 BodyMeasurement/
│   │       ├── 📁 History/
│   │       ├── 📁 Plans/
│   │       ├── 📁 Profile/
│   │       ├── 📁 Shared/
│   │       └── 📁 Training/
│   │       └── MainTabView.swift
│   │
│   └── 📁 Resources/                      # 资源目录
│       ├── 📁 Assets.xcassets/            # 应用程序资产（图片、颜色等）
│       ├── 📁 Database/                   # 数据库目录 (现在只包含 PreloadData/)
│       │   └── 📁 PreloadData/
│       ├── 📁 Images/                     # ✅ 统一的图片资源 (已删除Media/Actions/的重复内容)
│       └── database_stronix.db           # ✅ 主数据库文件
│
├── 📁 Tests/                              # 测试目录
│   ├── 📁 UITests/
│   └── 📁 UnitTests/
│
├── 📁 Stronix-App-V1-Info.plist           # 项目信息文件
├── 迁移方案.md                             # 迁移方案文档
└── database-bak/                         # 数据库备份目录
    └── database_stronix.db.bak           # 数据库备份文件

数据库表格说明
1.记录训练动作 (对应训练动作模块) : app提供的训练动作所需要的信息.
action                                        
action_target_muscle_link    
target_muscle 
body_part
equipment 
video
bodypart_target_muscle_link  

2.训练计划 (记录用户创建的训练计划)
training_plans
plan_actions 
plan_sets

3. 训练: 记录训练过程的表格, training_sessions用于记录训练过程的状态. 包含execuiton命令的的表格,都是临时训练过程记录信息的表格,完车训练后,要清除信息.
training_sessions 
training_plan_executions 
execution_actions                
execution_sets                                     

4. 训练历史 : 保留训练过程中的归档信息
training_history
training_history_details  
last_training_records 这个表格没用,可以去掉
 
 5.科普
 article 记录提供科普文章的链接

6. 其他
user 记录用户信息表格



 