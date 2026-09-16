__utils_git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null) || return
    [[ -n "$branch" ]] && printf ' (%s)' "$branch"
}

PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[33m\]$(__utils_git_branch)\[\e[0m\]\$ '

HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoredups:erasedups

shopt -s histappend
shopt -s checkwinsize
