# dev-env-bootstrap

跨平台开发环境一键初始化：**Node.js (LTS)** + **Rust (stable)** + **Tauri CLI**，
并自动安装 Tauri 的 Windows 前置依赖（Microsoft C++ Build Tools、WebView2 Runtime）。

## 使用

```bash
npm run setup   # 一键初始化，自动识别 macOS / Windows
```

## 支持平台

| 平台 | 脚本 | 安装方式 |
|------|------|----------|
| macOS | `scripts/setup-macos.sh` | Homebrew 装 Node.js (LTS)；rustup 装 Rust (stable)；npm 全局装 Tauri CLI |
| Windows | `scripts/setup-windows.ps1` | 优先本地安装包 → 其次 winget；自动装 MSVC Build Tools 与 WebView2 Runtime |

## Windows 离线安装包策略

`winget` 在防火墙 / 无外网环境下常常不可用。因此 Windows 脚本按以下顺序处理每个组件：

1. **已安装** → 跳过；
2. **`installers/` 目录下有本地安装包** → 读取安装包版本并与最新版本对比：
   - 差距较大（大版本落后，或小版本落后 ≥ 2）→ 推荐下载新版，确认后仍可用旧版安装；
   - 差距不大 → 直接静默安装；
   - 无法联网获取最新版本 → 直接用本地安装包（依据下载时间给出提示）；
   - 安装失败 → 提示安装包可能损坏，并给出下载地址。
3. 无本地安装包 → 尝试 `winget`；
4. 仍失败 → 提示下载网址，放入 `installers/` 后重跑。

各组件下载地址见 [installers/README.md](installers/README.md)。

## 目录结构

```
dev-env-bootstrap/
├── index.js               # 主入口：识别操作系统，调用对应平台脚本
├── package.json           # npm run setup 一键执行
├── scripts/
│   ├── setup-macos.sh     # macOS 脚本（Homebrew + rustup + npm）
│   └── setup-windows.ps1  # Windows 脚本（本地安装包 / winget）
├── installers/            # Windows 手动下载的安装包存放目录
└── README.md
```

## 说明

- 所有脚本均包含：**安装前检测**（已安装则跳过）、**静默安装参数**、**安装后版本验证**。
- macOS 端安装包版本管理：Homebrew 安装 `node@24`（当前 LTS，随 LTS 切换更新脚本顶部常量）；
  Rust 通过 rustup 安装 `stable` 工具链；Tauri CLI 通过 npm 全局安装 `@tauri-apps/cli`。
