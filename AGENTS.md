# AGENTS.md

## Stack & Versions
- Language(s): (detect from manifests/lockfiles)
- Framework(s): (name + exact version)
- Key libraries: (name + exact version)
- Source of truth: lockfiles/manifests (pnpm-lock.yaml, package-lock.json, poetry.lock, Pipfile.lock, Cargo.lock, etc.)

## Docs Lock (via context7)
_For each dependency you touch, refresh via **context7** and record below **before** coding._
| dependency | version | doc URL | checked_at (UTC) | notes |
|------------|---------|---------|------------------|-------|
|            |         |         |                  |       |

## MCP Usage Matrix
- **context7**: authoritative docs, migrations, deprecations. Use **before any coding**; update Docs Lock.
- **GitHub**: read/write repo ops (search/tree/blame, issues/PRs/branches/commits/CI). Also used to commit `README.md` & `AGENTS.md` updates **before and after** every action.
- **Stripe**: test-mode customers/prices/payments/setup intents/webhooks; simulate events; verify idempotency keys; never expose secrets; document live rollout separately.
- **Hugging Face**: model/dataset/Space selection; record **model card + license + exact revision/SHA** in Docs Lock; deterministic seeds for tests (when available).
- **Apify**: run actors; fetch datasets; define/validate stable schemas; capture dataset contracts for integration tests; mind rate limits/robots/TOS.

## Policies
- **Tests Always**: new code → new tests; touching untested legacy → add **characterization tests first**.
- **No mock data/simulation/shortcuts/truncation**. Provide real test-mode or local fixtures; justify any unavoidable placeholders with a removal plan.
- **Pre/Post Doc Sync**: `README.md` & `AGENTS.md` must be updated **immediately before** and **immediately after** each action.
- **Security**: no secrets in code/logs; validate inputs; escape outputs; least privilege; record secret names (not values) and where they are supplied.
- **Performance**: avoid N+1; protect hot paths; add micro-benchmarks when perf is a goal.
- **Compliance/Licensing**: record licenses (esp. HF models/datasets) and constraints; ensure compatible usage.

## Quality Gates (commands; adapt to project)
```bash
npm run lint && npm run typecheck && npm run format:check
npm test && npm run test:integration && npm run test:e2e
npm run build
npm audit || true
```

## Operational Runbook
- Migrations: idempotent `up`/`down`, pre/post validation, backfill strategy, rollback steps.
- Seeding: deterministic seeds; data shape documented.
- Smoke checks: endpoints/CLI/cron; health/readiness probes.

## Contribution Workflow
- Branch naming, PR template, review gates (security/perf/accessibility where relevant), release tagging, changelog policy.
