#!/bin/sh

set -e

OS=""
ENVC=""
ARCH=""
TMP_FILE=""
EXTRACT_DIR=""
NIMBLE_BIN="${NIMBLE_DIR:-$HOME/.nimble}/bin"

mkdir -p "$NIMBLE_BIN"

UNAME_S="$(uname -s)"
case $UNAME_S in
    Linux*)     OS="linux";;
    Darwin*)    OS="macosx";;
    CYGWIN*|MINGW*|MSYS*) OS="windows";;
    *)          echo "Currently Unsupported OS: $UNAME_S"; exit 1;;
esac

UNAME_M="$(uname -m)"
case $UNAME_M in
    x86_64*)    ARCH="amd64";;
    i386*|i686*)      ARCH="i386";;
    armv8*|arm64*|aarch64*) ARCH="arm64";;
    riscv32*) ARCH="riscv32";;
    riscv64*) ARCH="riscv64";;
    *)          echo "Currenty Unsupported CPU: $UNAME_M"; exit 1;;
esac

if [ "$OS" = "macosx" ]; then
  ENVC="_none"
elif [ "$OS" = "linux" ]; then
  # musl is hard to detect by design, so we are using a hack
  LDD_VERSION="$(ldd --version 2>&1 || echo GNU)"
  case $LDD_VERSION in
      musl*) ENVC="_musl";;
      *) ENVC="_gnu";; # default is GNU libc
  esac
fi

BASE_URL="https://codeberg.org/janAkali/grabnim/releases/download/ci-latest"
FILE_NAME="grabnim_${OS}${ENVC}_${ARCH}"

if [ "$OS" = "windows" ]; then
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}.zip"
    TMP_FILE=$(mktemp --suffix=.zip)
else
    DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}.tar.xz"
    TMP_FILE=$(mktemp)
fi

echo "Downloading grabnim for ${OS}-${ARCH}..."
if command -v curl >/dev/null 2>&1; then
    curl -L "$DOWNLOAD_URL" -o "$TMP_FILE"
elif command -v wget >/dev/null 2>&1; then
    wget "$DOWNLOAD_URL" -O "$TMP_FILE"
else
    echo "Neither curl nor wget found. Please install one of them."
    exit 1
fi

echo "Extracting files..."
if [ "$OS" = "windows" ]; then
    if command -v unzip >/dev/null 2>&1; then
        EXTRACT_DIR=$(mktemp -d)
        unzip "$TMP_FILE" -d "$EXTRACT_DIR"
        SUBDIR="${FILE_NAME}"
        cp "$EXTRACT_DIR/$SUBDIR/"* "$NIMBLE_BIN/"
    else
        echo "unzip not found. Please install unzip."
        exit 1
    fi
else
    if command -v tar >/dev/null 2>&1; then
        tar -xf "$TMP_FILE" -C "$NIMBLE_BIN"
    else
        echo "tar not found. Please install tar."
        exit 1
    fi
fi

rm "$TMP_FILE"
if [ -n "$EXTRACT_DIR" ]; then
    rm -rf "$EXTRACT_DIR"
fi

echo "Installation complete!"
echo ""
case "$OS" in
    linux)
        echo "Add these paths to ~/.profile or ~/.bash_profile and logout to apply changes."
        echo "    export PATH=\"$HOME/.nimble/bin:\$PATH\""
        echo "    export PATH=\"$HOME/.local/share/grabnim/current/bin:\$PATH\""
        echo ""
        echo "Nim needs a C compiler in order to compile software"
        echo "  You can install gcc or clang with your package manager"
        ;;
    macosx)
        echo "Add these paths to /etc/paths and restart Terminal to apply changes:"
        echo "    $HOME/.nimble/bin"
        echo "    $HOME/.local/share/grabnim/current/bin"
        echo ""
        echo "Nim needs a C compiler in order to compile software"
        echo "  You can install one by running this command in the Terminal:"
        echo "    xcode-select --install"
        ;;
    windows)
        echo "Setup C compiler and PATH env by running this command in the Terminal:"
        echo "    $NIMBLE_BIN\\grabnim.exe setup"
        echo ""
        echo "Or do it manually:"
        echo "  Add directories to your PATH:"
        echo "    $NIMBLE_BIN"
        echo "    %LOCALAPPDATA%\\grabnim\\current\\bin"
        echo ""
        echo "  Note: Restart your Terminal to apply changes"
        echo ""
        echo "  You can download MinGW C compiler from Nim website:"
        echo "    https://nim-lang.org/install_windows.html"
        echo "  Unpack it and add 'bin' directory to PATH, e.g. 'C:\\mingw64\\bin'"
        echo ""
        echo "  Note: Cygwin C compiler is not supported by Nim"
        ;;
esac
