#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- オプション解析 ---
AUTO_YES=false

usage() {
  cat <<'USAGE'
Usage: ./setup.sh [OPTIONS]

dotfiles のセットアップスクリプト

Options:
  -y, --yes   すべての確認をスキップして自動インストール
  -h, --help  このヘルプを表示

セットアップ内容:
  1. 必要パッケージ (zsh, git, curl, tmux, fzf, unzip)
  2. Oh My Zsh / Powerlevel10k / zsh プラグイン
  3. シンボリックリンク (.zshrc, .p10k.zsh, .bashrc, tmux.conf.local, zsh-abbr)
  4. Neovim (LazyVim)
  5. オプショナルCLIツール (eza, fd, dust, duf, procs, bottom, tealdeer, yazi, zoxide, atuin, lazygit, lazydocker, uv)
USAGE
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    -y|--yes) AUTO_YES=true ;;
    -h|--help) usage ;;
  esac
done

confirm() {
  local name="$1"
  if [ "$AUTO_YES" = true ]; then
    return 0
  fi
  read -rp "  $name [Y/n] " answer
  case "$answer" in
    [nN]*) return 1 ;;
    *) return 0 ;;
  esac
}

echo "=== dotfiles セットアップ ==="

# --- 必要パッケージのインストール ---
if confirm "必要パッケージ (zsh, git, curl, tmux, fzf) をインストールしますか?"; then
  PACKAGES=(zsh git curl tmux fzf unzip)
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
fi

# --- Homebrew ---
if command -v brew &>/dev/null; then
  echo "[Homebrew] 既にインストール済み: $(brew --version | head -1)"
elif confirm "Homebrew をインストールしますか?"; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # PATHを通す
  if [ -d /home/linuxbrew/.linuxbrew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [ -d "$HOME/.linuxbrew" ]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
  elif [ -d /opt/homebrew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# --- Oh My Zsh ---
if [ -d "$HOME/.oh-my-zsh" ]; then
  echo "[Oh My Zsh] 既にインストール済み"
elif confirm "Oh My Zsh をインストールしますか?"; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# --- Powerlevel10k テーマ ---
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
  echo "[Powerlevel10k] 既にインストール済み"
elif confirm "Powerlevel10k をインストールしますか?"; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# --- zsh プラグイン ---
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if confirm "zsh プラグイン (syntax-highlighting, autosuggestions, fzf-tab, abbr) をインストールしますか?"; then
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

# --- Oh My Tmux ---
if [ -f "$HOME/.local/share/tmux/oh-my-tmux/.tmux.conf" ]; then
  echo "[Oh My Tmux] 既にインストール済み"
elif confirm "Oh My Tmux をインストールしますか?"; then
  mkdir -p "$HOME/.local/share/tmux"
  git clone --single-branch https://github.com/gpakosz/.tmux.git "$HOME/.local/share/tmux/oh-my-tmux"
  mkdir -p "$HOME/.config/tmux"
  ln -sf "$HOME/.local/share/tmux/oh-my-tmux/.tmux.conf" "$HOME/.config/tmux/tmux.conf"
fi

confirm ".zshrc のシンボリックリンクを作成しますか?" && link_file "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
confirm ".p10k.zsh のシンボリックリンクを作成しますか?" && link_file "$SCRIPT_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
confirm ".bashrc のシンボリックリンクを作成しますか?" && link_file "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
if confirm "tmux.conf.local のシンボリックリンクを作成しますか?"; then
  mkdir -p "$HOME/.config/tmux"
  link_file "$SCRIPT_DIR/tmux.conf.local" "$HOME/.config/tmux/tmux.conf.local"
fi

# --- Neovim 本体 ---
if command -v nvim &>/dev/null; then
  echo "[Neovim] 既にインストール済み: $(nvim --version | head -1)"
elif confirm "Neovim をインストールしますか?"; then
  brew install neovim
  echo "  - Neovim をインストールしました"
fi

# --- Neovim (LazyVim) ---
if confirm "Neovim (LazyVim) をセットアップしますか?"; then
  NVIM_DIR="$HOME/.config/nvim"
  if [ ! -d "$NVIM_DIR" ]; then
    echo "  - LazyVim starter をクローン中..."
    git clone https://github.com/LazyVim/starter "$NVIM_DIR"
    rm -rf "$NVIM_DIR/.git"
  fi
  echo "  - カスタマイズファイルを配置中..."
  cp "$SCRIPT_DIR/nvim/lua/config/lazy.lua" "$NVIM_DIR/lua/config/lazy.lua"
fi

# --- zsh-abbr 略語設定 ---
echo "[7/8] zsh-abbr の略語設定を配置中..."

if confirm "zsh-abbr/user-abbreviations のシンボリックリンクを作成しますか?"; then
  mkdir -p "$HOME/.config/zsh-abbr"
  link_file "$SCRIPT_DIR/zsh-abbr/user-abbreviations" "$HOME/.config/zsh-abbr/user-abbreviations"
fi

# --- imgcat ---
if confirm "imgcat をインストールしますか?"; then
  mkdir -p "$HOME/.local/bin"
  cp "$SCRIPT_DIR/bin/imgcat" "$HOME/.local/bin/imgcat"
  chmod +x "$HOME/.local/bin/imgcat"
  echo "  - imgcat -> $HOME/.local/bin/imgcat"
fi

# =============================================================================
# オプショナルCLIツール
# =============================================================================
echo ""
echo "=== オプショナルCLIツール ==="

# --- uv ---
if command -v uv &>/dev/null; then
  echo "[uv] 既にインストール済み: $(uv --version)"
elif confirm "uv (Python パッケージマネージャ)"; then
  brew install uv
  echo "  - uv をインストールしました"
fi

# --- eza ---
if command -v eza &>/dev/null; then
  echo "[eza] 既にインストール済み"
elif confirm "eza (モダンな ls)"; then
  brew install eza
  echo "  - eza をインストールしました"
fi

# --- fd ---
if command -v fd &>/dev/null; then
  echo "[fd] 既にインストール済み"
elif confirm "fd (モダンな find)"; then
  brew install fd
  echo "  - fd をインストールしました"
fi

# --- dust ---
if command -v dust &>/dev/null; then
  echo "[dust] 既にインストール済み"
elif confirm "dust (モダンな du)"; then
  brew install dust
  echo "  - dust をインストールしました"
fi

# --- duf ---
if command -v duf &>/dev/null; then
  echo "[duf] 既にインストール済み"
elif confirm "duf (モダンな df)"; then
  brew install duf
  echo "  - duf をインストールしました"
fi

# --- procs ---
if command -v procs &>/dev/null; then
  echo "[procs] 既にインストール済み"
elif confirm "procs (モダンな ps)"; then
  brew install procs
  echo "  - procs をインストールしました"
fi

# --- bottom ---
if command -v btm &>/dev/null; then
  echo "[bottom] 既にインストール済み"
elif confirm "bottom (モダンな top)"; then
  brew install bottom
  echo "  - bottom をインストールしました"
fi

# --- tealdeer ---
if command -v tldr &>/dev/null; then
  echo "[tealdeer] 既にインストール済み"
elif confirm "tealdeer (tldr コマンドチートシート)"; then
  brew install tealdeer
  echo "  - tealdeer をインストールしました"
fi

# --- yazi ---
if command -v yazi &>/dev/null; then
  echo "[yazi] 既にインストール済み"
elif confirm "yazi (ターミナルファイルマネージャ)"; then
  brew install yazi
  echo "  - yazi をインストールしました"
fi

# --- zoxide ---
if command -v zoxide &>/dev/null; then
  echo "[zoxide] 既にインストール済み"
elif confirm "zoxide (スマート cd)"; then
  brew install zoxide
  echo "  - zoxide をインストールしました"
fi

# --- atuin ---
if command -v atuin &>/dev/null; then
  echo "[atuin] 既にインストール済み"
elif confirm "atuin (シェル履歴管理)"; then
  brew install atuin
  echo "  - atuin をインストールしました"
fi

# --- lazygit ---
if command -v lazygit &>/dev/null; then
  echo "[lazygit] 既にインストール済み"
elif confirm "lazygit (Git TUI)"; then
  brew install lazygit
  echo "  - lazygit をインストールしました"
fi

# --- lazydocker ---
if command -v lazydocker &>/dev/null; then
  echo "[lazydocker] 既にインストール済み"
elif confirm "lazydocker (Docker TUI)"; then
  brew install lazydocker
  echo "  - lazydocker をインストールしました"
fi

# --- デフォルトシェルを zsh に変更 ---
echo ""
if confirm "デフォルトシェルを zsh に変更しますか?"; then
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
fi

echo ""
echo "=== セットアップ完了 ==="

if [ "$(basename "$SHELL")" != "zsh" ] && command -v zsh &>/dev/null; then
  echo "zsh を起動します..."
  exec zsh -l
fi
