FROM ghcr.io/astral-sh/uv:0.11.2 AS uv
FROM ghcr.io/homebrew/core/go-task:3.49.1 AS taskfile

FROM registry.access.redhat.com/hi/python:3.14.10-builder AS dev-base

USER root

ENV PYTHONPATH="/app"

WORKDIR /app

COPY --from=uv /uv /uvx /bin/
COPY --from=taskfile /go-task/3.49.1/bin/task /bin/
COPY pyproject.toml uv.lock ./

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_INSTALLER_METADATA=1
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=never

RUN --mount=type=secret,id=proxy_ca,required=false \
    if [ -f /run/secrets/proxy_ca ]; then export SSL_CERT_FILE=/run/secrets/proxy_ca; fi && \
    uv export --frozen --no-emit-workspace --no-editable -o requirements.txt && \
    uv pip install -r requirements.txt --target .


FROM dev-base AS test

COPY --chown=65532:65532 app/ ./app/

ENV COVERAGE_FILE=/tmp/.coverage

USER 65532:65532

RUN python3 -m pytest -p no:cacheprovider


FROM scratch AS dev

COPY --from=dev-base / /


FROM registry.access.redhat.com/hi/python:3.14.10-builder AS release-build

USER root

COPY --from=uv /uv /uvx /bin/

WORKDIR /app

COPY pyproject.toml uv.lock ./
COPY app/ .

ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_INSTALLER_METADATA=1
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=never

RUN --mount=type=secret,id=proxy_ca,required=false \
    if [ -f /run/secrets/proxy_ca ]; then export SSL_CERT_FILE=/run/secrets/proxy_ca; fi && \
    uv export --frozen --no-emit-workspace --no-dev --no-editable -o requirements.txt && \
    uv pip install -r requirements.txt --target . && \
    find . -name '*_tests.py' -delete


FROM registry.access.redhat.com/hi/python:3.14.10 AS release-base

COPY --from=release-build /app /app


FROM scratch AS release

ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/tmp"
ENV PYTHONPATH="/app"

WORKDIR /app

COPY --from=release-base / /

USER 65532:65532

CMD ["/app/bin/fastapi", "run", "/app/main.py", "--port", "8080", "--host", "0.0.0.0"]
