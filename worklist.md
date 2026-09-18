请帮我创建一个跨平台开发环境初始化项目，名称为 `dev-env-bootstrap`。项目要求：

1. 在 macOS 和 Windows 上均可运行，自动安装  **Node.js（LTS）** 、**Rust（stable）** 和  **Tauri CLI** 。
2. Windows 端使用 PowerShell 脚本，优先通过 `winget` 安装，并自动安装 **Microsoft C++ Build Tools** 和  **WebView2 Runtime** （Tauri 的 Windows 前置依赖）。
3. macOS 端使用 Bash 脚本，通过 `Homebrew` 安装 Node.js，通过 `rustup` 安装 Rust，并安装 Tauri CLI。
4. 主入口使用 Node.js 脚本 `index.js`，能自动识别操作系统，调用对应的平台脚本。
5. 所有脚本需包含安装前检测（已安装则跳过）、静默安装参数、以及安装后的版本验证。
6. 提供完整的 `package.json` 配置，使得运行 `npm run setup` 即可一键完成环境配置。

注意：请优化一下，winget经常都不能用，可能有防火墙无法访问外网的问题，能不能提供对应安装包的网址，我自行下载放在对应路径之后，执行代码的时候去看看对应的路径下是否存在安装包，如果不存在则提示网址，如果存在就检查安装包的版本和最新版本的版本号差异大不大（或者计算更新时间差距，版本号之间的差距较大时，推荐下载新版），不大时使用安装包去安装，如果安装包有问题，再提醒安装包有问题，返回下载地址。

mac：优先使用homebrew

我电脑已经配置好了打包环境（**Node.js（LTS）** 、**Rust（stable）** 和  **Tauri CLI**），我想将compare-text这个项目打包成一个应用程序方便分发给其他用户使用，这是我第一次打包，请详细指导一下，项目路径是：E:\code\compare-text

你需要执行的命令（共 5 步）
打开终端（PowerShell 或 cmd），依次执行：

* [ ] cd E:\code\compare-text

# 第 1 步：安装 Tauri CLI（仅首次，约 1-2 分钟）

npm install

# 第 2 步：回归验证——确认我的改动没有破坏浏览器模式（全部显示 ok 才算通过）

npm test

# 第 3 步：生成应用图标

node make-icon.js
npx tauri icon icon.png

# 第 4 步：桌面窗口验证（首次要下载并编译几百个 Rust 依赖，约 5-15 分钟，耐心等待）

npm run dev:desktop

# 第 5 步：正式打包（首次需从 GitHub 下载 NSIS/WiX 打包工具，编译 release 版也较慢）

npm run build:desktop
第 4 步成功的标志：弹出一个标题为"文本对比工具"的桌面窗口，界面和浏览器版一致。请重点测试"对比源"功能（点路径输入框 → 应该弹出盘符列表 → 选文件夹 → 文件正常加载对比），这验证了 Rust 命令链路。

打包产物位置（第 5 步完成后）

E:\code\compare-text\src-tauri\target\release
├── bundle
│   ├── nsis\compare-text_1.0.0_x64-setup.exe   ← 推荐分发这个（双击安装，免管理员权限）
│   └── msi\compare-text_1.0.0_x64_en-US.msi    ← MSI 安装包（企业环境常用）
└── compare-text.exe                            ← 免安装，双击直接运行
分发建议：把 nsis 下的 -setup.exe 发给其他用户即可。对方双击安装就能用，不需要装 Node/Rust/任何东西。Win11 自带 WebView2；Win10 用户首次安装时安装程序会自动联网下载 WebView2（微软官方组件，约 100MB 流量）。

常见问题（第一次打包大概率会遇到）
第 4 步报错提示 WebView2 相关：你的系统是 Win10 18363（较老），可能没装 WebView2。去微软官网搜 "WebView2 Runtime" 下载安装后重试。

cargo 下载依赖极慢/卡住（国内网络常见）：配置国内镜像，参照 https://rsproxy.cn 首页说明改 C:\Users\Administrator\.cargo\config.toml，然后重试。

第 5 步下载 NSIS/WiX 失败：打包工具从 GitHub 下载，网络不畅时多试几次；若只要 NSIS 安装包，把 src-tauri/tauri.conf.json 里 "targets": "all" 改为 "targets": ["nsis"]。

杀毒软件拦截编译出的 exe：Rust 编译产物偶尔被误报，加白名单即可，不影响功能。

以后改代码怎么更新安装包：改完前端代码后，浏览器模式直接 node serve.js 刷新验证；桌面版重新执行 npm run build:desktop 即可（dist/ 会自动重新生成，不用手动管）。版本号在 tauri.conf.json 的 "version" 里改。

想换图标：准备一张 ≥512×512 的 PNG，执行 npx tauri icon 你的图.png，然后重新打包。

建议你先执行第 1～3 步（几分钟的事），确认 npm test 全部通过后告诉我结果；第 4 步编译时间最长，如果中途报错，把报错信息贴给我，我帮你排查。
