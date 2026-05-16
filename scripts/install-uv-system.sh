#!/bin/bash
# uv System-wide Installation Script
# Installs uv and uvx to /usr/local/bin for all users
# Requires root privileges (sudo)

set -e

INSTALL_DIR="/usr/local/bin"
UV_VERSION="latest"
TEMP_DIR="/tmp/uv-install"

# Proxy configuration (SOCKS5h for remote DNS)
PROXY_HOST="10.147.19.6"
PROXY_PORT="7898"
CURL_OPTS=""

# Check for proxy env or use default
if [ -n "${ALL_PROXY}" ] || [ -n "${http_proxy}" ]; then
    echo "Using existing proxy configuration"
elif [ -n "${PROXY_HOST}" ]; then
    CURL_OPTS="--proxy socks5h://${PROXY_HOST}:${PROXY_PORT}"
    echo "Using default proxy: socks5h://${PROXY_HOST}:${PROXY_PORT}"
fi

echo "=== uv System-wide Installer ==="
echo "Target: ${INSTALL_DIR}"
echo ""

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script requires root privileges."
    echo "Run with: sudo bash $0"
    exit 1
fi

# Create temp directory
mkdir -p "${TEMP_DIR}"
cd "${TEMP_DIR}"

# Determine architecture
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64|amd64)
        UV_ARCH="x86_64-unknown-linux-gnu"
        ;;
    aarch64|arm64)
        UV_ARCH="aarch64-unknown-linux-gnu"
        ;;
    *)
        echo "Error: Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

echo "Architecture: ${UV_ARCH}"

# Get latest version from GitHub API
echo "Fetching latest version..."
UV_VERSION=$(curl ${CURL_OPTS} -sL "https://api.github.com/repos/astral-sh/uv/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Latest version: ${UV_VERSION}"

# Download uv
echo "Downloading uv..."
UV_URL="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}.tar.gz"
curl ${CURL_OPTS} -L -o uv.tar.gz "${UV_URL}"

# Extract and install
echo "Extracting..."
tar -xzf uv.tar.gz

# Move to system path (files are in arch-specific subdirectory)
echo "Installing to ${INSTALL_DIR}..."
mv uv-${UV_ARCH}/uv "${INSTALL_DIR}/uv"
mv uv-${UV_ARCH}/uvx "${INSTALL_DIR}/uvx"
chmod +x "${INSTALL_DIR}/uv" "${INSTALL_DIR}/uvx"

# Verify installation
echo ""
echo "=== Installation Complete ==="
echo ""
"${INSTALL_DIR}/uv" version
echo ""
echo "uv location: ${INSTALL_DIR}/uv"
echo "uvx location: ${INSTALL_DIR}/uvx (symlink)"
echo ""
echo "All users can now run:"
echo "  uv --version"
echo "  uvx --version"
echo ""

# Cleanup
rm -rf "${TEMP_DIR}"

echo "Done!"