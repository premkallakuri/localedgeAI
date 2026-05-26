#!/usr/bin/env bash
# Downloads the default macOS GGUF model into build/models/ during compile/DMG build.
# Output: build/models/<defaultModel from AppConfig.json>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODELS_DIR="$ROOT/build/models"
mkdir -p "$MODELS_DIR"
cd "$ROOT"

DEFAULT_MODEL="$(python3 - <<'PY'
import json, pathlib
cfg = json.loads(pathlib.Path("Sources/LocalEdgeAI/Resources/AppConfig.json").read_text())
print(cfg["defaultModel"])
PY
)"

OUT="$MODELS_DIR/$DEFAULT_MODEL"

if [ -f "$OUT" ] && [ "$(stat -f%z "$OUT" 2>/dev/null || stat -c%s "$OUT")" -gt 100000000 ]; then
  echo "==> Model already present: $OUT"
  exit 0
fi

# Hugging Face GGUF mirror (Gemma 3 4B instruct, Q4_0 — matches AppConfig default).
HF_REPO="${HF_MODEL_REPO:-unsloth/gemma-3-4b-it-GGUF}"
HF_FILE="${HF_MODEL_FILE:-gemma-3-4b-it-Q4_0.gguf}"
URL="https://huggingface.co/${HF_REPO}/resolve/main/${HF_FILE}"

echo "==> Downloading $DEFAULT_MODEL from Hugging Face (~2.5 GB, cached in build/models/)"
echo "    $URL"
curl -L --fail --retry 3 --retry-delay 5 -C - -o "$OUT.part" "$URL"
mv "$OUT.part" "$OUT"

BYTES="$(stat -f%z "$OUT" 2>/dev/null || stat -c%s "$OUT")"
echo "==> Saved $OUT ($BYTES bytes)"
