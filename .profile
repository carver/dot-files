# ~/.profile, linked from the dot-files repo by install.sh.
#
# Login shells only, and bash reads it only when neither ~/.bash_profile nor
# ~/.bash_login exists. Its whole job is to pull in ~/.bashrc: bash reads that
# file for interactive *non-login* shells, so without this an `ssh host`, a
# console login or a desktop session would get none of it.
#
# POSIX sh, not bash: /bin/sh login shells read this too.
#
# Machine-specific additions go in ~/.profile.local, sourced at the end. Prefer
# ~/.bashrc.noninteractive.local unless the setting really is login-only --
# that one reaches every shell, this file only reaches login shells.

if [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi
