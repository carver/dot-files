# Aliases and small functions, sourced by .bashrc (linked from the dot-files repo).

# `.. 3` goes up three directories in a single cd, so `cd -` comes straight back.
function .. {
  local path=. i
  for ((i = 0; i < ${1:-1}; i++)); do
    path+=/..
  done
  cd "$path" || return
}

function mcd() {
  mkdir -p "$1" && cd "$1";
}

alias n='nvim'
alias vi='nvim'
alias vim='nvim'

alias serve='ip addr | grep inet; python3 -m http.server'

# 30 most-used commands from history
alias freq='cut -f1 -d" " ~/.bash_history | sort | uniq -c | sort -nr | head -n 30'

# color support of ls and grep
if [ -x /usr/bin/dircolors ]; then
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
# Normal urgency: GNOME shows a banner for it, where low urgency can land straight in the tray.
alias alert='notify-send --urgency=normal -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias gl='git log --oneline --decorate --graph --all'
alias gsh='git show'
