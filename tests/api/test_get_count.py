import json
from unittest.mock import MagicMock, patch

import azure.functions as func
from azure.cosmos.exceptions import CosmosResourceNotFoundError

import function_app


def _request() -> func.HttpRequest:
    return func.HttpRequest(method="GET", url="/api/count", body=None)


def test_get_count_increments_existing_counter():
    mock_container = MagicMock()
    mock_container.patch_item.return_value = {"id": "visitor-count", "count": 43}

    with patch.object(function_app, "_get_container", return_value=mock_container):
        response = function_app.get_count(_request())

    assert response.status_code == 200
    assert json.loads(response.get_body()) == {"count": 43}
    mock_container.patch_item.assert_called_once_with(
        item="visitor-count",
        partition_key="visitor-count",
        patch_operations=[{"op": "incr", "path": "/count", "value": 1}],
    )
    mock_container.upsert_item.assert_not_called()


def test_get_count_creates_counter_on_first_run():
    mock_container = MagicMock()
    mock_container.patch_item.side_effect = CosmosResourceNotFoundError(
        message="not found", status_code=404
    )
    mock_container.upsert_item.return_value = {"id": "visitor-count", "count": 1}

    with patch.object(function_app, "_get_container", return_value=mock_container):
        response = function_app.get_count(_request())

    assert response.status_code == 200
    assert json.loads(response.get_body()) == {"count": 1}
    mock_container.upsert_item.assert_called_once_with(
        {"id": "visitor-count", "count": 1}
    )


def test_get_count_returns_500_without_leaking_internals_on_cosmos_failure():
    mock_container = MagicMock()
    mock_container.patch_item.side_effect = RuntimeError(
        "AccountEndpoint=https://example.documents.azure.com;AccountKey=super-secret"
    )

    with patch.object(function_app, "_get_container", return_value=mock_container):
        response = function_app.get_count(_request())

    assert response.status_code == 500
    body = response.get_body().decode()
    assert "super-secret" not in body
    assert json.loads(body) == {"error": "unable to retrieve visitor count"}
