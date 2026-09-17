#!/bin/bash

UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$UTILS_DIR/common"
WORK_DIR="$UTILS_DIR/work"
WORK_MARKER="$UTILS_DIR/.work_enabled"
LOOKS_MARKER="$UTILS_DIR/.looks_enabled"
BASHRC="$HOME/.bashrc"
SOURCE_LINE="source \"$UTILS_DIR/setup.sh\""

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export PATH="$COMMON_DIR:$PATH"
    [[ -f "$WORK_MARKER" ]] && export PATH="$WORK_DIR:$PATH"
    [[ -d "$HOME/.fzf/bin" ]] && export PATH="$HOME/.fzf/bin:$PATH"
    [[ -f "$HOME/.fzf.bash" ]] && source "$HOME/.fzf.bash"
    command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

    if [[ -f "$COMMON_DIR/profile" ]]; then
        source "$COMMON_DIR/profile"
    fi

    if [[ -f "$LOOKS_MARKER" && -f "$COMMON_DIR/profile.looks" ]]; then
        source "$COMMON_DIR/profile.looks"
    fi

    _utils_reload_aliases() {
        if [[ -n "${_UTILS_ALIAS_NAMES:-}" ]]; then
            for name in $_UTILS_ALIAS_NAMES; do
                unalias "$name" 2>/dev/null
            done
        fi

        _UTILS_ALIAS_NAMES=""

        if [[ -f "$COMMON_DIR/alias" ]]; then
            _UTILS_ALIAS_NAMES=$(
                sed -n "s/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p" \
                    "$COMMON_DIR/alias"
            )

            source "$COMMON_DIR/alias"
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

COMMON_LINKS=(
    "common/vimrc:$HOME/.vimrc"
)

WORK_LINKS=(
    "work/gitconfig:$HOME/.gitconfig"
    "work/ssh_config:$HOME/.ssh/config"
)

LOOKS_LINKS=(
    "common/starship.toml:$HOME/.config/starship.toml"
)

link_config() {
    local target="$1" link_path="$2"
    [[ "$target" != /* ]] && target="$UTILS_DIR/$target"

    mkdir -p "$(dirname "$link_path")"

    if [[ -L "$link_path" ]]; then
        ln -sfn "$target" "$link_path"
        echo "Linked $link_path -> $target"
        return
    fi

    if [[ -e "$link_path" ]]; then
        mv "$link_path" "$link_path.bak"
        echo "Backed up $link_path -> $link_path.bak"
    fi

    ln -sfn "$target" "$link_path"
    echo "Linked $link_path -> $target"
}

unlink_config() {
    local link_path="$1"

    if [[ -L "$link_path" ]]; then
        rm "$link_path"
        if [[ -e "$link_path.bak" ]]; then
            mv "$link_path.bak" "$link_path"
            echo "Restored $link_path from backup"
        else
            echo "Removed $link_path"
        fi
    fi
}

# Shared by tools whose release tarball contains the binary somewhere
# inside it, named exactly like the command - whether at the archive
# root (bare "cmd" or "./cmd") or nested in a versioned directory
# ("pkg-1.2.3/cmd"). Finds the actual entry rather than assuming its
# path, since projects are inconsistent about this.
install_binary() {
    local cmd="$1" repo="$2" asset_pattern="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd already installed."
        return
    fi

    echo "Installing $cmd..."
    local url entry path
    url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -o "\"browser_download_url\": *\"[^\"]*${asset_pattern}\"" \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo "/tmp/$cmd.tar.gz" "$url"
        # Archive entry may be "cmd", "./cmd", or "pkg-1.2.3/cmd" depending
        # on the project. Extract using the raw entry (tar needs an exact
        # match), but strip any "./" prefix before using it as a local
        # path, so cleanup targets the real file/directory, not "/tmp/.".
        entry=$(tar -tzf "/tmp/$cmd.tar.gz" | grep -E "(^|/)$cmd\$" | head -1)
        path="${entry#./}"
        tar -xzf "/tmp/$cmd.tar.gz" -C /tmp "$entry" \
            && cp "/tmp/$path" "$HOME/.local/bin/$cmd" \
            && chmod +x "$HOME/.local/bin/$cmd" \
            && echo "Installed $cmd."
        rm -rf "/tmp/$cmd.tar.gz" "/tmp/${path%%/*}"
    else
        echo "Could not find a $cmd release asset."
    fi
}

install_zellij() {
    install_binary zellij zellij-org/zellij '/zellij-x86_64-unknown-linux-musl\.tar\.gz'
}

uninstall_zellij() {
    rm -f "$HOME/.local/bin/zellij"
    rm -rf "$HOME/.config/zellij" "$HOME/.cache/zellij" "$HOME/.local/share/zellij"
    echo "Removed zellij."
}

install_font() {
    local name="JetBrainsMono Nerd Font"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    local dest="$HOME/.local/share/fonts"
    local tmp_zip="/tmp/jetbrainsmono-nerd-font.zip"

    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        echo "$name already installed."
        return
    fi

    mkdir -p "$dest"
    echo "Downloading $name..."
    curl -fLo "$tmp_zip" "$url" || { echo "Download failed."; return 1; }
    unzip -oq "$tmp_zip" -d "$dest"
    rm -f "$tmp_zip"
    fc-cache -f "$dest" >/dev/null
    echo "Installed $name to $dest"
    echo "Set it as your terminal emulator's font to see icons/powerline glyphs."
}

uninstall_font() {
    rm -f "$HOME"/.local/share/fonts/JetBrainsMono*NerdFont*.ttf
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
    echo "Removed JetBrainsMono Nerd Font."
}

install_eza() {
    install_binary eza eza-community/eza 'x86_64-unknown-linux-gnu\.tar\.gz'
}

uninstall_eza() {
    rm -f "$HOME/.local/bin/eza"
    echo "Removed eza."
}

install_bat() {
    install_binary bat sharkdp/bat 'x86_64-unknown-linux-gnu\.tar\.gz'
}

uninstall_bat() {
    rm -f "$HOME/.local/bin/bat"
    echo "Removed bat."
}

install_delta() {
    install_binary delta dandavison/delta 'x86_64-unknown-linux-gnu\.tar\.gz'
}

uninstall_delta() {
    rm -f "$HOME/.local/bin/delta"
    echo "Removed delta."
}

install_btop() {
    if command -v btop >/dev/null 2>&1; then
        echo "btop already installed."
        return
    fi

    echo "Installing btop..."
    local url
    url=$(curl -fsSL https://api.github.com/repos/aristocratos/btop/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*x86_64-unknown-linux-musl\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo /tmp/btop.tar.gz "$url" \
            && tar -xzf /tmp/btop.tar.gz -C /tmp ./btop/bin/btop \
            && cp /tmp/btop/bin/btop "$HOME/.local/bin/btop" \
            && chmod +x "$HOME/.local/bin/btop" \
            && echo "Installed btop."
        rm -rf /tmp/btop.tar.gz /tmp/btop
    else
        echo "Could not find a btop release asset."
    fi
}

uninstall_btop() {
    rm -f "$HOME/.local/bin/btop"
    echo "Removed btop."
}

install_starship() {
    install_binary starship starship/starship 'x86_64-unknown-linux-gnu\.tar\.gz'
}

uninstall_starship() {
    rm -f "$HOME/.local/bin/starship"
    rm -f "$HOME/.config/starship.toml"
    echo "Removed starship."
}

install_fzf() {
    if [[ -d "$HOME/.fzf" ]]; then
        echo "fzf already installed."
        return
    fi

    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" \
        && "$HOME/.fzf/install" --key-bindings --completion --no-update-rc \
        && echo "Installed fzf."
}

uninstall_fzf() {
    rm -rf "$HOME/.fzf" "$HOME/.fzf.bash"
    echo "Removed fzf."
}

install_ripgrep() {
    install_binary rg BurntSushi/ripgrep 'x86_64-unknown-linux-musl\.tar\.gz'
}

uninstall_ripgrep() {
    rm -f "$HOME/.local/bin/rg"
    echo "Removed ripgrep."
}

install_fd() {
    install_binary fd sharkdp/fd 'x86_64-unknown-linux-gnu\.tar\.gz'
}

uninstall_fd() {
    rm -f "$HOME/.local/bin/fd"
    echo "Removed fd."
}

install_zoxide() {
    install_binary zoxide ajeetdsouza/zoxide 'x86_64-unknown-linux-musl\.tar\.gz'
}

uninstall_zoxide() {
    rm -f "$HOME/.local/bin/zoxide"
    rm -rf "$HOME/.local/share/zoxide" "$HOME/.cache/zoxide"
    echo "Removed zoxide."
}

install_jq() {
    if command -v jq >/dev/null 2>&1; then
        echo "jq already installed."
        return
    fi

    echo "Installing jq..."
    local url
    url=$(curl -fsSL https://api.github.com/repos/jqlang/jq/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*jq-linux-amd64"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo "$HOME/.local/bin/jq" "$url" \
            && chmod +x "$HOME/.local/bin/jq" \
            && echo "Installed jq."
    else
        echo "Could not find a jq release asset."
    fi
}

uninstall_jq() {
    rm -f "$HOME/.local/bin/jq"
    echo "Removed jq."
}

install_lazygit() {
    install_binary lazygit jesseduffield/lazygit 'linux_x86_64\.tar\.gz'
}

uninstall_lazygit() {
    rm -f "$HOME/.local/bin/lazygit"
    echo "Removed lazygit."
}

# Cosmetic: font + colorized ls/cat/diff/top replacements, and the fancy
# prompt (starship). No new capability, just nicer-looking output.
install_looks() {
    mkdir -p "$HOME/.local/bin"
    install_font
    install_eza
    install_bat
    install_delta
    install_btop
    install_starship
}

uninstall_looks() {
    uninstall_font
    uninstall_eza
    uninstall_bat
    uninstall_delta
    uninstall_btop
    uninstall_starship
}

# Functional: actually changes what you can do, not just how it looks.
install_tools() {
    install_fzf
    install_ripgrep
    install_fd
    install_zoxide
    install_jq
    install_lazygit
}

uninstall_tools() {
    uninstall_fzf
    uninstall_ripgrep
    uninstall_fd
    uninstall_zoxide
    uninstall_jq
    uninstall_lazygit
}

case "${1:-}" in
    install)
        if grep -Fqx "$SOURCE_LINE" "$BASHRC" 2>/dev/null; then
            echo "Already installed."
        else
            echo "$SOURCE_LINE" >> "$BASHRC"
            echo "Installed bashrc hook."
        fi

        mkdir -p "$HOME/.local/bin"
        install_zellij

        for entry in "${COMMON_LINKS[@]}"; do
            link_config "${entry%%:*}" "${entry#*:}"
        done

        for scope in "${@:2}"; do
            case "$scope" in
                work)
                    for entry in "${WORK_LINKS[@]}"; do
                        link_config "${entry%%:*}" "${entry#*:}"
                    done
                    touch "$WORK_MARKER"
                    echo "Work scope enabled."
                    ;;
                looks)
                    install_looks
                    for entry in "${LOOKS_LINKS[@]}"; do
                        link_config "${entry%%:*}" "${entry#*:}"
                    done
                    touch "$LOOKS_MARKER"
                    echo "Looks scope enabled (fancy prompt active)."
                    ;;
                tools)
                    install_tools
                    ;;
            esac
        done

        echo "Run: source ~/.bashrc"
        ;;

    uninstall)
        # Full teardown, always - no scope flags. Anything ever installed by
        # this repo (symlinks, downloaded binaries, cloned repos) is removed
        # so install-then-uninstall leaves nothing behind.

        if [[ -f "$BASHRC" ]]; then
            grep -Fvx "$SOURCE_LINE" "$BASHRC" > "$BASHRC.tmp"
            mv "$BASHRC.tmp" "$BASHRC"
        fi

        for entry in "${COMMON_LINKS[@]}"; do
            unlink_config "${entry#*:}"
        done

        for entry in "${WORK_LINKS[@]}"; do
            unlink_config "${entry#*:}"
        done

        for entry in "${LOOKS_LINKS[@]}"; do
            unlink_config "${entry#*:}"
        done

        uninstall_zellij
        uninstall_looks
        uninstall_tools

        rm -f "$WORK_MARKER" "$LOOKS_MARKER"

        echo "Uninstalled."
        echo "Open a new shell."
        ;;

    *)
        echo "Usage:"
        echo "  setup.sh install [work] [looks] [tools]"
        echo "  setup.sh uninstall"
        exit 1
        ;;
esac
