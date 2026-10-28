# LiteRT-LM server. Two images are built from this file:
#   --target download  the model is imported at runtime (`litert-lm import`)
#   --target bundled   the model is built into the image (default target)

# Model built into the "bundled" image.
ARG MODEL_ID=gemma-4-E2B-it.litertlm
ARG MODEL_HF_REPO=litert-community/gemma-4-E2B-it-litert-lm
ARG MODEL_HF_FILE=gemma-4-E2B-it.litertlm

# Install uv
FROM python:3.14-slim AS download
COPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv /uvx /bin/

# Use the system Python across both stages
ENV UV_PYTHON_DOWNLOADS=0

# Install dependencies
RUN --mount=type=cache,target=/root/.cache/uv \
    uv tool install litert-lm==0.18.1
ENV PATH="${PATH}:/root/.local/bin"

RUN apt update && \
    apt install -y libvulkan1 && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Run the application
CMD ["litert-lm", "serve"]

# Downloads the model once on the build platform: the file is the same for
# every architecture.
FROM --platform=$BUILDPLATFORM download AS model
ARG MODEL_ID
ARG MODEL_HF_REPO
ARG MODEL_HF_FILE
ENV LITERT_LM_DIR=/opt/litert-lm
RUN litert-lm import --from-huggingface-repo="${MODEL_HF_REPO}" "${MODEL_HF_FILE}" "${MODEL_ID}"

# The model lives outside /root/.litert-lm, so a model cache volume mounted
# at /root/.litert-lm/models does not hide it.
FROM download AS bundled
ARG MODEL_ID
ENV LITERT_LM_DIR=/opt/litert-lm \
    LITERT_LM_MODEL_ID=${MODEL_ID}
# Only the models directory: the import also leaves a download cache behind.
COPY --from=model /opt/litert-lm/models /opt/litert-lm/models
