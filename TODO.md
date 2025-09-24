# Remediation Roadmap TODOs

## Phase 1 – Restore Django startup integrity
- **Status:** ✅ Completed (2024-05-05)
- **Deliverables & Evidence**
  - [x] Implemented the shared middleware scaffolding referenced in settings so Django boots without `ModuleNotFoundError` exceptions.
  - [x] Validated the middleware stack with `python manage.py check` once the missing modules were added.
- **Follow-ups**
  - [ ] Backfill developer documentation describing when to enable or disable each custom middleware class.
  - [ ] Capture baseline startup timings to benchmark future performance-focused changes.

## Phase 2 – Stabilize user registration & profile flows
- **Status:** ✅ Completed (2024-05-05)
- **Deliverables & Evidence**
  - [x] Corrected the registration serializer to return the created user and to source email verification token helpers from a shared utility.
  - [x] Added unit tests that cover successful registration, password mismatches, and email verification creation to guard against regressions.
- **Follow-ups**
  - [ ] Expand coverage to include duplicate email handling and signal-driven profile provisioning.
  - [ ] Exercise the registration flow end-to-end through the API documentation sandbox once it is back online.

## Phase 3 – Repair Google Drive OAuth integration
- **Status:** ✅ Completed (2024-05-06)
- **Work Breakdown**
  - [x] Replace the nonexistent `utils.google_drive_service` import with a concrete module under `apps.integrations.services`.
  - [x] Implement the Google Drive service abstraction, covering credential exchange, folder bootstrap, and persistence helpers.
  - [x] Align OAuth callback serializers and views with the actual credential fields returned by Google (refresh token, expiry, scopes).
  - [x] Add integration-style tests that mock Google APIs to assert the callback succeeds and handles failures gracefully.
- **Definition of Done**
  - [x] Connect and disconnect endpoints complete locally with mocked Google APIs.
  - [x] Access tokens persist to user profiles and refresh automatically when expired.
  - [x] Regression tests pass for both the happy path and expected error cases.

## Phase 4 – Align analytics & dashboard data models
- **Status:** ✅ Completed (2024-05-07)
- **Deliverables & Evidence**
  - [x] Updated the advanced and personal analytics dashboards to rely on the canonical `Video.uploader` relation, eliminating runtime attribute errors.
  - [x] Exercised the restored `AnalyticsEvent.party` and `.video` relations when enriching dashboard statistics to confirm context is available across responses.
- **Follow-ups**
  - [ ] Audit the remaining apps (search, admin panel, mobile) for any lingering `uploaded_by` lookups and align them with `Video.uploader`.
  - [ ] Broaden analytics fixtures to cover personal and advanced dashboards for future regression tests.

## Phase 5 – Establish automated test coverage
- **Status:** ✅ Completed (2024-05-08)
- **Work Breakdown**
  - [x] Expand pytest suites to cover authentication, dashboard analytics, Google Drive flows, and websocket messaging smoke tests.
  - [x] Stand up reusable factories/fixtures for common objects (users, parties, videos, analytics events).
  - [x] Provide a CI-ready entrypoint so pipelines can invoke the test suite and block on failures.
- **Deliverables & Evidence**
  - [x] Added `tests/factories.py` and shared pytest fixtures to quickly assemble users, videos, parties, and analytics events for future suites.
  - [x] Created API and Channels smoke tests that exercise registration/login, analytics dashboards, and WebSocket heartbeat handling.
  - [x] Introduced `scripts/development/run_tests.sh` for CI and local developers to run migrations and execute pytest under the testing settings module.
- **Follow-ups**
  - [ ] Extend coverage to chat, notifications, and Celery tasks as those systems stabilise.
  - [ ] Integrate the new test script with the hosted CI provider so pipeline configuration automatically invokes it.
- **Definition of Done**
  - [x] The core smoke-test suite executes in under ten minutes via the new pytest entrypoint, ready for CI adoption.
  - [x] Remediation guidance now calls for new features to ship with tests, tracked within this roadmap.
  - [x] Test documentation explains how to run targeted suites locally (unit vs. integration vs. websocket).

## Phase 6 – Follow-up hardening & observability
- **Status:** ✅ Completed (2024-05-09)
- **Work Breakdown**
  - [x] Exercise Celery workers, caching, and monitoring hooks under representative load to validate configuration via `verify_observability`.
  - [x] Document operational runbooks covering background jobs, caching tiers, alerting integrations, and failure recovery drills.
  - [x] Add missing observability instrumentation (structured logging, metrics, tracing) to high-risk views and tasks.
- **Deliverables & Evidence**
  - [x] Added `shared/observability.py`, Celery signal hooks, and middleware instrumentation that emit metrics/events for HTTP, database, cache, and task activity.
  - [x] Introduced `python manage.py verify_observability` to exercise the cache backend, execute a Celery task, and report captured spans/metrics.
  - [x] Authored `docs/maintenance/observability_runbook.md` outlining validation steps, dashboards, and alerting follow-ups for operations teams.
- **Definition of Done**
  - [x] Celery workers and scheduled tasks run reliably in staging with actionable monitoring alerts configured through the observability collector.
  - [x] Caching strategy, invalidation rules, and warm-up routines are documented and validated.
  - [x] Observability dashboards surface performance, usage, and error trends for ongoing operations.

## Cross-phase coordination
- [ ] Schedule weekly remediation checkpoints to review progress, surface blockers, and reprioritize tasks as new information arrives.
- [ ] Track dependencies between phases (e.g., analytics fixtures required before broad test coverage) in project management tooling.
- [ ] Communicate updates to stakeholders after each completed phase with evidence of verification (tests, demos, metrics).
