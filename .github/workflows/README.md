# CI Workflows

This directory contains GitHub Actions workflows for the project.

## `ci.yml`

`ci.yml` is the main CI pipeline and runs on pushes to `main` and on all pull requests.

It has three jobs:

1. **`changes`**
   - Uses `dorny/paths-filter` to detect whether PHP-related or JS-related files changed.
   - Exposes two outputs: `php` and `js`.

2. **`php`**
   - Runs only when `changes.outputs.php == 'true'`.
   - Executes checks in fail-fast order:
     1. Pint (`vendor/bin/pint --parallel --test`)
     2. Rector dry run (`vendor/bin/rector process --dry-run --ansi`)
     3. PHPStan (`vendor/bin/phpstan analyse --memory-limit=256M`)
     4. Tests (`php artisan test --compact`)

3. **`js`**
   - Runs only when `changes.outputs.js == 'true'`.
   - Executes frontend checks:
     1. `npm run types:check`
     2. `npm run lint:check`
     3. `npm run format:check`

## Why path-based jobs?

Path filtering avoids running unrelated jobs. For example:

- PHP-only changes skip the JS job.
- JS-only changes skip the PHP job.

This reduces CI time and resource usage while keeping checks strict for changed areas.

## Notes

- If both PHP and JS files change, both jobs run.
- If no matched files change for a job, that job is skipped by design.

## `build_deploy.yml`

`build_deploy.yml` is a combined manual workflow that builds a release archive and immediately deploys it in the same run.

- It installs production PHP dependencies, builds frontend assets, optimizes Laravel, and packages the deployable files into `release.tar.gz`.
- It uploads that archive as a workflow artifact named `release-<commit-sha>` for traceability.
- It then uploads `release.tar.gz` to the server and runs `deployme.sh` in dry-run or live mode.

### When to use it

- Use `build_deploy.yml` when you want the simplest deployment flow with no cross-workflow artifact lookup.
- The older `build_release.yml` + `deploy.yml` flow can still exist, but `build_deploy.yml` avoids artifact handoff complexity.

