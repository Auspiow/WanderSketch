
# WanderSketch

WanderSketch 是一款基于 HarmonyOS 的智能旅行规划应用。用户选择目的地、出行日期和旅行偏好后，应用通过 Gemini 生成行程，并在地图上展示路线；行程期间还可依据实时天气给出提醒并重新规划。

## 功能

- 智能行程生成：结合目的地、日期、旅行节奏和餐饮偏好生成逐日路线、时间线与预算。
- 地点搜索与地图路线：使用 Google Places 搜索目的地，在 Google Maps 中展示景点、路线和地点详情。
- 天气感知：接入 OpenWeather 获取当前天气，在地图叠加天气图层；恶劣天气变化时提示并支持 AI 重规划。
- 行程编辑：支持查看、筛选、调整地点顺序、替换地点和修改行程名称。
- 行程海报：按天汇集景点与餐饮推荐，生成可浏览的旅行海报内容。
- 协作与通知：通过邀请码加入同一行程，支持成员权限、手动同步、行程修改同步与版本冲突提示，并可发送天气变化通知。

## 技术栈

| 范畴 | 技术 |
| --- | --- |
| 客户端 | HarmonyOS Stage Model、UIAbility、ArkTS、ArkUI 声明式 UI |
| 地图与地点 | Google Maps JavaScript API、Places API、Directions API、Static Maps API |
| 天气 | OpenWeather Current Weather API 与天气图层 |
| 服务端 | Node.js 20+、Gemini API |

## 项目结构

```text
WanderSketch/
├── entry/src/main/ets/
│   ├── pages/RealMapSelectPage.ets    # 应用主页面与交互
│   ├── components/RealMapView.ets     # 地图 Web 组件
│   ├── model/Types.ets                # 行程、天气等数据模型
│   ├── services/                      # 地图、天气、行程、通知、海报服务
│   └── entryability/EntryAbility.ets  # UIAbility 入口
├── server/
│   ├── src/index.js                   # Gemini 行程规划 API
│   └── README.md                      # 服务端接口说明
├── scripts/generate-api-config.mjs    # 从 .env 生成客户端密钥配置
└── .env.example                       # 客户端 API 密钥模板
```

## 环境要求

- DevEco Studio（已配置 HarmonyOS SDK）
- Node.js 20 或更高版本
- Google Maps API Key，且已启用 Maps JavaScript、Places、Directions 和 Static Maps 等所需服务
- OpenWeather API Key
- Gemini API Key

## 配置

### 客户端地图与天气密钥

复制根目录的环境变量模板：

```powershell
Copy-Item .env.example .env
```

编辑 `.env`，填入以下值：

```dotenv
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
OPENWEATHER_API_KEY=your_openweather_api_key
```

生成客户端使用的配置文件：

```powershell
node scripts/generate-api-config.mjs
```

该命令会生成 `entry/src/main/ets/services/ApiKeys.ets`。此文件与 `.env` 均已被 Git 忽略，避免提交密钥。

### 配置服务端

```powershell
Copy-Item server/.env.example server/.env
```

编辑 `server/.env`，至少设置：

```dotenv
GEMINI_API_KEY=your_gemini_api_key
```

可按需调整 `GEMINI_MODEL`、`PORT` 和请求超时时间。完整接口请求与响应格式见 [server/README.md](server/README.md)。

## 启动

先启动服务端：

```powershell
node server/src/index.js
```

可通过以下命令确认服务状态：

```powershell
curl.exe http://127.0.0.1:3000/health
```

随后使用 DevEco Studio 打开仓库根目录，选择 `entry` 模块并运行到模拟器或真机。

首次运行前，请确认已执行一次：

```powershell
node scripts/generate-api-config.mjs
```

## 客户端连接服务端

客户端服务地址定义在 [TravelPlanService.ets](entry/src/main/ets/services/TravelPlanService.ets) 的 `TRAVEL_PLAN_ENDPOINTS` 与 `TRAVEL_REPLAN_ENDPOINTS` 中。

- 使用模拟器时，可使用 `10.0.2.2:3000` 指向开发机服务。
- 使用真机时，必须将地址改为开发机在同一局域网内可访问的 IP，并确保防火墙允许该端口访问。
- `127.0.0.1` 仅代表设备或模拟器自身，通常不能用于访问开发机上的服务。

## 共同编辑

打开行程详情中的“共同编辑”面板后，应用会在服务端创建该行程的邀请码。将邀请码发给同行人；对方在同一面板输入邀请码和昵称即可加载同一份行程。

- 编辑景点、调整顺序、删除地点、AI 重规划和重命名会写回协作会话。
- 点击“同步最新修改”可获取其他设备的最新版本。
- 服务端使用版本号拒绝过期写入，避免静默覆盖他人的修改；发生冲突时先同步，再基于最新行程重新编辑。
- 协作会话目前保存在 Node.js 进程内存中，服务端重启后会清空。生产环境应替换为带身份认证的持久化存储。

## 权限

应用声明以下权限：

- `ohos.permission.INTERNET`：调用地图、天气与行程规划服务。
- `ohos.permission.APPROXIMATELY_LOCATION` 与 `ohos.permission.LOCATION`：支持基于位置的地图和行程能力。

通知功能会在需要时请求用户开启通知权限。

## 开发说明

- 客户端页面位于 `entry/src/main/ets/pages`，可复用组件位于 `components`。
- 数据模型集中在 `model/Types.ets`，网络和业务逻辑在 `services`。
- 当前首页为 `RealMapSelectPage`，由 `EntryAbility` 加载。
- 行程生成和重规划都依赖本地 Node.js 服务；服务不可达时，应用会显示生成失败原因。
