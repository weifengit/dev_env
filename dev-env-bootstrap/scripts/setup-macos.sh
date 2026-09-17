#!/usr/bin/env bash
#
# dev-env-bootstrap · macOS
#
# 通过 Homebrew 安装 Node.js (LTS)，通过 rustup 安装 Rust (stable)，通过 npm 安装 Tauri CLI。
# 每个组件都包含：已安装检测（跳过）、静默安装、安装后版本验证。
#
set -euo pipefail

# ---------- 可调参数 ----------
NODE_LTS_MAJOR=24 # 当前 Node.js LTS 主版本（LTS 切换后请更新）

# ---------- 输出辅助 ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { printf "${CYAN}[setup]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[warn]${NC} %s\n" "$*"; }
err()  { printf "${RED}[error]${NC} %s\n" "$*" >&2; }

# ---------- Homebrew ----------
install_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        ok "Homebrew 已安装 ($(brew --version | head -n1))"
        return 0
    fi

    info "未检测到 Homebrew，开始安装（可能需要 sudo 密码）..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -d /opt/homebrew/bin ]]; then
        export PATH="/opt/homebrew/bin:$PATH"
    fi
    if ! command -v brew >/dev/null 2>&1; then
        err "Homebrew 安装失败，请手动安装: https://brew.sh"
        return 1
    fi
    ok "Homebrew 安装成功 ($(brew --version | head -n1))"
}

# ---------- Node.js (LTS) ----------
install_node() {
    if command -v node >/dev/null 2>&1; then
        local ver major
        ver=$(node --version)
        major=${ver#v}
        major=${major%%.*}
        if [[ "$major" -ge 20 ]]; then
            ok "Node.js 已安装 ($(node --version))"
            return 0
        fi
        warn "Node.js 版本过旧 ($ver)，尝试升级到 LTS..."
    fi

    info "通过 Homebrew 安装 LTS (node@${NODE_LTS_MAJOR}) ..."
    brew install "node@${NODE_LTS_MAJOR}" || brew upgrade "node@${NODE_LTS_MAJOR}"
    # node@xx 是 keg-only，需要手动 link
    brew link --overwrite "node@${NODE_LTS_MAJOR}" \
        || warn "brew link 失败，请手动执行: brew link --overwrite node@${NODE_LTS_MAJOR}"

    if ! command -v node >/dev/null 2>&1; then
        err "Node.js 安装失败"
        return 1
    fi
    ok "Node.js $(node --version) / npm $(npm --version)"
}

# ---------- Rust (stable) ----------
install_rust() {
    if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
        ok "Rust 已安装 ($(rustc --version))"
    else
        info "未检测到 Rust，通过 rustup 安装 stable 工具链（静默）..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
        export PATH="$HOME/.cargo/bin:$PATH"
        if ! command -v rustc >/dev/null 2>&1; then
            err "Rust 安装失败"
            return 1
        fi
        ok "Rust 安装成功 ($(rustc --version))"
    fi
    rustup default stable >/dev/null 2>&1 || true
}

# ---------- Tauri CLI ----------
install_tauri_cli() {
    if command -v tauri >/dev/null 2>&1; then
        ok "Tauri CLI 已安装 ($(tauri --version))"
        return 0
    fi

    if ! command -v npm >/dev/null 2>&1; then
        err "未检测到 npm，请先完成 Node.js 安装后重试。"
        return 1
    fi
    info "通过 npm 全局安装 @tauri-apps/cli ..."
    npm install -g @tauri-apps/cli

    if ! command -v tauri >/dev/null 2>&1; then
        err "Tauri CLI 安装失败，请手动执行: npm install -g @tauri-apps/cli"
        return 1
    fi
    ok "Tauri CLI 安装成功 ($(tauri --version))"
}

# ---------- 主流程 ----------
main() {
    echo "===== dev-env-bootstrap · macOS ====="
    install_homebrew  || return 1
    install_node      || return 1
    install_rust      || return 1
    install_tauri_cli || return 1

    echo
    echo "===== 环境配置完成 ====="
    printf "Node.js : %s\n" "$(node --version)"
    printf "npm     : %s\n" "$(npm --version)"
    printf "Rust    : %s\n" "$(rustc --version)"
    printf "Cargo   : %s\n" "$(cargo --version)"
    printf "Tauri   : %s\n" "$(tauri --version)"
}

main "$@"
