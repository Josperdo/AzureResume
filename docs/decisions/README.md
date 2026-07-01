# Architecture Decision Records

Short, honest records of the biggest calls in this project — including the ones that traded away a "better" design for cost, and the one gate that got dropped rather than paid for. Full context in [`../architecture.md`](../architecture.md).

## 1. SWA Free tier + managed Functions, not Standard + BYOF

**Decision:** Use Azure Static Web Apps' Free tier with its built-in managed Functions, instead of Standard tier with a separate, standalone Function App (bring-your-own-Functions).

**Why:** The original design used Standard + BYOF specifically so the Function could get a system-assigned managed identity and authenticate to Cosmos DB via RBAC — zero keys anywhere. Standard tier costs ~$9-12/month (~$108-144/year), which conflicts with this project's ~$20-25/year budget for a portfolio piece.

**Trade-off accepted:** Verified against Microsoft's own SWA feature-comparison table (not assumed) that Free tier's managed-Functions model categorically cannot use managed identity — the underlying Function App isn't exposed as a controllable ARM resource at all on Free tier. Chose to stay on Free tier and accept a connection string instead (see ADR #2), rather than blow the budget for a feature the platform doesn't actually support at this tier.

## 2. Cosmos connection string, not managed identity — and how it's mitigated

**Decision:** Authenticate to Cosmos DB via a connection string, resolved live at deploy time.

**Why:** Direct consequence of ADR #1 — managed identity isn't available on SWA Free tier's managed Functions, full stop.

**Mitigation:** Bicep resolves the connection string via `listConnectionStrings()` on the Cosmos account resource and writes it directly into the SWA's `functionappsettings` child resource, entirely within a single deployment's internal data flow. It never becomes a GitHub Actions secret, never appears in a `.bicepparam` file, and is excluded from deployment outputs. This is the strongest mitigation available without managed identity.

**Known, accepted limitation:** Unlike the RBAC design this replaced, Cosmos primary/secondary keys grant access to the entire account — there's no container-scoped key. Accepted deliberately for a low-stakes portfolio resource (an inflated visitor count is cosmetic, not a real risk); the answer to "what would you change at higher stakes" is exactly the original design.

## 3. Cosmos provisioned free-tier, not serverless

**Decision:** `enableFreeTier: true` on a provisioned-throughput Cosmos account, not a serverless account.

**Why:** Confirmed before building: Cosmos's genuinely-$0 free tier (1000 RU/s + 25GB) only applies to provisioned/autoscale accounts. Serverless is cheap and simple, but has no free allowance at all — it would have been a small ongoing cost instead of $0.

## 4. Python over Node/TS for the API

**Decision:** The Function API is Python (Azure Functions v2 programming model), not Node/TypeScript.

**Why:** The original architecture revision started as Node/TS + SWA Standard + BYOF + Cosmos managed identity. When that got re-scoped for budget (ADR #1), the API was also switched to Python — partly to diversify the visible skill set in this portfolio beyond just JS/TS, partly because Python's `azure-cosmos` SDK and Functions tooling are equally first-class on SWA's managed-Functions model.

## 5. CI/CD infra-deploy manual-approval gate — descoped, not silently dropped

**Decision:** `infra.yml`'s Bicep deploy job targets a `production` GitHub Environment, but that environment has no required-reviewer protection rule configured.

**Why:** GitHub only allows required-reviewer protection rules on private repositories with GitHub Pro/Team/Enterprise, or for free on public repositories. This repo stayed private. Rather than pay for a plan upgrade or make the repo public purely to unlock one protection rule, the gate was deliberately dropped — with a single contributor on this project, a required-reviewer step wasn't adding real protection anyway.

**What's still real:** Bicep `what-if` still runs on every PR touching `infra/**`, so the exact resource diff is visible before merge. The `production` environment still exists (its name has to match the federated credential's OIDC subject for authentication to work), it just runs unattended rather than pausing for approval.

## 6. Custom domain: TXT validation, not a bare CNAME, for the apex

**Decision:** `josperdo.com` (apex/root domain) is validated via `dns-txt-token`, not a plain CNAME.

**Why:** Apex domains can't use a CNAME per DNS spec — only subdomains can. Azure Static Web Apps requires TXT-based domain-ownership validation specifically for apex custom domains. Once validated, actual traffic routing uses a CNAME at `@`, which Cloudflare auto-flattens at the apex (a Cloudflare-specific feature, not standard DNS behavior). `www.josperdo.com` redirects to the apex via a Cloudflare Redirect Rule instead of being registered as a second Azure custom domain, avoiding a second TXT-validation cycle for a hostname that's only ever supposed to bounce elsewhere.
