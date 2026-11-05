# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Self-contained Wand launcher installer: packages the launcher source,
  virtual environment, wemod_data, and the `wand` wrapper into the repository
  itself. No external clone or upstream dependency at install time.
- Global, per-user installer workflow: everything installs under
  `~/.local/share/wand-launcher`, with no system-wide or root-owned files.
- `wand` launch wrapper: moves leading `KEY=VALUE` launch-option tokens into the
  real environment before executing the launcher, fixing the
  `[Errno 2] No such file or directory` crash.
- Patched the launcher's `dotnet48` download bug (absolute cache path was joined
  again by `popup_download()`).
- Optional `--game <AppID>` mode for Steam games: downloads Wand's prepared
  prefix, keeps the game's user data (saves, configs) inside the new prefix, and
  refuses to run when the downloaded prefix looks wrong or is incomplete.
- README rewritten with a simple install guide, per-game setup section, and
  shared-mod instructions.

### Fixed
- Launcher did not start because environment-variable-only launch options were
  passed as program arguments; fixed in the `wand` wrapper.
- `.NET error` / "Wand will not start" caused by a Proton major version
  mismatch; now documented and addressable with a prepared prefix or
  `GE-Proton10-*`.

## [1.0.0] - 2026-11-05

### Added
- Initial CachyOS / Arch Linux installer for Wand (WeMod) launcher.
- Steam launch options support with environment variables.
- Documentation and install script.
