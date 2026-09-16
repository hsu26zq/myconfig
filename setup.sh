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

install_delta() {
    if command -v delta >/dev/null 2>&1; then
        echo "delta already installed."
        return
    fi

    echo "Installing delta..."
    local url dir
    url=$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*x86_64-unknown-linux-gnu\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo /tmp/delta.tar.gz "$url"
        dir=$(tar -tzf /tmp/delta.tar.gz | grep -E "/delta$" | head -1)
        tar -xzf /tmp/delta.tar.gz -C /tmp "$dir" \
            && cp "/tmp/$dir" "$HOME/.local/bin/delta" \
            && chmod +x "$HOME/.local/bin/delta" \
            && echo "Installed delta."
        rm -rf /tmp/delta.tar.gz "/tmp/$(dirname "$dir")"
    else
        echo "Could not find a delta release asset."
    fi
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
    if command -v starship >/dev/null 2>&1; then
        echo "starship already installed."
        return
    fi

    echo "Installing starship..."
    local url
    url=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*x86_64-unknown-linux-gnu\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo /tmp/starship.tar.gz "$url" \
            && tar -xzf /tmp/starship.tar.gz -C "$HOME/.local/bin" starship \
            && chmod +x "$HOME/.local/bin/starship" \
            && echo "Installed starship."
        rm -f /tmp/starship.tar.gz
    else
        echo "Could not find a starship release asset."
    fi
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
    if command -v rg >/dev/null 2>&1; then
        echo "ripgrep already installed."
        return
    fi

    echo "Installing ripgrep..."
    local url dir
    url=$(curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*x86_64-unknown-linux-musl\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo /tmp/rg.tar.gz "$url"
        dir=$(tar -tzf /tmp/rg.tar.gz | grep -E "/rg$" | head -1)
        tar -xzf /tmp/rg.tar.gz -C /tmp "$dir" \
            && cp "/tmp/$dir" "$HOME/.local/bin/rg" \
            && chmod +x "$HOME/.local/bin/rg" \
            && echo "Installed ripgrep."
        rm -rf /tmp/rg.tar.gz "/tmp/$(dirname "$dir")"
    else
        echo "Could not find a ripgrep release asset."
    fi
}

uninstall_ripgrep() {
    rm -f "$HOME/.local/bin/rg"
    echo "Removed ripgrep."
}

install_fd() {
    if command -v fd >/dev/null 2>&1; then
        echo "fd already installed."
        return
    fi

    echo "Installing fd..."
    local url dir
    url=$(curl -fsSL https://api.github.com/repos/sharkdp/fd/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*x86_64-unknown-linux-gnu\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo /tmp/fd.tar.gz "$url"
        dir=$(tar -tzf /tmp/fd.tar.gz | grep -E "/fd$" | head -1)
        tar -xzf /tmp/fd.tar.gz -C /tmp "$dir" \
            && cp "/tmp/$dir" "$HOME/.local/bin/fd" \
            && chmod +x "$HOME/.local/bin/fd" \
            && echo "Installed fd."
        rm -rf /tmp/fd.tar.gz "/tmp/$(dirname "$dir")"
    else
        echo "Could not find an fd release asset."
    fi
}

uninstall_fd() {
    rm -f "$HOME/.local/bin/fd"
    echo "Removed fd."
}

install_zoxide() {
    if command -v zoxide >/dev/null 2>&1; then
        echo "zoxide already installed."
        return
    fi

    echo "Installing zoxide..."
    local url
    url=$(curl -fsSL https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*x86_64-unknown-linux-musl\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo /tmp/zoxide.tar.gz "$url" \
            && tar -xzf /tmp/zoxide.tar.gz -C "$HOME/.local/bin" zoxide \
            && chmod +x "$HOME/.local/bin/zoxide" \
            && echo "Installed zoxide."
        rm -f /tmp/zoxide.tar.gz
    else
        echo "Could not find a zoxide release asset."
    fi
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
    if command -v lazygit >/dev/null 2>&1; then
        echo "lazygit already installed."
        return
    fi

    echo "Installing lazygit..."
    local url
    url=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*linux_x86_64\.tar\.gz"' \
        | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        curl -fLo /tmp/lazygit.tar.gz "$url" \
            && tar -xzf /tmp/lazygit.tar.gz -C "$HOME/.local/bin" lazygit \
            && chmod +x "$HOME/.local/bin/lazygit" \
            && echo "Installed lazygit."
        rm -f /tmp/lazygit.tar.gz
    else
        echo "Could not find a lazygit release asset."
    fi
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
