import logging
import os

import azure.functions as func
from azure.cosmos import CosmosClient
from azure.cosmos.exceptions import CosmosResourceNotFoundError

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

DATABASE_NAME = "resume"
CONTAINER_NAME = "counters"
COUNTER_ID = "visitor-count"

_client = None


def _get_container():
    # Lazily created so a cold start doesn't pay the connection cost until the
    # first real request, and so importing this module (e.g. in tests) never
    # requires COSMOS_CONNECTION_STRING to be set.
    global _client
    if _client is None:
        connection_string = os.environ["COSMOS_CONNECTION_STRING"]
        _client = CosmosClient.from_connection_string(connection_string)
    database = _client.get_database_client(DATABASE_NAME)
    return database.get_container_client(CONTAINER_NAME)


@app.route(route="count", methods=["GET"])
def get_count(req: func.HttpRequest) -> func.HttpResponse:
    # COUNTER_ID is a fixed constant, never derived from request input -- no
    # externally-supplied value ever reaches Cosmos, so there's no injection
    # surface on this endpoint at all (see Security.md checklist #3).
    try:
        container = _get_container()
        try:
            # Atomic increment via Cosmos's patch "incr" operation -- avoids a
            # read-then-write race between concurrent requests. Verify this
            # exact patch_item()/operation syntax against the azure-cosmos SDK
            # version actually installed before relying on it (flagged per
            # ROADMAP.md's "verify before building" convention).
            item = container.patch_item(
                item=COUNTER_ID,
                partition_key=COUNTER_ID,
                patch_operations=[{"op": "incr", "path": "/count", "value": 1}],
            )
        except CosmosResourceNotFoundError:
            item = container.upsert_item({"id": COUNTER_ID, "count": 1})

        return func.HttpResponse(
            body=f'{{"count": {item["count"]}}}',
            status_code=200,
            mimetype="application/json",
            headers={"Access-Control-Allow-Origin": _allowed_origin()},
        )
    except Exception:
        # Generic message only -- no internal details (connection info, stack
        # trace) leak into the response. See Security.md checklist.
        logging.exception("Failed to read/increment visitor count")
        return func.HttpResponse(
            body='{"error": "unable to retrieve visitor count"}',
            status_code=500,
            mimetype="application/json",
        )


def _allowed_origin() -> str:
    # Defense-in-depth only -- the real call path is same-origin through the
    # SWA proxy (Security.md #6). Locked to the deployed hostname via app
    # setting; verify whether this should instead be configured at the SWA
    # resource level (staticwebapp.config.json / Bicep) rather than per-function.
    return os.environ.get("ALLOWED_ORIGIN", "")
