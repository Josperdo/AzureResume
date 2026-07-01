// Calls GET /api/count as a relative path -- proxied same-origin through SWA's
// managed Functions backend, so this never makes a cross-origin request.
// See Security.md #6.
//
// The API isn't deployed yet (Milestone 3), so this fails gracefully and
// leaves the placeholder dash in place rather than showing an error.
(async function loadVisitorCount() {
  const el = document.getElementById("visitor-count");
  if (!el) return;

  try {
    const response = await fetch("/api/count");
    if (!response.ok) throw new Error(`Unexpected status ${response.status}`);
    const data = await response.json();
    el.textContent = data.count;
  } catch (err) {
    el.textContent = "—";
  }
})();
