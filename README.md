# Solid Queue Lite

A minimal, zero-build web interface for [Solid Queue](https://github.com/rails/solid_queue).

[![Gem Version](https://badge.fury.io/rb/solid_queue_lite.svg)](https://rubygems.org/gems/solid_queue_lite)

The official `mission_control-jobs` engine is great, but it brings along Turbo, Stimulus, and expects a standard Rails asset pipeline. If you run an API-only app, use a modern JS framework, or just want to avoid frontend dependencies in your infrastructure tooling, Solid Queue Lite provides the same operational visibility without the build-step baggage.

<img width="1512" height="1003" alt="574499032-9fe45dd4-f08f-4b12-b07e-b9394965b586" src="https://github.com/user-attachments/assets/a22f66d3-05a5-4d2a-ac01-ef219e40a038" />

## Installation

Add the engine to your host application's Gemfile:

```ruby
gem "solid_queue_lite"
```

Install dependencies, then run the engine migration:

```bash
bundle install
bin/rails solid_queue_lite:install
```

The installer copies the engine migration into the host app and creates `config/initializers/solid_queue_lite.rb` if it does not already exist.

Run the migration separately, or let the installer do it for you:

```bash
bin/rails db:migrate
# or
bin/rails solid_queue_lite:install MIGRATE=1
```

Mount the engine behind your application's own authentication boundary:

```ruby
# config/routes.rb
authenticate :user, ->(user) { user.admin? } do
	mount SolidQueueLite::Engine => "/ops/jobs"
end
```

The engine root renders the dashboard at `/ops/jobs`, and the jobs index is available at `/ops/jobs/jobs`.

## Requirements

- Ruby 3.1+
- Rails 7.1
- Solid Queue 1.x

If you are using Rails 8, you can install the gem normally without pinning Rails back to 7.x:

```ruby
gem "solid_queue_lite"
```

## Host Configuration

Use the configuration block to scope all dashboard reads in multi-tenant deployments:

```ruby
# config/initializers/solid_queue_lite.rb
SolidQueueLite.configure do |config|
	config.tenant_scope = lambda do |relation|
		relation.where(queue_name: Current.account.solid_queue_prefix)
	end
end
```

The lambda receives the Active Record relation before it is queried.

## Telemetry Sampling

The engine ships with `SolidQueueLite::TelemetrySamplerJob`, which writes aggregate queue snapshots into `solid_queue_lite_stats` and prunes samples older than 7 days.

If you use Solid Queue recurring tasks, schedule the sampler in your host application's recurring configuration:

```yml
# config/recurring.yml
production:
	solid_queue_lite_telemetry:
		class: SolidQueueLite::TelemetrySamplerJob
		schedule: every 5 minutes
		queue: default
```

Without a scheduler process, the dashboard still renders, but the historical charts stay empty until samples are written.

## Console And Tasks

The reusable logic now lives under `lib/solid_queue_lite`, so you can call the same APIs from a Rails console:

```ruby
SolidQueueLite::Telemetry.sample!
SolidQueueLite::Telemetry.backfill!
SolidQueueLite::Telemetry.dashboard_data(range_key: "24h")

SolidQueueLite::Jobs.list(state_key: "failed", page: 1, per_page: 50)
SolidQueueLite::Jobs.find(123)

SolidQueueLite::Processes.index_data
SolidQueueLite::Processes.pause_queue!("background")
```

To force an immediate current telemetry snapshot after upgrading, run:

```bash
bin/rake solid_queue_lite:telemetry:backfill
```

The historical `scheduled_count` and `success_count` series cannot be reconstructed exactly for old rows because Solid Queue does not retain that event history. The backfill task writes or refreshes a current snapshot immediately so upgraded installs do not need to wait for the next scheduled sample.

### Core Design Decisions

- **Zero Asset Pipeline:** The UI is built with raw HTML, Pico.css, and Alpine.js loaded via CDN. It adds nothing to your app's frontend build.
- **Database Safe:** Standard job dashboards often kill primary databases with naive `COUNT(*)` queries on massive tables. This engine strictly uses database metadata (e.g., `pg_class` in Postgres) for approximate counting to prevent sequential scans and lock contention.
- **Built-in Telemetry:** Solid Queue doesn't store historical data. This engine includes a lightweight, self-pruning background job that snapshots queue sizes, latency, and error rates, giving you 24-hour trends without needing an external APM.
- **Multi-tenant Support:** Exposes a simple configuration block to scope the dashboard's database queries, allowing you to isolate job visibility per tenant.

### Features

- Monitor active Supervisors, Workers, and Dispatchers.
- Filter and inspect Ready, In-Progress, Scheduled, and Failed jobs.
- View job arguments (JSON), full stack traces, and execute individual or bulk retries/discards.
- Configurable auto-refresh that automatically pauses when you interact with the UI to prevent state loss.
- Monitor recurring task schedule, last run time, next run time, and latest status from a dedicated dashboard tab.

## Releasing

Build the gem locally before publishing:

```bash
gem build solid_queue_lite.gemspec
```

Publish to RubyGems:

```bash
gem push solid_queue_lite-0.1.0.gem
```

Typical release flow:

1. Update `lib/solid_queue_lite/version.rb`.
2. Update `CHANGELOG.md`.
3. Commit and tag the release.
4. Build with `gem build solid_queue_lite.gemspec`.
5. Push with `gem push <built-gem-file>`.
