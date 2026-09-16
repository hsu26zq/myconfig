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

install_zellij() {
    if command -v zellij >/dev/null 2>&1; then
        echo "zellij already installed."
        return
    fi

    echo "Installing zellij..."
    local url
    url=$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*/zellij-x86_64-unknown-linux-musl\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo /tmp/zellij.tar.gz "$url" \
            && tar -xzf /tmp/zellij.tar.gz -C "$HOME/.local/bin" zellij \
            && chmod +x "$HOME/.local/bin/zellij" \
            && echo "Installed zellij."
        rm -f /tmp/zellij.tar.gz
    else
        echo "Could not find a zellij release asset."
    fi
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
    if command -v eza >/dev/null 2>&1; then
        echo "eza already installed."
        return
    fi

    echo "Installing eza..."
    local eza_url
    eza_url=$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*x86_64-unknown-linux-gnu\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$eza_url" ]]; then
        curl -fLo /tmp/eza.tar.gz "$eza_url" \
            && tar -xzf /tmp/eza.tar.gz -C "$HOME/.local/bin" ./eza \
            && chmod +x "$HOME/.local/bin/eza" \
            && echo "Installed eza."
        rm -f /tmp/eza.tar.gz
    else
        echo "Could not find an eza release asset."
    fi
}

uninstall_eza() {
    rm -f "$HOME/.local/bin/eza"
    echo "Removed eza."
}

install_bat() {
    if command -v bat >/dev/null 2>&1; then
        echo "bat already installed."
        return
    fi

    echo "Installing bat..."
    local bat_url bat_dir
    bat_url=$(curl -fsSL https://api.github.com/repos/sharkdp/bat/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*x86_64-unknown-linux-gnu\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$bat_url" ]]; then
        curl -fLo /tmp/bat.tar.gz "$bat_url"
        bat_dir=$(tar -tzf /tmp/bat.tar.gz | head -1 | cut -d/ -f1)
        tar -xzf /tmp/bat.tar.gz -C /tmp "$bat_dir/bat" \
            && cp "/tmp/$bat_dir/bat" "$HOME/.local/bin/bat" \
            && chmod +x "$HOME/.local/bin/bat" \
            && echo "Installed bat."
        rm -rf /tmp/bat.tar.gz "/tmp/$bat_dir"
    else
        echo "Could not find a bat release asset."
    fi
}

uninstall_bat() {
    rm -f "$HOME/.local/bin/bat"
    echo "Removed bat."
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

# Cosmetic: font + colorized ls/cat replacements. No new capability, just
# nicer-looking output.
install_looks() {
    mkdir -p "$HOME/.local/bin"
    install_font
    install_eza
    install_bat
}

uninstall_looks() {
    uninstall_font
    uninstall_eza
    uninstall_bat
}

# Functional: actually changes what you can do, not just how it looks.
install_tools() {
    install_fzf
}

uninstall_tools() {
    uninstall_fzf
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
