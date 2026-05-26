#!/usr/bin/env bash
# Stages llama-server + runtime dylibs for bundling inside the macOS .app.
# Output:
#   build/engine/llama-server
#   build/engine/lib/*.dylib
#
# Requires Homebrew llama.cpp on the build machine (matches brew install llama.cpp).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_DIR="$ROOT/build/engine"
LIB_DIR="$ENGINE_DIR/lib"
OUT_BIN="$ENGINE_DIR/llama-server"

if ! command -v brew >/dev/null 2>&1 || ! brew list llama.cpp &>/dev/null; then
  echo "==> Installing llama.cpp via Homebrew (build-time dependency)"
  brew install llama.cpp
fi

LLAMA_PREFIX="$(brew --prefix llama.cpp)"
GGML_PREFIX="$(brew --prefix ggml)"
OMP_PREFIX="$(brew --prefix libomp)"
SSL_PREFIX="$(brew --prefix openssl@3)"

rm -rf "$ENGINE_DIR"
mkdir -p "$LIB_DIR"

echo "==> Staging llama-server from $LLAMA_PREFIX"
cp "$LLAMA_PREFIX/bin/llama-server" "$OUT_BIN"
chmod +x "$OUT_BIN"

for src in \
  "$LLAMA_PREFIX/lib/"*.dylib \
  "$GGML_PREFIX/lib/"*.dylib \
  "$OMP_PREFIX/lib/libomp.dylib" \
  "$SSL_PREFIX/lib/libssl.3.dylib" \
  "$SSL_PREFIX/lib/libcrypto.3.dylib"
do
  [ -f "$src" ] || continue
  cp "$src" "$LIB_DIR/"
done

echo "==> Self-test staged engine"
if ! DYLD_LIBRARY_PATH="$LIB_DIR" "$OUT_BIN" --version >/dev/null 2>&1; then
  echo "✗ Staged llama-server failed --version" >&2
  exit 1
fi

echo "==> Engine ready: $OUT_BIN ($(find "$LIB_DIR" -name '*.dylib' | wc -l | tr -d ' ') dylibs)"
