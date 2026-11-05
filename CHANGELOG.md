# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Global, per-user installer workflow: everything installs under
  `~/.local/share/wand-launcher`, with no system-wide or root-owned files.
- `wand` launch wrapper: moves leading `KEY=VALUE` launch-option tokens into the
  real environment before executing the launcher, fixing the
  `[Errno 2] No such file or directory` crash.
- Patched the launcher's `dotnet48` download bug (absolute cache path was joined
  again by `popup_download()`).
- New `--prepare-hfw` mode for Horizon Forbidden West Complete Edition
  (Steam AppID 2420110): downloads Wand's prepared prefix, keeps the existing
  game prefix and saves for rollback, and refuses to run when the download looks
  wrong.
- README rewritten to point at `rvnrootx/wand-linux-installer` for quick install,
  with the full HFW setup workflow, troubleshooting guide, and shared-mod
  instructions.

### Fixed
- Quick-install URL now points at the upstream
  [rvnrootx/wand-linux-installer](https://github.com/rvnrootx/wand-linux-installer)
  repository, not a fork.
- Launcher did not start because environment-variable-only launch options were
  passed as program arguments; fixed in the `wand` wrapper.
- `.NET error` / "Wand will not start" caused by a Proton major version
  mismatch; now documented and addressable with `--prepare-hfw` or
  `GE-Proton10-*`.

## [1.0.0] - 2026-11-05

### Added
- Initial CachyOS / Arch Linux installer for Wand (WeMod) launcher.
- Steam launch options support with environment variables.
- Documentation and install script.
