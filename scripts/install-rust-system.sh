#!/bin/bash
# Rust System-wide Installation Script (China Mirror)
# Installs latest Rust via rustup to /usr/local using Tsinghua mirror
# Requires root privileges (sudo)

set -e

echo "=== Rust System-wide Installer (China Mirror) ==="
echo ""

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script requires root privileges."
    echo "Run with: sudo bash $0"
    exit 1
fi

RUSTUP_INSTALL_DIR="/usr/local"

# Set system-wide paths
export RUSTUP_HOME="${RUSTUP_INSTALL_DIR}/rustup"
export CARGO_HOME="${RUSTUP_INSTALL_DIR}/cargo"

# Use China mirror (Tsinghua TUNA)
export RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
export RUSTUP_UPDATE_ROOT="https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup"

echo "Installing to: ${RUSTUP_INSTALL_DIR}"
echo "Using mirror: Tsinghua TUNA"
echo "RUSTUP_DIST_SERVER: ${RUSTUP_DIST_SERVER}"
echo "RUSTUP_UPDATE_ROOT: ${RUSTUP_UPDATE_ROOT}"
echo ""

TEMP_DIR="/tmp/rust-install-$(date +%s)"
mkdir -p "${TEMP_DIR}"
cd "${TEMP_DIR}"

# Download official rustup-init script (handles mirror correctly)
echo "Downloading rustup installer..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup-init.sh

# Install Rust with stable toolchain
echo ""
echo "Installing Rust (stable toolchain)..."
sh rustup-init.sh -y --no-modify-path \
    --default-toolchain stable \
    --profile default

# Add extra components
echo ""
echo "Installing rustfmt and clippy..."
"${CARGO_HOME}/bin/rustup" component add rustfmt clippy

# Create symlinks in /usr/local/bin for all users
echo ""
echo "Creating symlinks..."
mkdir -p "${RUSTUP_INSTALL_DIR}/bin"
for tool in rustc rustup cargo rust-gdb rust-lldb rustfmt cargo-fmt clippy-driver cargo-clippy; do
    if [ -f "${CARGO_HOME}/bin/${tool}" ]; then
        ln -sf "${CARGO_HOME}/bin/${tool}" "${RUSTUP_INSTALL_DIR}/bin/${tool}"
    fi
done

# Configure cargo to use mirror for crates.io
echo ""
echo "Configuring cargo mirror..."
mkdir -p "${CARGO_HOME}"
cat > "${CARGO_HOME}/config.toml" << 'EOF'
[source.crates-io]
replace-with = 'tuna'

[source.tuna]
registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git"

[net]
git-fetch-with-cli = true
EOF

# Set default toolchain
echo ""
echo "Setting default toolchain..."
"${CARGO_HOME}/bin/rustup" default stable

# List installed toolchains
echo ""
echo "Installed toolchains:"
"${CARGO_HOME}/bin/rustup" toolchain list

# Add bash completions
mkdir -p "${RUSTUP_INSTALL_DIR}/share/bash-completion/completions"
"${CARGO_HOME}/bin/rustup" completions bash > "${RUSTUP_INSTALL_DIR}/share/bash-completion/completions/rustup" 2>/dev/null || true
"${CARGO_HOME}/bin/rustup" completions bash cargo > "${RUSTUP_INSTALL_DIR}/share/bash-completion/completions/cargo" 2>/dev/null || true

# Move to safe directory before cleanup
cd "${RUSTUP_INSTALL_DIR}"

# Cleanup
rm -rf "${TEMP_DIR}"

# Verify installation
echo ""
echo "=== Installation Complete ==="
echo ""
"${RUSTUP_INSTALL_DIR}/bin/rustc" --version
"${RUSTUP_INSTALL_DIR}/bin/cargo" --version
"${RUSTUP_INSTALL_DIR}/bin/rustup" --version
"${RUSTUP_INSTALL_DIR}/bin/rustfmt" --version 2>/dev/null || true
echo ""
echo "Default toolchain: stable"
echo ""
echo "Rust installed system-wide at:"
echo "  /usr/local/bin/rustc"
echo "  /usr/local/bin/cargo"
echo "  /usr/local/bin/rustup"
echo "  /usr/local/bin/rustfmt"
echo ""
echo "Cargo mirror configured (Tsinghua TUNA)"
echo ""
echo "All users can now run:"
echo "  rustc --version"
echo "  cargo --version"
echo ""
echo "To update Rust system-wide:"
echo "  sudo RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup /usr/local/bin/rustup update"
echo ""
echo "To install additional toolchains:"
echo "  sudo /usr/local/bin/rustup toolchain install nightly"
echo ""
echo "Done!"