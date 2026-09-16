# utils

Personal dotfiles and scripts, bootstrapped onto any machine with `setup.sh`.

Split into two scopes:

- `common/` — universal, safe on any machine
- `work/` — company-specific (work email, internal IPs, board/kernel scripts)

## Install

```bash
./setup.sh install                     # common/ only
./setup.sh install work                # common/ + work/
./setup.sh install work looks tools    # + cosmetic (looks) and functional (tools) extras
source ~/.bashrc
```

## Layout

- `common/alias` — shell aliases, sourced and live-reloaded every prompt
- `common/profile` — plain default prompt (`user@host:path (branch)$`), history, and shell
  options, sourced once per shell. Works anywhere, no font dependency.
- `common/profile.looks` — the fancy colored/powerline prompt, only sourced (on top of
  `profile`) when the `looks` scope is installed
- `common/vimrc` — symlinked to `~/.vimrc`
- `work/gitconfig`, `work/ssh_config` — symlinked to `~/.gitconfig`, `~/.ssh/config`
- `work/copy`, `work/flash` — scripts, made runnable anywhere via `PATH` (only when `work` scope is installed)

No tmux config lives in this repo — it isn't managed here at all. `zellij` (terminal
multiplexer) is installed as a plain user-local binary into `~/.local/bin` on every
`install`, same download-not-vendor approach as everything else below. No config file is
tracked for it yet (stock defaults); add `common/zellij_config.kdl`, symlinked to
`~/.config/zellij/config.kdl`, once there are actual overrides worth keeping.

`setup.sh install` backs up any pre-existing config it would overwrite as `<file>.bak`.

`setup.sh uninstall` is a **full, unconditional teardown** — no scope flags needed. It
removes everything this repo has ever installed: all symlinks (restoring `.bak` backups if
present), `zellij`, the Nerd Font, `eza`, `bat`, and `fzf` (deleting the actual downloaded
files, not just config wiring). Install-then-uninstall leaves nothing behind. Re-run
`install [work] [looks] [tools]` afterward to set it back up.

Two optional extra scopes for `install` only (`uninstall` always removes everything
regardless), split by what they actually give you:

`looks` — cosmetic, no new capability, just nicer-looking output:
- Swaps the prompt from the plain default to `common/profile.looks` (colored segments,
  powerline triangles) via a local `.looks_enabled` marker (gitignored, not shared config)
- JetBrainsMono Nerd Font, downloaded from its GitHub releases into `~/.local/share/fonts`
  (not vendored in this repo — binary, ~130MB). After installing, set it as your terminal
  emulator's font manually to see the icon/powerline glyphs — that part can't be scripted.
- `eza`, `bat` — colorized `ls`/`cat` replacements, downloaded as static binaries into
  `~/.local/bin`. `common/alias` already has `command -v` checks that pick them up
  automatically once installed.

`tools` — functional, changes what you can actually do:
- `fzf` — fuzzy history/file search (`Ctrl+R`/`Ctrl+T`), genuinely different from bash's
  built-in reverse-search, not just a visual upgrade. Cloned into `~/.fzf` via its official
  installer (key-bindings and completion, but not its own `~/.bashrc` hook, since
  `setup.sh` wires it in itself).

Both scopes install entirely under `$HOME` — no `sudo`, nothing system-wide. Need network
access once, at install time.

## Scripts

### `copy`

Copies a file/dir between local and remote paths (`user@host:/path` syntax), or use a preset:

- `rkernel` / `rmodule` / `rdt` — push kernel image / modules / device-tree overlay from the build host to the board
- `lkernel` / `lmodule` / `ldt` — pull the same from the build host to this machine

### `flash`

Flashes an image (`.img`/`.wic`, optionally compressed) to a removable device. Auto-detects the image in the current directory and the target device if not given. Defaults to `bmaptool`; pass `raw` to use `dd` instead.
