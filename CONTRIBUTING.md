# Contributing to DesmoSTORM

DesmoSTORM is under active development as a MATLAB application for
super-resolution image analysis. Contributions should keep the app usable for
current analysis workflows while preserving the separation between app,
model, analysis, export, and vendored dependency code.

## Setup

Clone the repository, open MATLAB, navigate to the repository root, and run:

```matlab
desmostorm.launch
```

The launcher performs setup when needed, including MATLAB path setup, matlabx
setup, Bio-Formats configuration, UI calibration, and settings migration.

## Development Guidelines

- Keep changes scoped to the feature or bug being addressed.
- Prefer existing package boundaries and local patterns over new abstractions.
- Keep model code free of GUI prompts and UI-specific behavior.
- Keep export and analysis code callable outside the GUI when practical.
- Do not edit `external/` directly except when intentionally updating a
  vendored dependency such as matlabx.
- Do not commit generated user data, logs, large local test outputs, `.asv`
  files, `.DS_Store`, or other machine-local artifacts.
- Update README, NOTICE, or other docs when changing user-visible behavior,
  dependencies, bundled assets, or licensing metadata.

## Checks

Before committing MATLAB code changes, run targeted checks where practical:

```matlab
checkcode("path/to/file.m")
```

For app-level changes, launch DesmoSTORM and smoke-test the affected workflow.
For analysis/export changes, test at least one representative project or region.
For matlabx API updates, verify ImageAxes tools, overlays, event routing, and
cluster/debug workflows still line up with DesmoSTORM usage.

## Licensing And Notices

DesmoSTORM is licensed under GPL-2.0-or-later. New DesmoSTORM-owned source
files should include the project GPL header used throughout the repository.

Vendored matlabx carries its own `LICENSE`, `NOTICE`, citation metadata, and
third-party notices under `external/matlabx/`. Keep those files intact when
updating the dependency.

If new third-party code, data, models, lookup tables, or binary assets are
added directly to DesmoSTORM, preserve upstream license files where available
and document them in the top-level `NOTICE`.

## Commit Style

Use short, imperative commit messages:

```text
Add ROI overlay export options
Fix project colormap initialization
Document Box tool gestures
```

For larger work, commit in coherent chunks so releases and regressions are
easier to review.
