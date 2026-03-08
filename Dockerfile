FROM python:3.14-alpine3.23 AS base

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

FROM base AS dev-base

RUN apk add --no-cache bash

COPY --from=ghcr.io/astral-sh/ruff:0.15 /ruff /bin/

COPY --from=ghcr.io/astral-sh/ty:0.0.21 /ty /bin/

COPY --from=ghcr.io/homebrew/core/go-task:3.49.1 /go-task/3.49.1/bin/task /bin/

COPY pyproject.toml uv.lock ./

RUN uv sync --locked

FROM scratch AS dev

COPY --from=dev-base / /

FROM base AS release-base

COPY . .

RUN UV_NO_DEV=1 uv sync --frozen --no-cache

FROM scratch AS release

COPY --from=release-base / /

CMD ["/app/.venv/bin/fastapi", "run", "/app/app/main.py", "--port", "8080", "--host", "0.0.0.0"]