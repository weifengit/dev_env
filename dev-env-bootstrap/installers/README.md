# installers —— 手动下载安装包目录（仅 Windows 需要）

由于部分网络环境下 `winget` 无法访问外网（防火墙 / 代理限制），脚本提供了**本地安装包回退方案**：

把安装包手动下载后**直接放入本目录**，重新运行 `npm run setup`。
脚本会自动检测到本地安装包并优先使用它安装；找不到时才尝试 `winget`，最终都不行则提示下载网址。
（唯一的子目录例外：`vs_BuildTools-offline/` 离线布局，见下方说明。）

| 组件 | 文件名匹配模式 | 下载地址 |
|------|----------------|----------|
| Node.js (LTS) x64 | `node-*.msi` | <https://nodejs.org/dist/latest-v24.x/> （选择 `node-v24.x.x-x64.msi`） |
| Rust（rustup-init） | `rustup-init*.exe` | <https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe> |
| Microsoft C++ Build Tools | `vs_BuildTools*.exe` | <https://aka.ms/vs/17/release/vs_BuildTools.exe> |
| WebView2 Runtime (Evergreen) | `MicrosoftEdgeWebView2*.exe` | <https://go.microsoft.com/fwlink/p/?LinkId=2124703> |

> 提示：
> - 下载后的文件名无需改名，只要匹配上面的模式即可（如 `node-v24.9.0-x64.msi`）。
> - 脚本会读取本地安装包的文件版本，并与在线最新版本对比：
>   - **差距较大**（大版本落后，或小版本落后 ≥ 2）时，提示推荐下载新版；
>   - **差距不大**时直接使用本地安装包安装；
>   - **无法联网获取最新版本**时，直接用本地安装包，并依据下载时间给出提示。
> - 若本地安装包安装失败，脚本会提示安装包可能损坏并给出下载地址。

## C++ Build Tools 离线布局（约 3~4 GB，保留在本目录下）

`vs_BuildTools.exe` 本身只是几 MB 的引导下载器，真正的安装负载（MSVC + Windows SDK）
约 3~4 GB 需要在线下载。脚本的处理方式：

1. **首次安装**：用引导包把完整负载下载到 `installers/vs_BuildTools-offline/`
   （离线布局，**永久保留**），再从布局离线安装。
2. **之后重装 / 换机器**：只要把这个文件夹（连同其他安装包）一起拷贝过去，
   脚本检测到布局后**全程不访问网络**直接安装。
3. 如果你已在别处用 `--layout` 创建过布局，把整个文件夹拷到本目录下即可
   （文件夹名不限，脚本会搜索子目录中的 `vs_BuildTools*.exe`）。

手动创建/更新离线布局的命令（在网速好的环境执行）：

```powershell
.\vs_BuildTools.exe --layout <本目录>\vs_BuildTools-offline --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --lang zh-CN
```
