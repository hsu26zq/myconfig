# set alert
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
. "$HOME/.cargo/env"

# prompt
FMT_BOLD="\e[1m"
FMT_RESET="\e[0m"
FMT_UNBOLD="\e[21m"
FG_BLACK="\e[30m"
FG_BLUE="\e[34m"
FG_CYAN="\e[36m"
FG_GREEN="\e[32m"
FG_MAGENTA="\e[35m"
FG_RED="\e[31m"
FG_WHITE="\e[97m"
BG_BLUE="\e[44m"
BG_GREEN="\e[42m"
BG_MAGENTA="\e[45m"
BG_BLACK="\e[40m"

export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWCOLORHINTS=1

git_branch_segment() {
    local branch
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || return

    printf '\e[34m\e[45m \e[1m\e[30m %s \e[35m\e[40m\e[0m' "$branch"
}

export PS1=\
"\n\[${FMT_BOLD}${BG_GREEN}\] \[${FG_RED}\] \[${FG_BLACK}\]\u "\
"\[${FG_GREEN}${BG_BLUE}\] "\
"\[${FG_WHITE}\]\w "\
"\[${FMT_RESET}\]"\
"\$(git_branch_segment || printf '\[%s%s\]\[%s\]' \"$FG_BLUE\" \"$BG_BLACK\" \"$FMT_RESET\")"\
"\n \[${FG_GREEN}\]╰ \[${FG_CYAN}\]\$ \[${FMT_RESET}\]"
