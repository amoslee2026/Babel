#!/bin/bash
#
# Babel-LSP Installation Script
# 独立安装 Babel-LSP（HDL Language Server）
#
# 用法：
#   ./scripts/install-babel-lsp.sh [--skip-apt] [--source-dir DIR]
#
# 默认安装路径：~/.local/bin/babel-lsp
# 依赖：Rust 1.80+, slang, curl, tar, gcc, make
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

INSTALL_DIR="${HOME}/.local/bin"
SOURCE_DIR="${HOME}/wrk/eda_opensources/src"
SKIP_APT=false
BABEL_LSP_VERSION="0.2.0"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-apt)     SKIP_APT=true; shift ;;
        --source-dir)   SOURCE_DIR="$2"; shift 2 ;;
        --install-dir)  INSTALL_DIR="$2"; shift 2 ;;
        -h|--help)      head -15 "$0" | tail -13; exit 0 ;;
        *)              log_error "未知参数: $1"; exit 1 ;;
    esac
done

# ─────────────── 1. 系统依赖 ───────────────
install_system_deps() {
    log_info "检查系统依赖..."
    local missing=()
    for cmd in curl tar gcc make git; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        if [[ "$SKIP_APT" == true ]]; then
            log_warn "跳过安装缺失包: ${missing[*]}"
        elif command -v apt-get &>/dev/null; then
            log_info "安装缺失系统包: ${missing[*]}"
            sudo apt-get update -qq
            sudo apt-get install -y -qq "${missing[@]}"
        else
            log_error "请手动安装: ${missing[*]}"
            exit 1
        fi
    fi
}

# ─────────────── 2. Rust 工具链 ───────────────
install_rust() {
    if command -v rustc &>/dev/null; then
        local version
        version=$(rustc --version | grep -oP '\d+\.\d+' | head -1)
        if [ "$(printf '%s\n' "1.80" "$version" | sort -V | head -1)" = "1.80" ]; then
            log_info "Rust ${version} >= 1.80, OK"
            return
        fi
        log_warn "Rust ${version} < 1.80, 需要升级"
    fi

    log_info "安装 Rust 工具链..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
}

# ─────────────── 3. slang ───────────────
install_slang() {
    if command -v slang &>/dev/null; then
        log_info "slang 已安装: $(slang --version 2>&1 | head -1)"
        return
    fi

    log_info "安装 slang (IEEE 1800-2023 SystemVerilog 解析器)..."
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x64" ;;
        aarch64) arch="arm64" ;;
        *) log_error "不支持的架构: $arch"; exit 1 ;;
    esac

    local tmpdir
    tmpdir=$(mktemp -d)
    local url="https://github.com/MikePopoloski/slang/releases/latest/download/slang-linux-${arch}.tar.gz"

    curl -fsSL "$url" -o "$tmpdir/slang.tar.gz"
    tar xzf "$tmpdir/slang.tar.gz" -C "$tmpdir"
    mkdir -p "$INSTALL_DIR"
    cp "$tmpdir"/bin/slang "$INSTALL_DIR/"
    log_info "slang 安装到: ${INSTALL_DIR}/slang"
}

# ─────────────── 4. 克隆/更新 Babel-LSP 源码 ───────────────
fetch_source() {
    mkdir -p "$SOURCE_DIR"
    local repo_dir="${SOURCE_DIR}/Babel-LSP"

    if [[ -d "$repo_dir/.git" ]]; then
        log_info "更新已有 Babel-LSP 仓库..."
        cd "$repo_dir"
        git fetch --tags
        git checkout "v${BABEL_LSP_VERSION}" 2>/dev/null || git checkout main
    else
        log_info "克隆 Babel-LSP v${BABEL_LSP_VERSION}..."
        git clone --depth 1 --branch "v${BABEL_LSP_VERSION}" \
            https://github.com/amoslee2026/Babel-LSP.git "$repo_dir" \
            2>/dev/null || \
        git clone --depth 1 \
            https://github.com/amoslee2026/Babel-LSP.git "$repo_dir"
        cd "$repo_dir"
    fi

    echo "$repo_dir"
}

# ─────────────── 5. 编译安装 ───────────────
build_and_install() {
    local repo_dir="$1"
    cd "$repo_dir"

    log_info "编译 Babel-LSP (release mode)..."
    cargo build --release

    mkdir -p "$INSTALL_DIR"
    cp target/release/babel-lsp "$INSTALL_DIR/babel-lsp"
    chmod +x "$INSTALL_DIR/babel-lsp"

    log_success "babel-lsp 已安装到: ${INSTALL_DIR}/babel-lsp"
}

# ─────────────── 6. PATH 配置 ───────────────
configure_path() {
    if echo "$PATH" | grep -q "$INSTALL_DIR"; then
        return
    fi

    local rc_file=""
    case "$(basename "$SHELL")" in
        zsh)  rc_file="${HOME}/.zshrc" ;;
        bash) rc_file="${HOME}/.bashrc" ;;
        *)    rc_file="${HOME}/.profile" ;;
    esac

    if ! grep -q "$INSTALL_DIR" "$rc_file" 2>/dev/null; then
        echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "$rc_file"
        log_info "已将 ${INSTALL_DIR} 添加到 ${rc_file}"
    fi
    log_warn "运行 'source ${rc_file}' 或重新打开终端使 PATH 生效"
}

# ─────────────── 7. 验证 ───────────────
verify() {
    export PATH="${INSTALL_DIR}:${PATH}"

    echo ""
    log_info "=== Babel-LSP 安装验证 ==="
    local ok=true

    if command -v babel-lsp &>/dev/null; then
        babel-lsp --version 2>/dev/null && echo "  ✓ babel-lsp" || { log_error "  ✗ babel-lsp 版本检查失败"; ok=false; }
    else
        log_error "  ✗ babel-lsp 不在 PATH 中"
        ok=false
    fi

    if command -v slang &>/dev/null; then
        slang --version 2>/dev/null && echo "  ✓ slang" || log_warn "  ! slang 版本检查失败"
    else
        log_warn "  ! slang 未安装"
    fi

    echo ""
    if $ok; then
        log_success "验证通过！"
    else
        log_error "部分组件缺失，请检查错误信息"
    fi
}

# ─────────────── main ───────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   Babel-LSP v${BABEL_LSP_VERSION} 安装脚本          ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    install_system_deps
    install_rust
    install_slang

    local repo_dir
    repo_dir=$(fetch_source)
    build_and_install "$repo_dir"
    configure_path
    verify

    log_success "Babel-LSP 安装完成！"
    log_info "Claude Code MCP 模式: babel-lsp --mcp"
    log_info "编辑器 LSP 模式: babel-lsp"
}

main
