#!/bin/bash
set -euo pipefail

# ============================================================
# llama.cpp Vulkan server entrypoint
#
# Model discovery order:
#   1. LLAMA_MODEL env var — explicit path to a .gguf file
#   2. Ollama blob directory — auto-detect GGUF files from
#      Ollama's model storage (no re-download needed)
#   3. /models directory — manually downloaded GGUF files
#
# If multiple models are found, the largest one is selected
# (heuristic: larger = more capable). Override with LLAMA_MODEL.
# ============================================================

PORT="${LLAMA_VULKAN_PORT:-8082}"
CTX_SIZE="${LLAMA_VULKAN_CTX:-8192}"
GPU_LAYERS="${LLAMA_VULKAN_NGL:-999}"
THREADS="${LLAMA_VULKAN_THREADS:-$(nproc)}"
HOST="${LLAMA_VULKAN_HOST:-0.0.0.0}"
EXTRA_ARGS="${LLAMA_VULKAN_EXTRA_ARGS:-}"

# The official llama.cpp image installs the server binary to /app/.
# Use an absolute path so this script works regardless of PATH.
LLAMA_SERVER_BIN="/app/llama-server"

# --- Model discovery ---
MODEL_PATH=""

# 1. Explicit path
if [ -n "${LLAMA_MODEL:-}" ] && [ -f "${LLAMA_MODEL}" ]; then
    MODEL_PATH="${LLAMA_MODEL}"
    echo "[llama-vulkan] Using explicit model: ${MODEL_PATH}"
fi

# 2. Ollama blobs — scan for GGUF magic bytes
if [ -z "${MODEL_PATH}" ] && [ -d "/ollama-models/models/blobs" ]; then
    echo "[llama-vulkan] Scanning Ollama blob directory for GGUF files..."
    largest_size=0
    largest_file=""
    for blob in /ollama-models/models/blobs/*; do
        [ -f "$blob" ] || continue
        # Check for GGUF magic: offset 0, bytes "GGUF"
        magic=$(head -c 4 "$blob" 2>/dev/null || true)
        if [ "$magic" = "GGUF" ]; then
            size=$(stat -c%s "$blob" 2>/dev/null || echo 0)
            if [ "$size" -gt "$largest_size" ]; then
                largest_size="$size"
                largest_file="$blob"
            fi
            echo "[llama-vulkan]   Found GGUF: $blob ($(numfmt --to=iec $size 2>/dev/null || echo ${size}B))"
        fi
    done
    if [ -n "$largest_file" ]; then
        MODEL_PATH="$largest_file"
        echo "[llama-vulkan] Auto-selected: ${MODEL_PATH} ($(numfmt --to=iec $largest_size 2>/dev/null || echo ${largest_size}B))"
    fi
fi

# 3. /models directory
if [ -z "${MODEL_PATH}" ] && [ -d "/models" ]; then
    echo "[llama-vulkan] Scanning /models for GGUF files..."
    largest_size=0
    largest_file=""
    while IFS= read -r -d '' f; do
        magic=$(head -c 4 "$f" 2>/dev/null || true)
        if [ "$magic" = "GGUF" ]; then
            size=$(stat -c%s "$f" 2>/dev/null || echo 0)
            if [ "$size" -gt "$largest_size" ]; then
                largest_size="$size"
                largest_file="$f"
            fi
            echo "[llama-vulkan]   Found GGUF: $f ($(numfmt --to=iec $size 2>/dev/null || echo ${size}B))"
        fi
    done < <(find /models -name '*.gguf' -print0 2>/dev/null)
    if [ -n "$largest_file" ]; then
        MODEL_PATH="$largest_file"
        echo "[llama-vulkan] Auto-selected: ${MODEL_PATH} ($(numfmt --to=iec $largest_size 2>/dev/null || echo ${largest_size}B))"
    fi
fi

# Fail fast if no model found
if [ -z "${MODEL_PATH}" ]; then
    echo "[llama-vulkan] ERROR: No GGUF model found."
    echo "[llama-vulkan] Options:"
    echo "[llama-vulkan]   1. Set LLAMA_MODEL=/path/to/model.gguf"
    echo "[llama-vulkan]   2. Mount Ollama's model volume to /ollama-models (read-only)"
    echo "[llama-vulkan]   3. Place .gguf files in /models/"
    echo "[llama-vulkan]   4. Download: huggingface-cli download <repo> <file> --local-dir /models"
    exit 1
fi

echo "[llama-vulkan] Model: ${MODEL_PATH}"
echo "[llama-vulkan] Context: ${CTX_SIZE}, GPU layers: ${GPU_LAYERS}, Threads: ${THREADS}"
echo "[llama-vulkan] Starting server on ${HOST}:${PORT}"
echo "[llama-vulkan] OpenAI-compatible API at http://localhost:${PORT}/v1"

exec "${LLAMA_SERVER_BIN}" \
    --model "${MODEL_PATH}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --ctx-size "${CTX_SIZE}" \
    --n-gpu-layers "${GPU_LAYERS}" \
    --threads "${THREADS}" \
    ${EXTRA_ARGS}
