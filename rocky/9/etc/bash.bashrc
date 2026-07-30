# System-wide .bashrc additions for interactive bash shells.

[ -z "$PS1" ] && return

shopt -s checkwinsize

PS1='\u@\h:\w\$ '

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -f /etc/bash_alias ]; then . /etc/bash_alias; fi
for f in /etc/bashrc.d/*; do test -f "$f" && . "$f"; done
