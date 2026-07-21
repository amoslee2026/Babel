#!/bin/bash
#
# Open-Source EDA Toolchain Installation Script
# 用于数字集成电路设计的开源EDA工具链安装脚本
#
# 工具列表：Yosys, ABC, Magic, Netgen, QRouter, OpenSTA, KLayout, Verilator
#
# 用法：
#   ./install-eda-toolchain.sh [--install-dir DIR] [--skip-apt] [--tool TOOL]
#
# 选项：
#   --install-dir DIR   安装目录 (默认: ~/wrk/eda_opensources/install)
#   --skip-apt          跳过apt依赖安装
#   --tool TOOL         只安装指定工具
#   --parallel N        并行编译数 (默认: CPU核心数)
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 默认配置
INSTALL_DIR="${HOME}/wrk/eda_opensources/install"
BUILD_DIR="${HOME}/wrk/eda_opensources/build"
SRC_DIR="${HOME}/wrk/eda_opensources/src"
SKIP_APT=false
SPECIFIC_TOOL=""
PARALLEL=$(nproc)

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --skip-apt)
            SKIP_APT=true
            shift
            ;;
        --tool)
            SPECIFIC_TOOL="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL="$2"
            shift 2
            ;;
        -h|--help)
            head -20 "$0" | tail -18
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# 工具版本配置
declare -A TOOL_VERSIONS=(
    [yosys]="0.35"
    [abc]="latest"
    [magic]="8.3.641"
    [netgen]="1.5"
    [qrouter]="1.4"
    [opensta]="2.2.0"
    [klayout]="0.30.8"
    [verilator]="5.024"
    [babel_lsp]="0.2.0"
)

# 创建目录结构
setup_dirs() {
    log_info "创建目录结构..."
    mkdir -p "$INSTALL_DIR/bin"
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/lib64"
    mkdir -p "$INSTALL_DIR/include"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$SRC_DIR"
    log_success "目录已创建: $INSTALL_DIR"
}

# 检查系统依赖
check_dependencies() {
    if [[ "$SKIP_APT" == true ]]; then
        log_warn "跳过apt依赖安装"
        return
    fi

    log_info "检查并安装系统依赖..."

    # 检测系统类型
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKGS="build-essential clang bison flex libreadline-dev gawk tcl-dev \
              libffi-dev git graphviz xdot pkg-config python3 python3-dev \
              libboost-system-dev libboost-python-dev libboost-filesystem-dev \
              zlib1g-dev libfltk1.3-dev libglu1-mesa-dev libglew-dev libx11-dev \
              libxext-dev libxrender-dev libxpm-dev libgl1-mesa-dev \
              qt5-default qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
              libqt5xmlpatterns5-dev libqt5svg5-dev libcurl4-openssl-dev \
              wget curl cmake autoconf automake libtool"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKGS="gcc gcc-c++ clang bison flex readline-devel gawk tcl-devel \
              libffi-devel git graphviz xdot pkgconfig python3 python3-devel \
              boost-devel zlib-devel fltk-devel mesa-libGLU-devel glew-devel \
              libX11-devel libXext-devel libXrender-devel libXpm-devel mesa-libGL-devel \
              qt5-qtbase-devel qt5-qmake qt5-qtbase-devel-tools \
              libcurl-devel wget curl cmake autoconf automake libtool"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKGS="gcc gcc-c++ clang bison flex readline-devel gawk tcl-devel \
              libffi-devel git graphviz xdot pkgconfig python3 python3-devel \
              boost-devel zlib-devel fltk-devel mesa-libGLU-devel glew-devel \
              libX11-devel libXext-devel libXrender-devel libXpm-devel mesa-libGL-devel \
              qt5-qtbase-devel qt5-qmake qt5-rpm-macros \
              libcurl-devel wget curl cmake autoconf automake libtool"
    else
        log_error "不支持的系统，请手动安装依赖"
        return 1
    fi

    log_info "使用 $PKG_MANAGER 安装依赖包..."
    sudo $PKG_MANAGER update -y
    sudo $PKG_MANAGER install -y $PKGS

    log_success "系统依赖已安装"
}

# 下载并编译 Yosys
install_yosys() {
    log_info "安装 Yosys ${TOOL_VERSIONS[yosys]}..."

    cd "$SRC_DIR"
    if [[ ! -d "yosys" ]]; then
        git clone https://github.com/YosysHQ/yosys.git
    fi
    cd yosys

    # 切换到指定版本
    if [[ "${TOOL_VERSIONS[yosys]}" != "latest" ]]; then
        git checkout yosys-${TOOL_VERSIONS[yosys]}
    fi

    make config-clang
    make -j$PARALLEL PREFIX="$INSTALL_DIR"
    make install PREFIX="$INSTALL_DIR"

    log_success "Yosys 已安装"
    yosys --version
}

# 下载并编译 ABC
install_abc() {
    log_info "安装 ABC..."

    cd "$SRC_DIR"
    if [[ ! -d "abc" ]]; then
        git clone https://github.com/berkeley-abc/abc.git
    fi
    cd abc

    make -j$PARALLEL
    cp abc "$INSTALL_DIR/bin/"

    log_success "ABC 已安装"
}

# 下载并编译 Magic
install_magic() {
    log_info "安装 Magic ${TOOL_VERSIONS[magic]}..."

    cd "$SRC_DIR"
    if [[ ! -d "magic" ]]; then
        git clone https://github.com/RTimothyEdwards/magic.git
    fi
    cd magic

    # 切换到指定版本
    if [[ "${TOOL_VERSIONS[magic]}" != "latest" ]]; then
        git checkout magic-${TOOL_VERSIONS[magic]}
    fi

    ./configure --prefix="$INSTALL_DIR"
    make -j$PARALLEL
    make install

    log_success "Magic 已安装"
    magic --version
}

# 下载并编译 Netgen
install_netgen() {
    log_info "安装 Netgen ${TOOL_VERSIONS[netgen]}..."

    cd "$SRC_DIR"
    if [[ ! -d "netgen" ]]; then
        git clone https://github.com/RTimothyEdwards/netgen.git
    fi
    cd netgen

    # 切换到指定版本
    if [[ "${TOOL_VERSIONS[netgen]}" != "latest" ]]; then
        git checkout netgen-${TOOL_VERSIONS[netgen]}
    fi

    ./configure --prefix="$INSTALL_DIR"
    make -j$PARALLEL
    make install

    log_success "Netgen 已安装"
    netgen -v
}

# 下载并编译 QRouter
install_qrouter() {
    log_info "安装 QRouter ${TOOL_VERSIONS[qrouter]}..."

    cd "$SRC_DIR"
    if [[ ! -d "qrouter" ]]; then
        git clone https://github.com/RTimothyEdwards/qrouter.git
    fi
    cd qrouter

    # 切换到指定版本
    if [[ "${TOOL_VERSIONS[qrouter]}" != "latest" ]]; then
        git checkout qrouter-${TOOL_VERSIONS[qrouter]}
    fi

    ./configure --prefix="$INSTALL_DIR"
    make -j$PARALLEL
    make install

    log_success "QRouter 已安装"
}

# 下载并编译 OpenSTA
install_opensta() {
    log_info "安装 OpenSTA ${TOOL_VERSIONS[opensta]}..."

    cd "$SRC_DIR"
    if [[ ! -d "OpenSTA" ]]; then
        git clone https://github.com/The-OpenROAD-Project/OpenSTA.git
    fi
    cd OpenSTA

    # 切换到指定版本
    if [[ "${TOOL_VERSIONS[opensta]}" != "latest" ]]; then
        git checkout sta-${TOOL_VERSIONS[opensta]}
    fi

    cmake -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -B build
    cmake --build build -j$PARALLEL
    cmake --install build

    log_success "OpenSTA 已安装"
    sta --version
}

# 下载并安装 KLayout
install_klayout() {
    log_info "安装 KLayout ${TOOL_VERSIONS[klayout]}..."

    cd "$SRC_DIR"

    # 检测系统
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu - 使用预编译包
        Klayout_URL="https://github.com/KLayout/klayout/releases/download/v${TOOL_VERSIONS[klayout]}/klayout_${TOOL_VERSIONS[klayout]}-1_amd64.deb"
        wget -O klayout.deb "$Klayout_URL"
        sudo dpkg -i klayout.deb || sudo apt-get install -f -y
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        # RHEL/CentOS/Fedora - 编译安装
        if [[ ! -d "klayout" ]]; then
            git clone https://github.com/KLayout/klayout.git
        fi
        cd klayout
        git checkout v${TOOL_VERSIONS[klayout]}

        ./build.sh -build -j$PARALLEL -prefix "$INSTALL_DIR"
    fi

    log_success "KLayout 已安装"
    klayout --version || echo "KLayout 版本检查失败（可能需要重启终端）"
}

# 下载并编译 Verilator
install_verilator() {
    log_info "安装 Verilator ${TOOL_VERSIONS[verilator]}..."

    cd "$SRC_DIR"
    if [[ ! -d "verilator" ]]; then
        git clone https://github.com/verilator/verilator.git
    fi
    cd verilator

    git checkout v${TOOL_VERSIONS[verilator]}

    autoconf
    ./configure --prefix="$INSTALL_DIR"
    make -j$PARALLEL
    make install

    log_success "Verilator 已安装"
    verilator --version
}

# 安装 Babel-LSP (HDL Language Server — Rust + slang)
# 2026-07-21: 新增 Babel-LSP 依赖，用于 SV 语法检查和 MCP 服务
install_babel_lsp() {
    log_info "安装 Babel-LSP ${TOOL_VERSIONS[babel_lsp]}..."

    local BABEL_LSP_DIR="${HOME}/.local/bin"

    # 检查是否已安装
    if command -v babel-lsp &>/dev/null; then
        local installed_ver
        installed_ver=$(babel-lsp --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
        log_info "babel-lsp 已安装: ${installed_ver}"
        return
    fi

    # 检查/安装 Rust
    if ! command -v cargo &>/dev/null; then
        log_info "安装 Rust 工具链..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --default-toolchain stable
        # shellcheck source=/dev/null
        source "${HOME}/.cargo/env"
    fi

    # 检查/安装 slang
    if ! command -v slang &>/dev/null; then
        log_info "安装 slang (SV 解析引擎)..."
        local arch
        arch=$(uname -m)
        case "$arch" in
            x86_64)  arch="x64" ;;
            aarch64) arch="arm64" ;;
            *) log_error "不支持的架构: $arch"; return 1 ;;
        esac
        local tmpdir
        tmpdir=$(mktemp -d)
        curl -fsSL "https://github.com/MikePopoloski/slang/releases/latest/download/slang-linux-${arch}.tar.gz" \
            -o "$tmpdir/slang.tar.gz"
        tar xzf "$tmpdir/slang.tar.gz" -C "$tmpdir"
        mkdir -p "$BABEL_LSP_DIR"
        cp "$tmpdir/bin/slang" "$BABEL_LSP_DIR/"
        log_success "slang 已安装"
    fi

    # 克隆/更新 Babel-LSP
    local repo_dir="${SRC_DIR}/Babel-LSP"
    if [[ ! -d "$repo_dir/.git" ]]; then
        git clone --depth 1 https://github.com/amoslee2026/Babel-LSP.git "$repo_dir"
    fi
    cd "$repo_dir"

    # 编译
    log_info "编译 Babel-LSP (release mode)..."
    cargo build --release

    mkdir -p "$BABEL_LSP_DIR"
    cp target/release/babel-lsp "$BABEL_LSP_DIR/babel-lsp"
    chmod +x "$BABEL_LSP_DIR/babel-lsp"

    log_success "Babel-LSP 已安装到: ${BABEL_LSP_DIR}/babel-lsp"
}

# 安装 OSS CAD Suite (预编译的 Yosys+ABC+其他)
install_oss_cad_suite() {
    log_info "安装 OSS CAD Suite..."

    cd "$SRC_DIR"
    OSS_DIR="${HOME}/wrk/eda_opensources/oss-cad-suite"

    if [[ ! -d "$OSS_DIR" ]]; then
        # 检测系统
        if [[ "$(uname -m)" == "x86_64" ]]; then
            ARCH="linux-x64"
        elif [[ "$(uname -m)" == "aarch64" ]]; then
            ARCH="linux-arm64"
        else
            log_error "不支持的架构"
            return 1
        fi

        OSS_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/latest/download/oss-cad-suite-${ARCH}.tar.gz"
        wget -O oss-cad-suite.tar.gz "$OSS_URL"
        mkdir -p "$OSS_DIR"
        tar -xzf oss-cad-suite.tar.gz -C "$OSS_DIR" --strip-components=1
    fi

    log_success "OSS CAD Suite 已安装"
    "$OSS_DIR/bin/yosys" --version
}

# 生成环境变量脚本
generate_env_script() {
    log_info "生成环境变量脚本..."

    ENV_SCRIPT="${HOME}/wrk/eda_opensources/eda_env.sh"

    cat > "$ENV_SCRIPT" << 'EOF'
#!/bin/bash
# Open-Source EDA Toolchain Environment
# 开源EDA工具链环境变量配置

# OSS CAD Suite (预编译，包含最新版Yosys)
export OSS_CAD_SUITE="$HOME/wrk/eda_opensources/oss-cad-suite"

# 传统编译安装目录
export EDA_OPENROOT="$HOME/wrk/eda_opensources/install"

# PATH配置 - OSS优先
export PATH="$OSS_CAD_SUITE/bin:$EDA_OPENROOT/bin:$PATH"

# LD_LIBRARY_PATH - 仅用于传统安装
export LD_LIBRARY_PATH="$EDA_OPENROOT:$EDA_OPENROOT/lib:$EDA_OPENROOT/lib64:$LD_LIBRARY_PATH"

# 工具别名
alias yosys-run='yosys'
alias sta-run='sta'
alias magic-run='magic'

echo "EDA工具链环境已加载"
echo "可用工具: yosys, abc, magic, netgen, qrouter, sta, klayout, verilator"
EOF

    chmod +x "$ENV_SCRIPT"
    log_success "环境脚本已生成: $ENV_SCRIPT"

    # 提示添加到 .bashrc
    log_warn "请运行以下命令或添加到 ~/.bashrc:"
    echo ""
    echo "    source ~/wrk/eda_opensources/eda_env.sh"
    echo ""
}

# 验证安装
verify_installation() {
    log_info "验证安装..."

    source "${HOME}/wrk/eda_opensources/eda_env.sh" 2>/dev/null || true

    TOOLS=("yosys" "abc" "magic" "netgen" "qrouter" "sta" "klayout" "verilator")

    echo ""
    echo "=========================================="
    echo "工具版本检查"
    echo "=========================================="

    for tool in "${TOOLS[@]}"; do
        if command -v "$tool" &> /dev/null; then
            case $tool in
                yosys)   version=$(yosys --version | head -1) ;;
                abc)     version="latest (ok)" ;;
                magic)   version=$(magic --version 2>&1 | head -1) ;;
                netgen)  version=$(netgen -v 2>&1 | head -1) ;;
                qrouter) version=$(qrouter --version 2>&1 | head -1) ;;
                sta)     version=$(sta --version 2>&1 | head -1) ;;
                klayout) version=$(klayout --version 2>&1 | head -1) ;;
                verilator) version=$(verilator --version | head -1) ;;
            esac
            echo -e "  ${GREEN}✓${NC} $tool: $version"
        else
            echo -e "  ${RED}✗${NC} $tool: 未安装"
        fi
    done

    echo "=========================================="
    echo ""
}

# 主函数
main() {
    log_info "开始安装开源EDA工具链..."
    log_info "安装目录: $INSTALL_DIR"
    log_info "并行编译: $PARALLEL"

    setup_dirs
    check_dependencies

    if [[ -n "$SPECIFIC_TOOL" ]]; then
        case "$SPECIFIC_TOOL" in
            yosys)      install_yosys ;;
            abc)        install_abc ;;
            magic)      install_magic ;;
            netgen)     install_netgen ;;
            qrouter)    install_qrouter ;;
            opensta)    install_opensta ;;
            klayout)    install_klayout ;;
            verilator)  install_verilator ;;
            oss-cad-suite) install_oss_cad_suite ;;
            all)
                install_oss_cad_suite
                install_yosys
                install_abc
                install_magic
                install_netgen
                install_qrouter
                install_opensta
                install_klayout
                install_verilator
                ;;
            *)
                log_error "未知工具: $SPECIFIC_TOOL"
                echo "可用工具: yosys, abc, magic, netgen, qrouter, opensta, klayout, verilator, oss-cad-suite, all"
                exit 1
                ;;
        esac
    else
        # 默认安装所有工具
        install_oss_cad_suite  # 预编译包，快速
        install_abc
        install_magic
        install_netgen
        install_qrouter
        install_opensta
        install_klayout
        install_verilator
    fi

    generate_env_script
    verify_installation

    log_success "安装完成!"
    log_info "请运行: source ~/wrk/eda_opensources/eda_env.sh"
}

main