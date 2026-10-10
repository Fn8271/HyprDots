export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export HISTFILE="$XDG_STATE_HOME/zsh/history"

export GOPATH="$XDG_DATA_HOME/go"

export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/git/config"

export EDITOR="nvim"
export VISUAL="nvim"
export TERMINAL="kitty"
export BROWSER="firefox"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$GOPATH/bin:$PATH"

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

export PAGER="less"
export LESS="-R"
export MANPAGER="less"
export LESSHISTFILE="$XDG_CACHE_HOME/less/history"
