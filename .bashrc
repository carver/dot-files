# ~/.bashrc, linked from the dot-files repo by install.sh.
# Machine-specific additions go in one of two files, neither of them in the repo:
#   ~/.bashrc.noninteractive.local  sourced below, before the interactive-only guard,
#                                   so it applies to `ssh host cmd`, scripts, etc. too.
#                                   The safe default: when in doubt, put it here.
#   ~/.bashrc.local                 sourced at the very end, interactive shells only.
#                                   For anything slow enough that a script shouldn't pay for it.

# --- Cheap, always-useful environment (also for non-interactive shells, e.g. `ssh host cmd`)
if command -v nvim >/dev/null 2>&1; then
  # TODO: use the result of command -v to set the full path to nvim below:
    export SUDO_EDITOR=nvim EDITOR=nvim VISUAL=nvim
fi

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# _path_add front|back DIR -- add DIR to PATH at most once. A login shell reaches
# this file through ~/.profile while an interactive one reads it directly, so it
# can end up sourced twice in one shell; without the check PATH would stack
# duplicates every time.
_path_add() {
    case ":$PATH:" in *":$2:"*) return 0;; esac
    if [ "$1" = front ]; then PATH="$2:$PATH"; else PATH="$PATH:$2"; fi
}
_path_add front "$HOME/.local/bin"
[ -d "$HOME/bin" ] && _path_add front "$HOME/bin"
# golang: the toolchain, then binaries from `go install` (GOPATH defaults to ~/go)
[ -d /usr/local/go/bin ] && _path_add back /usr/local/go/bin
_path_add back "${GOPATH:-$HOME/go}/bin"
unset -f _path_add
export PATH

# Don't let docker sbx cache the files locally, because I want to be able to edit them on the
# host, and have the changes immediately visible. This has already bitten me once.
export DOCKER_SANDBOXES_ENABLE_VIRTIOFS_CACHE=0

# --- Machine-specific settings that every shell needs, interactive or not.
# Sourced before the guard below, so non-interactive shells (`ssh host cmd`, scripts,
# anything run by an editor or an agent) still get it.
if [ -f ~/.bashrc.noninteractive.local ]; then
    . ~/.bashrc.noninteractive.local
fi

# --- Everything below is for interactive shells only
case $- in
    *i*) ;;
      *) return;;
esac

# History: no duplicates or space-prefixed lines, append rather than overwrite, keep lots.
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000

# Re-check the window size after each command
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Prompt: colored when the terminal supports it
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac
if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac

# ls colors (the aliases that use them live in .bash_aliases)
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# --- Toolchains that are slow to initialize or only make sense interactively
if command -v rustc >/dev/null 2>&1; then
    export RUSTFLAGS="-D warnings"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# conda (miniforge), if installed on this machine. Equivalent to the block `conda init` writes.
if [ -x "$HOME/miniforge3/bin/conda" ]; then
    __conda_setup="$("$HOME/miniforge3/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    elif [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/miniforge3/bin:$PATH"
    fi
    unset __conda_setup
fi

# --- Machine-specific settings for interactive shells only
if [ -f ~/.bashrc.local ]; then
    . ~/.bashrc.local
fi
