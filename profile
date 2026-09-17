if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    __utils_git_branch() {
        local branch
        branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || return
        printf ' (%s)' "$branch"
    }
    PS1='\u@\h:\w$(__utils_git_branch)\$ '
fi

HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoredups:erasedups

shopt -s histappend
shopt -s checkwinsize
