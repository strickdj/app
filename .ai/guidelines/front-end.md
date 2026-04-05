# Frontend Development Guidelines

## Verification Scripts

- Do not create verification scripts or tinker when tests cover that functionality and prove they work. Unit and feature tests are more important.
- After modifying frontend code or shared JavaScript/TypeScript/Vue files, run `npm run fix` and then `npm run check` before finalizing.
- `npm run fix` applies formatting and lint fixes. `npm run check` runs type-checking, lint checks, and format checks.
