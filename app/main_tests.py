import pytest
from fastapi.testclient import TestClient

from .main import app

client = TestClient(app)


def test_index():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello World"}


def test_health_check():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.parametrize("path", ["/", "/healthz"])
def test_endpoints_return_json(path):
    response = client.get(path)
    assert response.headers["content-type"] == "application/json"


@pytest.mark.parametrize("path", ["/", "/healthz"])
@pytest.mark.parametrize("method", ["POST", "PUT", "PATCH", "DELETE"])
def test_endpoints_are_read_only(method, path):
    response = client.request(method, path)
    assert response.status_code == 405


def test_unknown_path_returns_not_found():
    response = client.get("/does-not-exist")
    assert response.status_code == 404
