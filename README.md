# utils

Personal dotfiles and scripts, bootstrapped onto any machine with `setup.sh`.

## Install

```bash
./setup.sh install
source ~/.bashrc
```

## Layout

- `alias` — shell aliases, sourced and live-reloaded every prompt
- `profile` — prompt (PS1), history, and shell options, sourced once per shell
- `vimrc`, `tmux.conf`, `gitconfig` — symlinked to `~/.vimrc`, `~/.tmux.conf`, `~/.gitconfig`
- `copy`, `flash` — scripts, made runnable anywhere via `PATH`

`setup.sh install` backs up any pre-existing config it would overwrite as `<file>.bak`.
`setup.sh uninstall` removes the bashrc hook and symlinks, restoring backups if present.

## Scripts

### `copy`

Copies a file/dir between local and remote paths (`user@host:/path` syntax), or use a preset:

- `rkernel` / `rmodule` / `rdt` — push kernel image / modules / device-tree overlay from the build host to the board
- `lkernel` / `lmodule` / `ldt` — pull the same from the build host to this machine

### `flash`

Flashes an image (`.img`/`.wic`, optionally compressed) to a removable device. Auto-detects the image in the current directory and the target device if not given. Defaults to `bmaptool`; pass `raw` to use `dd` instead.
