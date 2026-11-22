FROM ghcr.io/astral-sh/uv:0.11.2 AS uv
FROM ghcr.io/homebrew/core/go-task:3.49.1 AS taskfile

FROM python:3.14-alpine3.24  AS dev-base

ENV PYTHONPATH="/app"

WORKDIR /app

COPY --from=uv /uv /uvx /bin/
COPY --from=taskfile /go-task/3.49.1/bin/task /bin/
COPY pyproject.toml uv.lock ./

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_INSTALLER_METADATA=1
ENV UV_LINK_MODE=copy

RUN --mount=type=secret,id=proxy_ca,required=false \
    if [ -f /run/secrets/proxy_ca ]; then export SSL_CERT_FILE=/run/secrets/proxy_ca; fi && \
    uv export --frozen --no-emit-workspace --no-editable -o requirements.txt && \
    uv pip install -r requirements.txt --target .


FROM dev-base AS test

COPY app/ ./app/

RUN python -m pytest


FROM scratch AS dev

COPY --from=dev-base / /


FROM python:3.14-alpine3.24 AS release-build

COPY --from=uv /uv /uvx /bin/

WORKDIR /app

COPY pyproject.toml uv.lock ./
COPY app/ .

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_INSTALLER_METADATA=1
ENV UV_LINK_MODE=copy

RUN --mount=type=secret,id=proxy_ca,required=false \
    if [ -f /run/secrets/proxy_ca ]; then export SSL_CERT_FILE=/run/secrets/proxy_ca; fi && \
    uv export --frozen --no-emit-workspace --no-dev --no-editable -o requirements.txt && \
    uv pip install -r requirements.txt --target .


FROM python:3.14-alpine3.24 AS release-base

COPY --from=release-build /app /app


FROM scratch AS release

ENV PYTHONPATH="/app"

WORKDIR /app

COPY --from=release-base / /

USER nonroot

CMD ["/app/bin/fastapi", "run", "/app/main.py", "--port", "8080", "--host", "0.0.0.0"]