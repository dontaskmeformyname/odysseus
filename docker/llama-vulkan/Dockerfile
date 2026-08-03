# llama.cpp server with Vulkan backend for AMD GPUs (RDNA 2/3/4).
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
# Bump deliberately after testing — floating tags break reproducibility.
ARG LLAMA_CPP_REF=b4200

FROM docker.io/ubuntu:24.04 AS builder

ARG LLAMA_CPP_REF

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    ca-certificates \
    libcurl4-openssl-dev \
    libvulkan-dev \
    glslang-tools \
    && rm -rf /var/lib/apt/lists/*

# Clone at pinned ref.
RUN git clone --depth 1 --branch ${LLAMA_CPP_REF} \
    https://github.com/ggml-org/llama.cpp.git /llama.cpp

# Build with Vulkan backend.
RUN cmake -S /llama.cpp -B /llama.cpp/build \
    -DGGML_VULKAN=ON \
    -DLLAMA_CURL=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=ON \
    && cmake --build /llama.cpp/build --config Release -j$(nproc) \
    && cp /llama.cpp/build/bin/llama-server /llama-server \
    && cp /llama.cpp/build/bin/llama-cli /llama-cli

# --- Runtime stage ---
FROM docker.io/ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Vulkan loader + Mesa RADV drivers (userspace). This is all that's needed
# at runtime — no ROCm, no HIP, no kfd. The kernel DRI driver (amdgpu)
# handles the rest via /dev/dri.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /llama-server /usr/local/bin/llama-server
COPY --from=builder /llama-cli /usr/local/bin/llama-cli
COPY docker/llama-vulkan/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/models"]

EXPOSE 8082

ENTRYPOINT ["/entrypoint.sh"]
