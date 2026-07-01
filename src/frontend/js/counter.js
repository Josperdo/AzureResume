// Calls GET /api/count as a relative path -- proxied same-origin through SWA's
// managed Functions backend, so this never makes a cross-origin request.
// See Security.md #6.
//
// The count is intentionally not displayed anywhere in the UI -- this just
// keeps the counter incrementing in Cosmos DB on each page load. Fire-and-
// forget: nothing to update on success, nothing to show on failure.
fetch("/api/count").catch(() => {});
