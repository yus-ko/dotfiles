#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== dotfiles セットアップ ==="

# --- Oh My Zsh ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "[1/5] Oh My Zsh をインストール中..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "[1/5] Oh My Zsh は既にインストール済み"
fi

# --- Powerlevel10k テーマ ---
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  echo "[2/5] Powerlevel10k をインストール中..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  echo "[2/5] Powerlevel10k は既にインストール済み"
fi

# --- zsh プラグイン ---
echo "[3/5] zsh プラグインをインストール中..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

declare -A plugins=(
  ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
  ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
  ["zsh-abbr"]="https://github.com/olets/zsh-abbr.git"
)

for plugin in "${!plugins[@]}"; do
  plugin_dir="$ZSH_CUSTOM/plugins/$plugin"
  if [ ! -d "$plugin_dir" ]; then
    echo "  - $plugin をインストール中..."
    git clone --depth=1 "${plugins[$plugin]}" "$plugin_dir"
  else
    echo "  - $plugin は既にインストール済み"
  fi
done

# --- シンボリックリンク作成 ---
echo "[4/5] シンボリックリンクを作成中..."

link_file() {
  local src="$1"
  local dest="$2"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
    echo "  - 既存の $(basename "$dest") をバックアップ: $backup"
    mv "$dest" "$backup"
  fi
  ln -s "$src" "$dest"
  echo "  - $(basename "$dest") -> $src"
}

link_file "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
link_file "$SCRIPT_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
link_file "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
link_file "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
link_file "$SCRIPT_DIR/nvim" "$HOME/.config/nvim"

# --- zsh-abbr 略語設定 ---
echo "[5/5] zsh-abbr の略語設定を配置中..."
mkdir -p "$HOME/.config/zsh-abbr"
link_file "$SCRIPT_DIR/zsh-abbr/user-abbreviations" "$HOME/.config/zsh-abbr/user-abbreviations"

echo ""
echo "=== セットアップ完了 ==="
echo "新しいシェルを起動するか、'source ~/.zshrc' を実行してください。"
