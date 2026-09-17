#!/bin/bash

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHRC="$HOME/.bashrc"
SOURCE_LINE="source \"$REPO_DIR/setup.sh\""
IDENTITY_FILE="$REPO_DIR/identity.env"
GIT_BACKUP_FILE="$REPO_DIR/.git_identity.bak"
SSH_FRAGMENT="$HOME/.ssh/config.d/myconfig"
SSH_INCLUDE_LINE="Include ~/.ssh/config.d/*"

# ---------------------------------------------------------------------------
# Sourced from ~/.bashrc on every new shell
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export PATH="$REPO_DIR:$HOME/.local/bin:$PATH"

    [[ -f "$HOME/.local/share/fzf/key-bindings.bash" ]] && source "$HOME/.local/share/fzf/key-bindings.bash"
    [[ -f "$HOME/.local/share/fzf/completion.bash" ]] && source "$HOME/.local/share/fzf/completion.bash"
    command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

    [[ -f "$REPO_DIR/profile" ]] && source "$REPO_DIR/profile"

    _utils_reload_aliases() {
        if [[ -n "${_UTILS_ALIAS_NAMES:-}" ]]; then
            for name in $_UTILS_ALIAS_NAMES; do
                unalias "$name" 2>/dev/null
            done
        fi

        _UTILS_ALIAS_NAMES=""

        if [[ -f "$REPO_DIR/alias" ]]; then
            _UTILS_ALIAS_NAMES=$(
                sed -n "s/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p" \
                    "$REPO_DIR/alias"
            )
            source "$REPO_DIR/alias"
        fi
    }

    _utils_reload_aliases

    case ";${PROMPT_COMMAND:-};" in
        *";_utils_reload_aliases;"*) ;;
        *)
            PROMPT_COMMAND="_utils_reload_aliases${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
            ;;
    esac

    return
fi

# ---------------------------------------------------------------------------
# install / uninstall
# ---------------------------------------------------------------------------

link_config() {
    local target="$1" link_path="$2"
    [[ "$target" != /* ]] && target="$REPO_DIR/$target"

    mkdir -p "$(dirname "$link_path")"

    if [[ -L "$link_path" ]]; then
        ln -sfn "$target" "$link_path"
        echo "  linked $link_path"
        return
    fi

    if [[ -e "$link_path" ]]; then
        mv "$link_path" "$link_path.bak"
        echo "  backed up $link_path -> $link_path.bak"
    fi

    ln -sfn "$target" "$link_path"
    echo "  linked $link_path"
}

unlink_config() {
    local link_path="$1"

    if [[ -L "$link_path" ]]; then
        rm "$link_path"
        if [[ -e "$link_path.bak" ]]; then
            mv "$link_path.bak" "$link_path"
            echo "  restored $link_path from backup"
        else
            echo "  removed $link_path"
        fi
    fi
}

# Architecture detection - every binary install below is best-effort: if the
# architecture is unrecognized, or there's no matching release asset, or
# there's no network, it's skipped with a message instead of aborting.
UNAME_ARCH="$(uname -m)"
case "$UNAME_ARCH" in
    x86_64) ARCH_RUST="x86_64"; ARCH_GO="amd64" ;;
    aarch64|arm64) ARCH_RUST="aarch64"; ARCH_GO="arm64" ;;
    *) ARCH_RUST=""; ARCH_GO="" ;;
esac

rust_pattern() {
    [[ -n "$ARCH_RUST" ]] && echo "${ARCH_RUST}-unknown-linux-$1\\.tar\\.gz"
}

go_pattern() {
    [[ -n "$ARCH_GO" ]] && echo "linux_${ARCH_GO}\\.tar\\.gz"
}

# Shared by any tool whose release tarball contains a binary named exactly
# like the command, whether at the archive root ("cmd", "./cmd") or nested
# in a versioned directory ("pkg-1.2.3/cmd").
install_binary() {
    local cmd="$1" repo="$2" asset_pattern="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  $cmd: already installed"
        return
    fi

    if [[ -z "$asset_pattern" ]]; then
        echo "  $cmd: skipped (no build for architecture $UNAME_ARCH)"
        return
    fi

    local url entry path
    url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -o "\"browser_download_url\": *\"[^\"]*${asset_pattern}\"" \
        | cut -d'"' -f4)
    if [[ -z "$url" ]]; then
        echo "  $cmd: skipped (couldn't reach GitHub or no matching release asset)"
        return
    fi

    if ! curl -fsSLo "/tmp/$cmd.tar.gz" "$url" 2>/dev/null; then
        echo "  $cmd: skipped (download failed)"
        return
    fi

    entry=$(tar -tzf "/tmp/$cmd.tar.gz" 2>/dev/null | grep -E "(^|/)$cmd\$" | head -1)
    if [[ -z "$entry" ]]; then
        echo "  $cmd: skipped (binary not found in archive)"
        rm -f "/tmp/$cmd.tar.gz"
        return
    fi

    path="${entry#./}"
    if tar -xzf "/tmp/$cmd.tar.gz" -C /tmp "$entry" 2>/dev/null \
        && cp "/tmp/$path" "$HOME/.local/bin/$cmd" \
        && chmod +x "$HOME/.local/bin/$cmd"; then
        echo "  $cmd: installed"
    else
        echo "  $cmd: skipped (extraction failed)"
    fi
    rm -rf "/tmp/$cmd.tar.gz" "/tmp/${path%%/*}"
}

install_font() {
    local name="JetBrainsMono Nerd Font"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    local dest="$HOME/.local/share/fonts"

    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        echo "  font: already installed"
        return
    fi

    mkdir -p "$dest"
    if curl -fsSLo "/tmp/jetbrainsmono-nerd-font.zip" "$url" 2>/dev/null; then
        unzip -oq "/tmp/jetbrainsmono-nerd-font.zip" -d "$dest" 2>/dev/null \
            && fc-cache -f "$dest" >/dev/null 2>&1 \
            && echo "  font: installed (set it as your terminal's font manually)"
        rm -f "/tmp/jetbrainsmono-nerd-font.zip"
    else
        echo "  font: skipped (download failed)"
    fi
}

install_jq() {
    if command -v jq >/dev/null 2>&1; then
        echo "  jq: already installed"
        return
    fi

    if [[ -z "$ARCH_GO" ]]; then
        echo "  jq: skipped (no build for architecture $UNAME_ARCH)"
        return
    fi

    local url
    url=$(curl -fsSL https://api.github.com/repos/jqlang/jq/releases/latest 2>/dev/null \
        | grep -o "\"browser_download_url\": *\"[^\"]*jq-linux-${ARCH_GO}\"" \
        | cut -d'"' -f4)
    if [[ -z "$url" ]]; then
        echo "  jq: skipped (couldn't reach GitHub or no matching release asset)"
        return
    fi

    if curl -fsSLo "$HOME/.local/bin/jq" "$url" 2>/dev/null; then
        chmod +x "$HOME/.local/bin/jq"
        echo "  jq: installed"
    else
        echo "  jq: skipped (download failed)"
    fi
}

install_fzf() {
    if command -v fzf >/dev/null 2>&1; then
        echo "  fzf: already installed"
    else
        install_binary fzf junegunn/fzf "$(go_pattern)"
    fi

    if command -v fzf >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/share/fzf"
        curl -fsSLo "$HOME/.local/share/fzf/key-bindings.bash" \
            https://raw.githubusercontent.com/junegunn/fzf/master/shell/key-bindings.bash 2>/dev/null \
            && echo "  fzf: key-bindings installed"
        curl -fsSLo "$HOME/.local/share/fzf/completion.bash" \
            https://raw.githubusercontent.com/junegunn/fzf/master/shell/completion.bash 2>/dev/null \
            && echo "  fzf: completion installed"
    fi
}

setup_identity() {
    if [[ ! -f "$IDENTITY_FILE" ]]; then
        echo "No identity.env - skipping git/ssh identity setup."
        return
    fi

    echo "Applying identity.env..."
    set -a
    # shellcheck disable=SC1090
    source "$IDENTITY_FILE"
    set +a

    if [[ -n "${GIT_EMAIL:-}" || -n "${GIT_NAME:-}" ]]; then
        if [[ ! -f "$GIT_BACKUP_FILE" ]]; then
            local prev_email prev_name
            prev_email="$(git config --global user.email 2>/dev/null || true)"
            prev_name="$(git config --global user.name 2>/dev/null || true)"
            {
                printf 'GIT_EMAIL_BAK=%q\n' "$prev_email"
                printf 'GIT_NAME_BAK=%q\n' "$prev_name"
            } > "$GIT_BACKUP_FILE"
        fi
        [[ -n "${GIT_EMAIL:-}" ]] && git config --global user.email "$GIT_EMAIL"
        [[ -n "${GIT_NAME:-}" ]] && git config --global user.name "$GIT_NAME"
        echo "  git identity configured"
    fi

    mkdir -p "$HOME/.ssh/config.d"
    chmod 700 "$HOME/.ssh"

    {
        if [[ -n "${BUILDHOST_IP:-}" ]]; then
            echo "Host buildhost"
            echo "  HostName ${BUILDHOST_IP}"
            echo "  User ${BUILDHOST_USER:-$USER}"
            echo
        fi
        if [[ -n "${BOARD_IP:-}" ]]; then
            echo "Host board"
            echo "  HostName ${BOARD_IP}"
            echo "  User ${BOARD_USER:-root}"
        fi
    } > "$SSH_FRAGMENT"

    if [[ -s "$SSH_FRAGMENT" ]]; then
        touch "$HOME/.ssh/config"
        if ! grep -Fqx "$SSH_INCLUDE_LINE" "$HOME/.ssh/config"; then
            { echo "$SSH_INCLUDE_LINE"; echo; cat "$HOME/.ssh/config"; } > "$HOME/.ssh/config.tmp"
            mv "$HOME/.ssh/config.tmp" "$HOME/.ssh/config"
        fi
        echo "  ssh hosts generated (buildhost/board)"
    else
        rm -f "$SSH_FRAGMENT"
    fi
}

teardown_identity() {
    if [[ -f "$GIT_BACKUP_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$GIT_BACKUP_FILE"
        if [[ -n "${GIT_EMAIL_BAK:-}" ]]; then
            git config --global user.email "$GIT_EMAIL_BAK"
        else
            git config --global --unset user.email 2>/dev/null || true
        fi
        if [[ -n "${GIT_NAME_BAK:-}" ]]; then
            git config --global user.name "$GIT_NAME_BAK"
        else
            git config --global --unset user.name 2>/dev/null || true
        fi
        rm -f "$GIT_BACKUP_FILE"
        echo "  git identity restored"
    fi

    if [[ -f "$SSH_FRAGMENT" ]]; then
        rm -f "$SSH_FRAGMENT"
        echo "  ssh generated hosts removed"
    fi

    if [[ -f "$HOME/.ssh/config" ]] && grep -Fqx "$SSH_INCLUDE_LINE" "$HOME/.ssh/config"; then
        grep -Fvx "$SSH_INCLUDE_LINE" "$HOME/.ssh/config" > "$HOME/.ssh/config.tmp"
        mv "$HOME/.ssh/config.tmp" "$HOME/.ssh/config"
        echo "  ssh Include line removed"
    fi
}

case "${1:-}" in
    install)
        if grep -Fqx "$SOURCE_LINE" "$BASHRC" 2>/dev/null; then
            echo "bashrc hook: already installed"
        else
            echo "$SOURCE_LINE" >> "$BASHRC"
            echo "bashrc hook: installed"
        fi

        mkdir -p "$HOME/.local/bin"

        link_config "vimrc" "$HOME/.vimrc"
        link_config "starship.toml" "$HOME/.config/starship.toml"

        echo "Installing tools (detected architecture: $UNAME_ARCH)..."
        install_font
        install_binary eza eza-community/eza "$(rust_pattern gnu)"
        install_binary bat sharkdp/bat "$(rust_pattern gnu)"
        install_binary delta dandavison/delta "$(rust_pattern gnu)"
        install_binary btop aristocratos/btop "$(rust_pattern musl)"
        install_binary starship starship/starship "$(rust_pattern gnu)"
        install_binary rg BurntSushi/ripgrep "$(rust_pattern musl)"
        install_binary fd sharkdp/fd "$(rust_pattern gnu)"
        install_binary zoxide ajeetdsouza/zoxide "$(rust_pattern musl)"
        case "$UNAME_ARCH" in
            x86_64) install_binary lazygit jesseduffield/lazygit 'linux_x86_64\.tar\.gz' ;;
            aarch64|arm64) install_binary lazygit jesseduffield/lazygit 'linux_arm64\.tar\.gz' ;;
            *) echo "  lazygit: skipped (no build for architecture $UNAME_ARCH)" ;;
        esac
        [[ -n "$ARCH_RUST" ]] && install_binary zellij zellij-org/zellij "/zellij-${ARCH_RUST}-unknown-linux-musl\\.tar\\.gz"
        install_jq
        install_fzf

        setup_identity

        echo "Done. Run: source ~/.bashrc"
        ;;

    uninstall)
        if [[ -f "$BASHRC" ]]; then
            grep -Fvx "$SOURCE_LINE" "$BASHRC" > "$BASHRC.tmp"
            mv "$BASHRC.tmp" "$BASHRC"
        fi

        unlink_config "$HOME/.vimrc"
        unlink_config "$HOME/.config/starship.toml"

        for bin in eza bat delta btop starship rg fd zoxide lazygit zellij fzf jq; do
            rm -f "$HOME/.local/bin/$bin"
        done
        rm -rf "$HOME/.local/share/fzf"
        rm -rf "$HOME/.config/zellij" "$HOME/.cache/zellij" "$HOME/.local/share/zellij"
        rm -f "$HOME"/.local/share/fonts/JetBrainsMono*NerdFont*.ttf
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true

        teardown_identity

        echo "Uninstalled."
        echo "Open a new shell."
        ;;

    *)
        echo "Usage:"
        echo "  setup.sh install"
        echo "  setup.sh uninstall"
        exit 1
        ;;
esac
