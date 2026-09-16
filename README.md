# utils

Personal dotfiles and scripts, bootstrapped onto any machine with `setup.sh`.

Split into two scopes:

- `common/` — universal, safe on any machine
- `work/` — company-specific (work email, internal IPs, board/kernel scripts)

## Install

```bash
./setup.sh install              # common/ only
./setup.sh install work         # common/ + work/
./setup.sh install work font    # + JetBrainsMono Nerd Font (downloaded, not vendored)
source ~/.bashrc
```

## Layout

- `common/alias` — shell aliases, sourced and live-reloaded every prompt
- `common/profile` — prompt (PS1), history, and shell options, sourced once per shell
- `common/vimrc`, `common/tmux.conf` — symlinked to `~/.vimrc`, `~/.tmux.conf`
- `work/gitconfig`, `work/ssh_config` — symlinked to `~/.gitconfig`, `~/.ssh/config`
- `work/copy`, `work/flash` — scripts, made runnable anywhere via `PATH` (only when `work` scope is installed)

`setup.sh install` backs up any pre-existing config it would overwrite as `<file>.bak`.
`setup.sh uninstall [work]` removes the bashrc hook and symlinks, restoring backups if present.

`font` downloads JetBrainsMono Nerd Font from its GitHub releases and installs it to
`~/.local/share/fonts` — not vendored in this repo (binary, ~130MB). Needs network access
once, at install time. After installing, set it as your terminal emulator's font manually
to see the icon/powerline glyphs — that part can't be scripted from here.

## Scripts

### `copy`

Copies a file/dir between local and remote paths (`user@host:/path` syntax), or use a preset:

- `rkernel` / `rmodule` / `rdt` — push kernel image / modules / device-tree overlay from the build host to the board
- `lkernel` / `lmodule` / `ldt` — pull the same from the build host to this machine

### `flash`

Flashes an image (`.img`/`.wic`, optionally compressed) to a removable device. Auto-detects the image in the current directory and the target device if not given. Defaults to `bmaptool`; pass `raw` to use `dd` instead.
