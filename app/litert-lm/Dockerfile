# Install uv
FROM python:3.14-slim AS builder
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
