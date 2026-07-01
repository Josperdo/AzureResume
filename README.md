# Azure Resume Challenge

My build of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/docs/the-challenge/azure/) on Azure — a static portfolio/resume site backed by a serverless Python visitor-counter API, fully defined as Infrastructure-as-Code and deployed via CI/CD.

**Live site:** _not deployed yet_
**Status:** in progress — see the build log below.

---

## Architecture

```
Browser
  │  HTTPS
  ▼
Azure Static Web App (Free tier)
  │  /api/* proxied same-origin to the managed Python Function
  ▼
Azure Functions (Python, SWA-managed)
  │  reads/increments a counter via the Cosmos DB connection string
  │  (wired in by Bicep at deploy time -- never stored in a GitHub secret,
  │   parameter file, or git history)
  ▼
Azure Cosmos DB (NoSQL API, provisioned throughput, free tier)
```

| Layer | Choice |
|---|---|
| Frontend | Static HTML/CSS/vanilla JS, no framework |
| Hosting | Azure Static Web Apps — Free tier, managed Functions (no separate Function App resource) |
| API | Python, Azure Functions v2 programming model |
| Database | Azure Cosmos DB (NoSQL API), provisioned throughput with `enableFreeTier: true` |
| IaC | Bicep |
| CI/CD | GitHub Actions — one workflow deploys frontend + API together, a second handles Bicep `what-if`/deploy |

**Budget:** targeting ~$20-25/year, essentially all of it just custom domain registration.

## Why these choices (a couple worth calling out)

- **SWA Free tier over Standard:** Standard tier would have allowed a standalone Function App with a system-assigned managed identity authenticating to Cosmos via RBAC — zero keys anywhere. It also costs ~$9-12/month (~$108-144/year), which blew this project's budget by 4-6x. Free tier's managed-Functions model can't use managed identity at all (confirmed against Microsoft's own SWA docs), so this uses a Cosmos connection string instead — mitigated by having Bicep resolve it live at deploy time (`listConnectionStrings()`) straight into the Function App setting, so it never touches a GitHub secret, a parameter file, or git history. Full writeup of this trade-off in the project's internal security notes (not published — see below).
- **Cosmos provisioned throughput with free tier, not serverless:** Cosmos DB's free tier (1000 RU/s + 25GB, genuinely $0) only applies to provisioned/autoscale accounts, not serverless.

## Repo layout

```
.github/workflows/   GitHub Actions: combined frontend+API deploy, Bicep IaC pipeline
infra/                Bicep templates (Cosmos DB, Static Web App)
src/frontend/         Static site (HTML/CSS/JS)
src/api/               Python Azure Functions API
tests/                 Unit tests (pytest, mocked Cosmos client)
docs/                  Architecture notes / decision records
```

## Running locally

**Frontend:**
```
cd src/frontend
python -m http.server 8080
```

**API tests:**
```
python -m venv .venv
.venv/Scripts/activate   # or source .venv/bin/activate on macOS/Linux
pip install -r tests/requirements.txt
pytest tests/
```

## Security considerations

- No secrets committed to source control at any point — the Cosmos connection string is resolved live during infrastructure deployment and never appears in a GitHub secret, parameter file, or git history.
- All Azure resources are provisioned via Bicep — no manual portal configuration.
- CORS is same-origin by design (the frontend calls `/api/*` as a relative path through the Static Web App's proxy), with an explicit origin lock as defense-in-depth.
- Infrastructure changes go through a `what-if` diff on every pull request and a manual approval gate before deploying to the live resource group.

## License

MIT — see [LICENSE](LICENSE).
