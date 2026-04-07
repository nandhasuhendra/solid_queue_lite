# Changelog

## 0.2.0

- Reworked the main dashboard to provide unified pulse, jobs, processes, and recurring task tabs.
- Added recurring task monitoring with last-run, next-run, and latest status visibility.
- Improved queue discovery from worker configuration and process metadata, including wildcard handling.
- Switched queue-specific and telemetry KPI counts to exact values for fresh installs.
- Added Rails 8 and newer Solid Queue compatibility in the gem dependency constraints.
- Improved relative time formatting and process/queue operational controls.

## 0.1.0

- Initial public release of Solid Queue Lite.
- Added a mockup-aligned dashboard experience for pulse, jobs, processes, and recurring tasks.
- Added queue discovery from Solid Queue worker configuration and process metadata.
- Added exact queue and telemetry counts for fresh installs.
- Added recurring task monitoring with last-run and next-run visibility.
- Added queue control actions, job drill-downs, retry/discard operations, and telemetry sampling support.
