#!/bin/bash
# Rust Environment Configuration Script
# Configures ~/.bashrc and sudoers for system-wide Rust installation
# Run with: bash scripts/configure-rust-env.sh

set -e

echo "=== Rust Environment Configuration ==="
echo ""

RUSTUP_HOME="/usr/local/rustup"
CARGO_HOME="/usr/local/cargo"
MIRROR_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"

# Check if Rust is installed
if [ ! -d "${RUSTUP_HOME}" ] || [ ! -d "${CARGO_HOME}" ]; then
    echo "Error: Rust not found at ${RUSTUP_HOME} or ${CARGO_HOME}"
    echo "Please run install-rust-system.sh first."
    exit 1
fi

# Configure sudoers to preserve Rust environment variables (including PATH)
echo "Configuring sudoers..."
SUDOERS_FILE="/etc/sudoers.d/rust-env"
sudo mkdir -p /etc/sudoers.d
sudo tee "${SUDOERS_FILE}" > /dev/null << 'EOF'
Defaults env_keep += "RUSTUP_HOME CARGO_HOME RUSTUP_DIST_SERVER RUSTUP_UPDATE_ROOT PATH"
EOF
sudo chmod 440 "${SUDOERS_FILE}"

# Verify sudoers syntax
sudo visudo -cf "${SUDOERS_FILE}" && echo "sudoers syntax OK"

# Add to ~/.bashrc (user level)
echo ""
echo "Adding Rust configuration to ~/.bashrc..."
if ! grep -q "RUSTUP_HOME=/usr/local/rustup" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# Rust system-wide configuration
export RUSTUP_HOME="/usr/local/rustup"
export CARGO_HOME="/usr/local/cargo"
export RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
export RUSTUP_UPDATE_ROOT="https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup"
export PATH="/usr/local/cargo/bin:$PATH"
EOF
    echo "Added to ~/.bashrc"
else
    echo "Already configured in ~/.bashrc"
fi

# Apply for current session
export RUSTUP_HOME="${RUSTUP_HOME}"
export CARGO_HOME="${CARGO_HOME}"
export RUSTUP_DIST_SERVER="${MIRROR_SERVER}"
export RUSTUP_UPDATE_ROOT="${MIRROR_SERVER}/rustup"
export PATH="${CARGO_HOME}/bin:${PATH}"

echo ""
echo "=== Configuration Complete ==="
echo ""
rustc --version
cargo --version
echo ""
echo "Now you can run:"
echo "  sudo rustup default stable"
echo "  sudo rustup toolchain list"
echo "  sudo rustup update"
echo ""
echo "For new terminals: source ~/.bashrc"
echo "Done!"