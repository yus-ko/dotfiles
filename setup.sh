#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== dotfiles セットアップ ==="

# --- 必要パッケージのインストール ---
echo "[0/7] 必要パッケージをインストール中..."
PACKAGES=(zsh git curl tmux fzf)

if command -v apt-get &>/dev/null; then
  # Debian / Ubuntu
  MISSING=()
  for pkg in "${PACKAGES[@]}"; do
    dpkg -s "$pkg" &>/dev/null || MISSING+=("$pkg")
  done
  if [ ${#MISSING[@]} -gt 0 ]; then
    echo "  - apt で不足パッケージをインストール: ${MISSING[*]}"
    APT="apt-get"
    [ "$(id -u)" -ne 0 ] && APT="sudo -E apt-get"
    $APT update -qq
    $APT install -y -qq "${MISSING[@]}"
  else
    echo "  - 必要パッケージはすべてインストール済み"
  fi
elif command -v brew &>/dev/null; then
  # macOS (Homebrew)
  for pkg in "${PACKAGES[@]}"; do
    brew list "$pkg" &>/dev/null || brew install "$pkg"
  done
else
  echo "  - WARNING: apt-get / brew が見つかりません。パッケージを手動でインストールしてください: ${PACKAGES[*]}"
fi

# --- Oh My Zsh ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "[1/7] Oh My Zsh をインストール中..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "[1/7] Oh My Zsh は既にインストール済み"
fi

# --- Powerlevel10k テーマ ---
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  echo "[2/7] Powerlevel10k をインストール中..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  echo "[2/7] Powerlevel10k は既にインストール済み"
fi

# --- zsh プラグイン ---
echo "[3/7] zsh プラグインをインストール中..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

declare -A plugins=(
  ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
  ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
  ["fzf-tab"]="https://github.com/Aloxaf/fzf-tab.git"
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

# zsh-abbr: サブモジュール (zsh-job-queue) を含めてクローン
ABBR_DIR="$ZSH_CUSTOM/plugins/zsh-abbr"
if [ ! -f "$ABBR_DIR/zsh-job-queue/zsh-job-queue.zsh" ]; then
  echo "  - zsh-abbr をインストール中..."
  rm -rf "$ABBR_DIR"
  git clone --depth=1 --recurse-submodules --shallow-submodules \
    https://github.com/olets/zsh-abbr.git "$ABBR_DIR"
else
  echo "  - zsh-abbr は既にインストール済み"
fi

# --- シンボリックリンク作成 ---
echo "[4/7] シンボリックリンクを作成中..."

BACKUP_DIR="$SCRIPT_DIR/tmp"
mkdir -p "$BACKUP_DIR"

link_file() {
  local src="$1"
  local dest="$2"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local backup="$BACKUP_DIR/$(basename "$dest").backup.$(date +%Y%m%d%H%M%S)"
    echo "  - 既存の $(basename "$dest") をバックアップ: $backup"
    mv "$dest" "$backup"
  fi
  ln -s "$src" "$dest"
  echo "  - $(basename "$dest") -> $src"
}

link_file "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
link_file "$SCRIPT_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
link_file "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
mkdir -p "$HOME/.config/tmux"
link_file "$SCRIPT_DIR/tmux.conf.local" "$HOME/.config/tmux/tmux.conf.local"

# --- Neovim 本体（GitHub Releases から最新版） ---
echo "[5/8] Neovim をインストール中..."
if ! command -v nvim &>/dev/null || ! nvim --version | grep -qE 'NVIM v(0\.[1-9][0-9]|[1-9])'; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  NVIM_ASSET="nvim-linux-x86_64.tar.gz" ;;
    aarch64) NVIM_ASSET="nvim-linux-arm64.tar.gz"  ;;
    *)        echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}"
  NVIM_TMP="$(mktemp -d)"
  echo "  - ${NVIM_URL} からダウンロード中..."
  curl -fsSL "$NVIM_URL" | tar xz -C "$NVIM_TMP"
  NVIM_DIR_NAME="${NVIM_ASSET%.tar.gz}"
  mkdir -p "$HOME/.local"
  rm -rf "$HOME/.local/${NVIM_DIR_NAME}"
  mv "$NVIM_TMP/${NVIM_DIR_NAME}" "$HOME/.local/${NVIM_DIR_NAME}"
  rm -rf "$NVIM_TMP"
  # PATH に通すシンボリックリンク
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.local/${NVIM_DIR_NAME}/bin/nvim" "$HOME/.local/bin/nvim"
  echo "  - nvim $("$HOME/.local/bin/nvim" --version | head -1) をインストールしました"
else
  echo "  - Neovim は既に要件を満たすバージョンがインストール済み: $(nvim --version | head -1)"
fi

# --- Neovim (LazyVim) ---
echo "[6/8] Neovim (LazyVim) をセットアップ中..."
NVIM_DIR="$HOME/.config/nvim"
if [ ! -d "$NVIM_DIR" ]; then
  echo "  - LazyVim starter をクローン中..."
  git clone https://github.com/LazyVim/starter "$NVIM_DIR"
  rm -rf "$NVIM_DIR/.git"
fi
echo "  - カスタマイズファイルを配置中..."
cp "$SCRIPT_DIR/nvim/lua/config/lazy.lua" "$NVIM_DIR/lua/config/lazy.lua"

# --- zsh-abbr 略語設定 ---
echo "[7/8] zsh-abbr の略語設定を配置中..."

mkdir -p "$HOME/.config/zsh-abbr"
link_file "$SCRIPT_DIR/zsh-abbr/user-abbreviations" "$HOME/.config/zsh-abbr/user-abbreviations"

# --- imgcat ---
echo "[8/8] imgcat をインストール中..."
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/bin/imgcat" "$HOME/.local/bin/imgcat"
chmod +x "$HOME/.local/bin/imgcat"
echo "  - imgcat -> $HOME/.local/bin/imgcat"
cp "$SCRIPT_DIR/bin/tmux-sync-bg" "$HOME/.local/bin/tmux-sync-bg"
chmod +x "$HOME/.local/bin/tmux-sync-bg"
echo "  - tmux-sync-bg -> $HOME/.local/bin/tmux-sync-bg"

# --- uv ---
echo "[+] uv をインストール中..."
if command -v uv &>/dev/null; then
  echo "  - uv は既にインストール済み: $(uv --version)"
else
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo "  - uv をインストールしました"
fi

# --- eza ---
echo "[+] eza をインストール中..."
if command -v eza &>/dev/null || [ -x "$HOME/.local/bin/eza" ]; then
  echo "  - eza は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  EZA_ASSET="eza_x86_64-unknown-linux-gnu.tar.gz" ;;
    aarch64) EZA_ASSET="eza_aarch64-unknown-linux-gnu.tar.gz" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/${EZA_ASSET}" \
    | tar xz -C "$HOME/.local/bin"
  chmod +x "$HOME/.local/bin/eza"
  echo "  - eza $("$HOME/.local/bin/eza" --version | head -1) をインストールしました"
fi

# --- lazygit ---
echo "[+] lazygit をインストール中..."
if command -v lazygit &>/dev/null || [ -x "$HOME/.local/bin/lazygit" ]; then
  echo "  - lazygit は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  LG_ARCH="x86_64" ;;
    aarch64) LG_ARCH="arm64"  ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  LG_VERSION=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  LG_URL="https://github.com/jesseduffield/lazygit/releases/download/v${LG_VERSION}/lazygit_${LG_VERSION}_Linux_${LG_ARCH}.tar.gz"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "$LG_URL" | tar xz -C "$HOME/.local/bin" lazygit
  chmod +x "$HOME/.local/bin/lazygit"
  echo "  - lazygit $("$HOME/.local/bin/lazygit" --version | head -1) をインストールしました"
fi

# --- lazydocker ---
echo "[+] lazydocker をインストール中..."
if command -v lazydocker &>/dev/null || [ -x "$HOME/.local/bin/lazydocker" ]; then
  echo "  - lazydocker は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  LD_ARCH="x86_64" ;;
    aarch64) LD_ARCH="arm64"  ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  LD_VERSION=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  LD_URL="https://github.com/jesseduffield/lazydocker/releases/download/v${LD_VERSION}/lazydocker_${LD_VERSION}_Linux_${LD_ARCH}.tar.gz"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "$LD_URL" | tar xz -C "$HOME/.local/bin" lazydocker
  chmod +x "$HOME/.local/bin/lazydocker"
  echo "  - lazydocker $("$HOME/.local/bin/lazydocker" --version | head -1) をインストールしました"
fi

# --- デフォルトシェルを zsh に変更 ---
echo "[+] デフォルトシェルを zsh に変更中..."
ZSH_PATH="$(command -v zsh)"
if [ -n "$ZSH_PATH" ]; then
  if ! grep -qF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "$ZSH_PATH" | sudo -E tee -a /etc/shells
  fi
  CHSH="chsh"
  [ "$(id -u)" -ne 0 ] && CHSH="sudo -E chsh"
  $CHSH -s "$ZSH_PATH" "$(id -un)" && echo "  - デフォルトシェルを $ZSH_PATH に変更しました"
else
  echo "  - WARNING: zsh が見つかりません。デフォルトシェルの変更をスキップします"
fi

echo ""
echo "=== セットアップ完了 ==="
echo "新しいシェルを起動するか、'source ~/.zshrc' を実行してください。"
