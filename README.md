# myconfig

Personal dotfiles and scripts. One flat repo, one command to set up, works
anywhere from a bare embedded board to a full desktop.

```bash
git clone https://github.com/hsu26zq/myconfig.git
cd myconfig
./setup.sh install
source ~/.bashrc
```

No `git`? Download it as a tarball instead:

```bash
curl -L https://github.com/hsu26zq/myconfig/archive/refs/heads/main.tar.gz | tar xz
cd myconfig-main
./setup.sh install
source ~/.bashrc
```

`./setup.sh uninstall` fully reverses everything below - every symlink,
every downloaded binary, and git/ssh identity changes (restoring whatever
was there before, not just deleting it). Install-then-uninstall leaves the
machine exactly as it was.

## Design

- **One command, no flags.** `install`/`uninstall` always attempt
  everything. There's no "scope" to remember.
- **Best-effort, never all-or-nothing.** Each tool install is independent -
  no network, wrong architecture, or no matching release asset just skips
  that one tool with a message and keeps going. Dotfiles/prompt always
  succeed regardless, since they don't need network access.
- **Architecture-aware.** Detects `x86_64` vs `aarch64` (`uname -m`) and
  downloads the matching build for each tool.
- **Everything user-local.** Every file this touches lives under `$HOME`
  (mostly `~/.local/bin`) - no `sudo`, nothing system-wide.
- **No git dependency for any tool install.** Everything is a direct binary
  download, so this works even on a machine with no `git` at all (the
  reason to have `git` is just to clone this repo in the first place - the
  no-git tarball method above works around even that).

## Layout

```
myconfig/
├── setup.sh
├── alias, profile, vimrc, starship.toml   # dotfiles, always symlinked/sourced
├── copy, flash                            # scripts, always on PATH
├── identity.env.example                   # tracked template
└── identity.env                           # LOCAL ONLY, gitignored, you create this
```

- `profile` sets up history/shell options and the prompt: `starship` if it
  installed successfully, a plain fallback prompt (still shows git branch)
  if not - so a bare board with no network still gets a working shell.
- `copy SOURCE DEST` - plain generic copy. Either side can be local or
  `user@host:/path`, either can be a file or directory, trailing slash
  never changes behavior (the source always lands under DEST). No presets,
  no hardcoded hosts.
- `flash [raw] [device] [image]` - flashes an image to a removable device,
  auto-detecting the image/device if not given.

## `identity.env` (git/SSH identity)

This repo never contains your actual git email or internal host IPs -
that data lives in `identity.env`, which is gitignored and lives only on
each machine you create it on:

```bash
cp identity.env.example identity.env
nano identity.env
./setup.sh install
```

Recognized keys (all optional - a machine with no `identity.env`, or one
missing some keys, just skips whatever it doesn't have):

- `GIT_EMAIL`, `GIT_NAME` - applied via `git config --global`. Whatever was
  already configured is backed up first and restored on `uninstall` - your
  own prior identity is never lost, only ever set aside.
- `BUILDHOST_IP`, `BUILDHOST_USER`, `BOARD_IP`, `BOARD_USER` - generates
  SSH `Host buildhost` / `Host board` entries (in `~/.ssh/config.d/`,
  included from `~/.ssh/config` via one added `Include` line), so
  `ssh buildhost` / `copy board:/path .` work without typing IPs.

**Values with spaces must be quoted** (`GIT_NAME="Your Name"`) -
`identity.env` is read as shell code, and an unquoted space breaks it.

## Tools installed

Cosmetic (nicer output, no new capability): JetBrainsMono Nerd Font
(set it as your terminal's font manually - that part can't be scripted),
`eza`, `bat`, `delta`, `btop`, `starship`.

Functional (new capability): `fzf` (fuzzy `Ctrl+R`/`Ctrl+T` search),
`ripgrep` (`rg`), `fd`, `zoxide` (`z`), `jq`, `lazygit`, `zellij`.

`ncdu` was considered but isn't distributed as a prebuilt binary release,
so it doesn't fit this repo's no-sudo/no-vendoring approach.
