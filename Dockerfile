FROM ghcr.io/astral-sh/uv:0.11.2 AS uv
FROM ghcr.io/homebrew/core/go-task:3.49.1 AS taskfile

FROM dhi.io/python:3.14-alpine3.23-dev  AS dev-base

ENV PYTHONPATH="/app"

WORKDIR /app

COPY --from=uv/uv /uvx /bin/
COPY --from=taskfile /go-task/3.49.1/bin/task /bin/
COPY pyproject.toml uv.lock ./

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_INSTALLER_METADATA=1
ENV UV_LINK_MODE=copy

RUN uv export --frozen --no-emit-workspace --no-editable -o requirements.txt && \
    uv pip install -r requirements.txt --target .


FROM scratch AS dev

COPY --from=dev-base / /


FROM dhi.io/python:3.14-alpine3.23-dev AS release-build

COPY --from=uv /uv /uvx /bin/

WORKDIR /app

COPY pyproject.toml uv.lock ./
COPY app/ .

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_INSTALLER_METADATA=1
ENV UV_LINK_MODE=copy

RUN uv export --frozen --no-emit-workspace --no-dev --no-editable -o requirements.txt && \
    uv pip install -r requirements.txt --target .


FROM dhi.io/python:3.14-alpine3.23 AS release-base

COPY --from=release-build /app /app


FROM scratch AS release

ENV PYTHONPATH="/app"

WORKDIR /app

COPY --from=release-base / /

USER nonroot

CMD ["/app/bin/fastapi", "run", "/app/main.py", "--port", "8080", "--host", "0.0.0.0"]