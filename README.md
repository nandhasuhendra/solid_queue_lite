# Solid Queue Lite

A minimal, zero-build web interface for [Solid Queue](https://github.com/rails/solid_queue).

The official `mission_control-jobs` engine is great, but it brings along Turbo, Stimulus, and expects a standard Rails asset pipeline. If you run an API-only app, use a modern JS framework, or just want to avoid frontend dependencies in your infrastructure tooling, Solid Queue Lite provides the same operational visibility without the build-step baggage.

### Core Design Decisions

* **Zero Asset Pipeline:** The UI is built with raw HTML, Pico.css, and Alpine.js loaded via CDN. It adds nothing to your app's frontend build.
* **Database Safe:** Standard job dashboards often kill primary databases with naive `COUNT(*)` queries on massive tables. This engine strictly uses database metadata (e.g., `pg_class` in Postgres) for approximate counting to prevent sequential scans and lock contention.
* **Built-in Telemetry:** Solid Queue doesn't store historical data. This engine includes a lightweight, self-pruning background job that snapshots queue sizes, latency, and error rates, giving you 24-hour trends without needing an external APM.
* **Multi-tenant Support:** Exposes a simple configuration block to scope the dashboard's database queries, allowing you to isolate job visibility per tenant.

### Features

* Monitor active Supervisors, Workers, and Dispatchers.
* Filter and inspect Ready, In-Progress, Scheduled, and Failed jobs.
* View job arguments (JSON), full stack traces, and execute individual or bulk retries/discards.
* Configurable auto-refresh that automatically pauses when you interact with the UI to prevent state loss.
