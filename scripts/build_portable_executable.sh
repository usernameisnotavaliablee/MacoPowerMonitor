#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacoPowerMonitor"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_CONSTANTS_PATH="$ROOT_DIR/Sources/MacoPowerMonitor/Support/AppConstants.swift"
ARCH="$(uname -m)"

cd "$ROOT_DIR"

APP_VERSION="$(awk -F'\"' '/appVersion/ { print $2; exit }' "$APP_CONSTANTS_PATH")"
if [[ -z "$APP_VERSION" ]]; then
  echo "Could not determine app version from $APP_CONSTANTS_PATH" >&2
  exit 1
fi

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  swift build -c release
fi

EXECUTABLE_PATH="$(find "$BUILD_DIR" -type f -path "*/release/$APP_NAME" | head -n 1)"
if [[ -z "$EXECUTABLE_PATH" ]]; then
  echo "Could not find release executable for $APP_NAME" >&2
  exit 1
fi

PORTABLE_DIR="$DIST_DIR/$APP_NAME-v$APP_VERSION-macos-$ARCH"
PORTABLE_EXECUTABLE="$PORTABLE_DIR/$APP_NAME"
LAUNCHER_PATH="$PORTABLE_DIR/Launch $APP_NAME.command"
README_PATH="$PORTABLE_DIR/README.txt"

rm -rf "$PORTABLE_DIR"
mkdir -p "$PORTABLE_DIR"
cp "$EXECUTABLE_PATH" "$PORTABLE_EXECUTABLE"
chmod +x "$PORTABLE_EXECUTABLE"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$PORTABLE_EXECUTABLE" >/dev/null 2>&1 || true
fi

cat > "$LAUNCHER_PATH" <<'LAUNCHER'
#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT_DIR/MacoPowerMonitor"
LAUNCHER
chmod +x "$LAUNCHER_PATH"

cat > "$README_PATH" <<EOF_README
Maco Power Monitor 免安装可执行文件

- 直接在终端中运行：
    ./MacoPowerMonitor
- 或双击“Launch MacoPowerMonitor.command”。
- 程序运行后会显示在 macOS 菜单栏；关闭终端或按 Control-C 可结束进程。
- 不需要移动到 Applications；但“开机自启”仅在 .app 版本中可用。
- 此构建目标为 macOS 13+、$ARCH 架构。
EOF_README

echo "Built portable executable bundle:"
echo "$PORTABLE_DIR"
