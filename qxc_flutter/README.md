# 七星彩预测系统 - Flutter版

这是一个基于Flutter开发的七星彩预测系统，集成了数据采集、分析预测和用户界面于一体。

## 项目结构说明

```
lib/
├── main.dart                 # 应用程序入口文件，配置主题、路由等
├── pages/                    # 页面文件目录
│   ├── splash_page.dart      # 启动页面，处理初始化加载
│   ├── home_page.dart        # 主页面，展示主要功能入口
│   ├── prediction_page.dart  # 预测页面，显示预测结果和推荐号码
│   ├── history_page.dart     # 历史记录页面，展示历史开奖和预测数据
│   └── settings_page.dart    # 设置页面，提供应用配置选项
│
├── services/                 # 服务层目录
│   ├── lottery_service.dart  # 彩票服务，处理开奖数据获取和管理
│   ├── prediction_service.dart # 预测服务，实现预测算法和分析
│   └── database_service.dart # 数据库服务，管理本地数据存储
│
├── models/                   # 数据模型目录
│   ├── lottery_model.dart    # 开奖数据模型
│   ├── prediction_model.dart # 预测结果模型
│   └── settings_model.dart   # 设置数据模型
│
├── utils/                    # 工具类目录
│   ├── date_util.dart       # 日期处理工具
│   ├── number_util.dart     # 数字处理工具
│   ├── http_util.dart       # 网络请求工具
│   └── db_util.dart         # 数据库工具
│
└── widgets/                  # 自定义组件目录
    ├── number_grid.dart     # 号码网格组件，展示号码矩阵
    ├── prediction_card.dart # 预测结果卡片组件
    ├── history_item.dart    # 历史记录列表项组件
    └── loading_dialog.dart  # 加载对话框组件

assets/                      # 资源文件目录
├── images/                  # 图片资源
│   ├── logo.png            # 应用logo
│   └── icons/              # 图标资源
└── fonts/                   # 字体文件

test/                       # 测试目录
├── unit/                   # 单元测试
│   ├── prediction_test.dart # 预测算法测试
│   └── lottery_test.dart   # 彩票服务测试
└── widget/                 # 组件测试
    └── number_grid_test.dart # 号码网格组件测试
```

## 文件功能说明

### 主要文件

1. **main.dart**
   - 应用程序入口
   - 配置应用主题和全局样式
   - 设置路由导航
   - 初始化必要的服务

2. **pages/**
   - **splash_page.dart**: 启动页面，处理数据初始化和版本检查
   - **home_page.dart**: 主页面，提供功能导航和最新开奖信息
   - **prediction_page.dart**: 预测页面，展示预测结果和推荐号码
   - **history_page.dart**: 历史记录页面，查看历史开奖和预测数据
   - **settings_page.dart**: 设置页面，管理应用配置和用户偏好

3. **services/**
   - **lottery_service.dart**: 
     * 获取最新开奖数据
     * 管理历史开奖记录
     * 数据格式转换和验证
   - **prediction_service.dart**:
     * 实现预测算法
     * 计算特征值
     * 生成推荐号码
   - **database_service.dart**:
     * 管理SQLite数据库
     * 处理数据的增删改查
     * 提供数据缓存机制

4. **models/**
   - **lottery_model.dart**: 开奖数据的数据模型和相关方法
   - **prediction_model.dart**: 预测结果的数据模型和统计方法
   - **settings_model.dart**: 用户设置和配置的数据模型

5. **utils/**
   - **date_util.dart**: 日期格式化和计算工具
   - **number_util.dart**: 号码处理和统计工具
   - **http_util.dart**: 网络请求和错误处理工具
   - **db_util.dart**: 数据库操作和维护工具

6. **widgets/**
   - **number_grid.dart**: 展示号码矩阵的网格组件
   - **prediction_card.dart**: 显示预测结果的卡片组件
   - **history_item.dart**: 历史记录的列表项组件
   - **loading_dialog.dart**: 加载状态的对话框组件

### 资源文件

1. **assets/images/**
   - 存放应用图标、logo等图片资源
   - 包含各种分辨率的启动图标

2. **assets/fonts/**
   - 存放自定义字体文件
   - 用于特殊文字显示需求

### 测试文件

1. **test/unit/**
   - 包含各个服务和工具类的单元测试
   - 确保核心功能的正确性

2. **test/widget/**
   - 包含UI组件的集成测试
   - 验证组件的交互和显示效果

## 开发环境

- Flutter 3.x
- Dart 3.x
- VS Code / Android Studio
- SQLite

## 运行说明

1. 确保已安装Flutter环境：
```bash
flutter doctor
```

2. 获取项目依赖：
```bash
flutter pub get
```

3. 运行项目：
```bash
flutter run
```

## 注意事项

- 确保 `pubspec.yaml` 中的依赖版本兼容
- 遵循 Flutter 开发规范和最佳实践
- 保持代码的可维护性和可测试性
- 注意性能优化和内存管理
