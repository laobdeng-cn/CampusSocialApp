# CampusSocialApp

基于 Flutter + Node.js + MongoDB 的校园社交活动平台。项目面向高校学生，提供校园动态、活动报名、活动签到、社群交流、私信互动、个人中心、通知管理等功能。

## 技术栈

### 前端

- Flutter / Dart
- Material UI
- shared_preferences
- image_picker

### 后端

- Node.js
- Express
- MongoDB
- Mongoose
- Multer
- dotenv
- cors

### 认证与安全

- PBKDF2 密码哈希
- Bearer Token 登录认证
- AUTH_TOKEN_SECRET 环境变量签名
- REGISTER_INVITATION_CODE 后端邀请码校验

## 主要功能

### 用户模块

- 登录
- 注册
- 校园认证
- 个人资料
- 设置管理
- 关注 / 粉丝

### 校园动态

- 发布帖子
- 编辑帖子
- 删除帖子
- 点赞
- 收藏
- 评论
- 浏览记录
- 草稿箱

### 活动模块

- 活动列表
- 活动详情
- 活动创建
- 活动编辑
- 活动删除
- 报名活动
- 取消报名
- 活动收藏
- 活动评论
- 活动签到
- 签到码管理
- 我报名的活动
- 我发起的活动

### 社群模块

- 社群列表
- 加入社群
- 退出社群
- 社群管理
- 社群公告
- 社群讨论
- 置顶讨论

### 消息与通知

- 私信会话
- 聊天消息
- 系统通知
- 活动通知
- 通知已读
- 删除通知

## 项目结构

```text
CampusSocialApp
├── backend
│   ├── src
│   │   ├── models
│   │   ├── routes
│   │   ├── auth.js
│   │   ├── db.js
│   │   └── server.js
│   ├── uploads
│   ├── package.json
│   └── .env.example
│
├── frontend
│   └── frontend
│       ├── lib
│       │   ├── data
│       │   ├── models
│       │   ├── repositories
│       │   ├── screens
│       │   ├── services
│       │   ├── theme
│       │   ├── widgets
│       │   └── main.dart
│       ├── assets
│       └── pubspec.yaml
│
└── README.md
```

## 环境要求

### 后端

- Node.js >= 20
- MongoDB

### 前端

- Flutter SDK
- Dart SDK
- Android Studio 或 Xcode
- Android 模拟器 / iOS 模拟器 / 真机

## 后端启动

进入后端目录：

```bash
cd backend
```

安装依赖：

```bash
npm install
```

复制环境变量文件：

```bash
cp .env.example .env
```

编辑 `.env`：

```env
PORT=4000
MONGODB_URI=mongodb://127.0.0.1:27017/campus_social
CORS_ORIGIN=http://localhost:3000,http://127.0.0.1:3000

AUTH_TOKEN_SECRET=please-change-this-secret
REGISTER_INVITATION_CODE=campus2026
ENABLE_DEMO_SEED=false
```

开发模式启动：

```bash
npm run dev
```

生产模式启动：

```bash
npm start
```

检查后端语法：

```bash
npm run check
```

健康检查地址：

```text
http://localhost:4000/health
```

## 前端启动

进入 Flutter 项目目录：

```bash
cd frontend/frontend
```

安装依赖：

```bash
flutter pub get
```

运行项目：

```bash
flutter run
```

代码检查：

```bash
flutter analyze
```

## 前后端连接说明

前端通过 `/api/...` 接口访问后端服务。后端默认端口为 `4000`。

如果使用 Android 模拟器，本机地址通常需要使用：

```text
http://10.0.2.2:4000
```

如果使用 iOS 模拟器，一般可以使用：

```text
http://localhost:4000
```

如果使用真机测试，需要把接口地址改为电脑在局域网中的 IP，例如：

```text
http://192.168.x.x:4000
```

## MongoDB 说明

如果没有配置 `MONGODB_URI`，部分公共接口可以返回演示数据。

但是以下功能需要 MongoDB 正常连接：

- 登录
- 注册
- 校园认证
- 发帖
- 评论
- 活动报名
- 活动签到
- 收藏
- 私信
- 通知
- 社群管理

## 注册邀请码

注册邀请码由后端环境变量控制：

```env
REGISTER_INVITATION_CODE=campus2026
```

前端只负责提交邀请码，不再在前端硬编码校验邀请码。

## Token Secret

后端必须配置：

```env
AUTH_TOKEN_SECRET=please-change-this-secret
```

部署时请更换为更复杂的随机字符串。不要使用示例值作为生产环境密钥。

## 常用命令

### 后端

```bash
cd backend
npm install
npm run check
npm run dev
```

### 前端

```bash
cd frontend/frontend
flutter pub get
flutter analyze
flutter run
```

### Git 提交

```bash
git status
git add .
git commit -m "your commit message"
git push
```

## 当前整理记录

项目已完成以下整理：

- 删除前端 token/debug 相关 print 日志
- 清理 `main_shell.dart` 中未使用元素
- 删除 `campus_repository.dart` 中未使用字段
- 后端强制要求配置 `AUTH_TOKEN_SECRET`
- `.env.example` 增加安全配置项

## 后续优化建议

- 拆分 `main_shell.dart`，减少单文件体积
- 拆分 `backend/src/routes/index.js`，按业务模块管理路由
- 将 Token 存储迁移到 `flutter_secure_storage`
- 增加 GitHub Actions 自动检查
- 补充接口文档
- 补充项目截图
- 补充测试账号和演示数据说明
