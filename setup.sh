#!/bin/bash

UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHRC="$HOME/.bashrc"
SOURCE_LINE="source \"$UTILS_DIR/setup.sh\""

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export PATH="$UTILS_DIR:$PATH"

    if [[ -f "$UTILS_DIR/profile" ]]; then
        source "$UTILS_DIR/profile"
    fi

    _utils_reload_aliases() {
        if [[ -n "${_UTILS_ALIAS_NAMES:-}" ]]; then
            for name in $_UTILS_ALIAS_NAMES; do
                unalias "$name" 2>/dev/null
            done
        fi

        _UTILS_ALIAS_NAMES=""

        if [[ -f "$UTILS_DIR/alias" ]]; then
            _UTILS_ALIAS_NAMES=$(
                sed -n "s/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p" \
                    "$UTILS_DIR/alias"
            )

            source "$UTILS_DIR/alias"
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

LINKS=(
    "vimrc:$HOME/.vimrc"
    "tmux.conf:$HOME/.tmux.conf"
    "gitconfig:$HOME/.gitconfig"
    "ssh_config:$HOME/.ssh/config"
)

link_config() {
    local target="$UTILS_DIR/$1" link_path="$2"

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

case "${1:-}" in
    install)
        if grep -Fqx "$SOURCE_LINE" "$BASHRC" 2>/dev/null; then
            echo "Already installed."
        else
            echo "$SOURCE_LINE" >> "$BASHRC"
            echo "Installed bashrc hook."
        fi

        for entry in "${LINKS[@]}"; do
            link_config "${entry%%:*}" "${entry#*:}"
        done

        echo "Run: source ~/.bashrc"
        ;;

    uninstall)
        if [[ -f "$BASHRC" ]]; then
            grep -Fvx "$SOURCE_LINE" "$BASHRC" > "$BASHRC.tmp"
            mv "$BASHRC.tmp" "$BASHRC"
        fi

        for entry in "${LINKS[@]}"; do
            unlink_config "${entry#*:}"
        done

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
