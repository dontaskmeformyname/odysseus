# llama.cpp server with Vulkan backend for AMD GPUs (RDNA 2/3/4).
#
# Uses the official pre-built Vulkan image from llama.cpp's GHCR registry.
# No source compilation needed — faster builds, official binaries.
#
# Unlike the ROCm overlay (docker/gpu.amd.yml), this backend needs no ROCm
# userspace — only the Mesa RADV Vulkan driver, which ships with every
# mainstream Linux distro. This makes it the recommended path for RDNA 2
# cards (RX 6000 series) that only have "Limited" ROCm support.
#
# Build:
#   docker compose -f docker-compose.yml -f docker/llama-vulkan.yml build llama-vulkan
#
# Run (with AMD GPU overlay):
#   COMPOSE_FILE=docker-compose.yml:docker/llama-vulkan.yml
#   # Plus, if the Odysseus container itself needs GPU access:
#   COMPOSE_FILE=docker-compose.yml:docker/gpu.amd.yml:docker/llama-vulkan.yml

# Pin a stable llama.cpp release tag for reproducibility.
# See: https://github.com/ggml-org/llama.cpp/pkgs/container/llama.cpp
ARG LLAMA_CPP_TAG=server-vulkan-b9265

FROM ghcr.io/ggml-org/llama.cpp:${LLAMA_CPP_TAG}

# Install Vulkan runtime + Mesa RADV drivers. The official image includes
# the Vulkan loader, but we ensure RADV is present for AMD GPUs.
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    mesa-vulkan-drivers \
    libvulkan1 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# The official llama.cpp image places binaries in /app which is not in PATH.
ENV PATH="/app:${PATH}"

COPY docker/llama-vulkan/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/models"]

EXPOSE 8082

ENTRYPOINT ["/entrypoint.sh"]
