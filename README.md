# Pet Status Lite

A compact, configurable Hunter pet status panel for WoW Forever.

## Install

Use `dist/PetStatusLite.zip` after a local build. Follow the [install instructions](PetStatusLite/README.md).

## Develop

From the repository root, run the offline behavior and package checks with Python 3.12:

```text
python -m pip install --target .tools -r tests/requirements.txt
python tests/test_addon.py
python tests/test_package.py
python tools/package.py
```

The build outputs the stable ZIP, a versioned ZIP, and checksums under `dist/`. For a release, update the TOC version and `.github/RELEASE_NOTES.md`, then tag the release commit with the matching version prefixed by `v`.

## Forever smoke test

In-client verification is pending. On a Hunter, compare the panel with the character sheet and its pet happiness indicator. Earn XP on a pet below your level. Confirm the bar fills below the XP row, enable the pace and estimate, and watch both update after two XP gains over at least 30 seconds. Feed the pet, dismiss it, and summon it again. Check both minimap clicks, drag the panel, and confirm the options and position survive `/reload`.
