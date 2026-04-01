#!/usr/bin/env bash
set -euo pipefail

REPO="so-jelly/hops"
APP_DIR="/Applications/hops.app"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "Fetching latest release..."
DOWNLOAD_URL="$(curl -sf "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' \
  | head -1 \
  | cut -d'"' -f4)"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Error: no release found" >&2
  exit 1
fi

TAG="$(echo "$DOWNLOAD_URL" | grep -o '/[0-9]*/hops' | tr -d '/hops')"
echo "Installing hops ${TAG}..."

curl -sfL "$DOWNLOAD_URL" -o "$TMP_DIR/hops.zip"
unzip -qo "$TMP_DIR/hops.zip" -d "$TMP_DIR"

if [[ -d "$APP_DIR" ]]; then
  rm -rf "$APP_DIR"
fi
mv "$TMP_DIR/hops.app" "$APP_DIR"

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_DIR"

echo "hops ${TAG} installed to ${APP_DIR}"
