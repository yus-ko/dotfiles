#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

./setup.sh -y

if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
fi

for command_name in zsh git curl tmux fzf unzip batcat; do
  command -v "$command_name" >/dev/null
done

locale -a | grep -qi '^ja_JP\.utf8$'
test "$(readlink -f /etc/localtime)" = "/usr/share/zoneinfo/Asia/Tokyo"

test -L "$HOME/.zshrc"
test -L "$HOME/.p10k.zsh"
test -L "$HOME/.bashrc"
test -L "$HOME/.config/tmux/tmux.conf.local"
test -L "$HOME/.config/zsh-abbr/user-abbreviations"

printf 'Ubuntu %s: setup test passed\n' "$(. /etc/os-release && printf '%s' "$VERSION_ID")"
