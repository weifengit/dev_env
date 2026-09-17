
请帮我创建一个跨平台开发环境初始化项目，名称为 `dev-env-bootstrap`。项目要求：

1. 在 macOS 和 Windows 上均可运行，自动安装  **Node.js（LTS）** 、**Rust（stable）** 和  **Tauri CLI** 。
2. Windows 端使用 PowerShell 脚本，优先通过 `winget` 安装，并自动安装 **Microsoft C++ Build Tools** 和  **WebView2 Runtime** （Tauri 的 Windows 前置依赖）。
3. macOS 端使用 Bash 脚本，通过 `Homebrew` 安装 Node.js，通过 `rustup` 安装 Rust，并安装 Tauri CLI。
4. 主入口使用 Node.js 脚本 `index.js`，能自动识别操作系统，调用对应的平台脚本。
5. 所有脚本需包含安装前检测（已安装则跳过）、静默安装参数、以及安装后的版本验证。
6. 提供完整的 `package.json` 配置，使得运行 `npm run setup` 即可一键完成环境配置。

注意：请优化一下，winget经常都不能用，可能有防火墙无法访问外网的问题，能不能提供对应安装包的网址，我自行下载放在对应路径之后，执行代码的时候去看看对应的路径下是否存在安装包，如果不存在则提示网址，如果存在就检查安装包的版本和最新版本的版本号差异大不大（或者计算更新时间差距，版本号之间的差距较大时，推荐下载新版），不大时使用安装包去安装，如果安装包有问题，再提醒安装包有问题，返回下载地址。

mac：优先使用homebrew
