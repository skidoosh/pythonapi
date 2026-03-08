FROM python:3.14-alpine3.23 AS base

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

COPY pyproject.toml uv.lock

FROM base AS release-base

WORKDIR /app

COPY . .

RUN UV_NO_DEV=1 uv sync --frozen --no-cache

FROM scratch AS release

COPY --from=release-base / /

CMD ["/app/.venv/bin/fastapi", "run", "/app/app/main.py", "--port", "8080", "--host", "0.0.0.0"]