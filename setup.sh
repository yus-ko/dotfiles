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

# --- procs ---
echo "[+] procs をインストール中..."
if command -v procs &>/dev/null || [ -x "$HOME/.local/bin/procs" ]; then
  echo "  - procs は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  PROCS_ARCH="x86_64" ;;
    aarch64) PROCS_ARCH="aarch64" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  PROCS_VERSION=$(curl -fsSL "https://api.github.com/repos/dalance/procs/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  PROCS_URL="https://github.com/dalance/procs/releases/download/v${PROCS_VERSION}/procs-v${PROCS_VERSION}-${PROCS_ARCH}-linux.zip"
  PROCS_TMP="$(mktemp -d)"
  curl -fsSL "$PROCS_URL" -o "$PROCS_TMP/procs.zip"
  unzip -q "$PROCS_TMP/procs.zip" -d "$PROCS_TMP"
  mkdir -p "$HOME/.local/bin"
  cp "$PROCS_TMP/procs" "$HOME/.local/bin/procs"
  chmod +x "$HOME/.local/bin/procs"
  rm -rf "$PROCS_TMP"
  echo "  - procs $("$HOME/.local/bin/procs" --version) をインストールしました"
fi

# --- bottom ---
echo "[+] bottom をインストール中..."
if command -v btm &>/dev/null || [ -x "$HOME/.local/bin/btm" ]; then
  echo "  - bottom は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  BTM_ARCH="x86_64-unknown-linux-gnu" ;;
    aarch64) BTM_ARCH="aarch64-unknown-linux-gnu" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  BTM_VERSION=$(curl -fsSL "https://api.github.com/repos/ClementTsang/bottom/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
  BTM_URL="https://github.com/ClementTsang/bottom/releases/download/${BTM_VERSION}/bottom_${BTM_ARCH}.tar.gz"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "$BTM_URL" | tar xz -C "$HOME/.local/bin" btm
  chmod +x "$HOME/.local/bin/btm"
  echo "  - bottom $("$HOME/.local/bin/btm" --version) をインストールしました"
fi

# --- tealdeer ---
echo "[+] tealdeer をインストール中..."
if command -v tldr &>/dev/null || [ -x "$HOME/.local/bin/tldr" ]; then
  echo "  - tealdeer は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  TLDR_ARCH="x86_64" ;;
    aarch64) TLDR_ARCH="aarch64" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-${TLDR_ARCH}-musl" \
    -o "$HOME/.local/bin/tldr"
  chmod +x "$HOME/.local/bin/tldr"
  echo "  - tealdeer $("$HOME/.local/bin/tldr" --version) をインストールしました"
fi

# --- yazi ---
echo "[+] yazi をインストール中..."
if command -v yazi &>/dev/null || [ -x "$HOME/.local/bin/yazi" ]; then
  echo "  - yazi は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  YAZI_ARCH="x86_64-unknown-linux-gnu" ;;
    aarch64) YAZI_ARCH="aarch64-unknown-linux-gnu" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  YAZI_VERSION=$(curl -fsSL "https://api.github.com/repos/sxyazi/yazi/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  YAZI_URL="https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-${YAZI_ARCH}.zip"
  YAZI_TMP="$(mktemp -d)"
  curl -fsSL "$YAZI_URL" -o "$YAZI_TMP/yazi.zip"
  unzip -q "$YAZI_TMP/yazi.zip" -d "$YAZI_TMP"
  mkdir -p "$HOME/.local/bin"
  cp "$YAZI_TMP"/yazi-*/yazi "$HOME/.local/bin/yazi"
  cp "$YAZI_TMP"/yazi-*/ya "$HOME/.local/bin/ya"
  chmod +x "$HOME/.local/bin/yazi" "$HOME/.local/bin/ya"
  rm -rf "$YAZI_TMP"
  echo "  - yazi $("$HOME/.local/bin/yazi" --version) をインストールしました"
fi

# --- zoxide ---
echo "[+] zoxide をインストール中..."
if command -v zoxide &>/dev/null || [ -x "$HOME/.local/bin/zoxide" ]; then
  echo "  - zoxide は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ZO_ARCH="x86_64-unknown-linux-musl" ;;
    aarch64) ZO_ARCH="aarch64-unknown-linux-musl" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  ZO_VERSION=$(curl -fsSL "https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  ZO_URL="https://github.com/ajeetdsouza/zoxide/releases/download/v${ZO_VERSION}/zoxide-${ZO_VERSION}-${ZO_ARCH}.tar.gz"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "$ZO_URL" | tar xz -C "$HOME/.local/bin" zoxide
  chmod +x "$HOME/.local/bin/zoxide"
  echo "  - zoxide $("$HOME/.local/bin/zoxide" --version) をインストールしました"
fi

# --- atuin ---
echo "[+] atuin をインストール中..."
if command -v atuin &>/dev/null || [ -x "$HOME/.local/bin/atuin" ]; then
  echo "  - atuin は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ATUIN_ARCH="x86_64-unknown-linux-gnu" ;;
    aarch64) ATUIN_ARCH="aarch64-unknown-linux-gnu" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  ATUIN_VERSION=$(curl -fsSL "https://api.github.com/repos/atuinsh/atuin/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  ATUIN_URL="https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/atuin-${ATUIN_ARCH}.tar.gz"
  ATUIN_TMP="$(mktemp -d)"
  curl -fsSL "$ATUIN_URL" | tar xz -C "$ATUIN_TMP"
  mkdir -p "$HOME/.local/bin"
  cp "$ATUIN_TMP"/atuin-*/atuin "$HOME/.local/bin/atuin"
  chmod +x "$HOME/.local/bin/atuin"
  rm -rf "$ATUIN_TMP"
  echo "  - atuin $("$HOME/.local/bin/atuin" --version) をインストールしました"
fi

# --- duf ---
echo "[+] duf をインストール中..."
if command -v duf &>/dev/null || [ -x "$HOME/.local/bin/duf" ]; then
  echo "  - duf は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  DUF_ARCH="x86_64" ;;
    aarch64) DUF_ARCH="arm64" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  DUF_VERSION=$(curl -fsSL "https://api.github.com/repos/muesli/duf/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  DUF_URL="https://github.com/muesli/duf/releases/download/v${DUF_VERSION}/duf_${DUF_VERSION}_linux_${DUF_ARCH}.tar.gz"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "$DUF_URL" | tar xz -C "$HOME/.local/bin" duf
  chmod +x "$HOME/.local/bin/duf"
  echo "  - duf $("$HOME/.local/bin/duf" --version) をインストールしました"
fi

# --- dust ---
echo "[+] dust をインストール中..."
if command -v dust &>/dev/null || [ -x "$HOME/.local/bin/dust" ]; then
  echo "  - dust は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  DUST_ARCH="x86_64-unknown-linux-gnu" ;;
    aarch64) DUST_ARCH="aarch64-unknown-linux-gnu" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  DUST_VERSION=$(curl -fsSL "https://api.github.com/repos/bootandy/dust/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  DUST_URL="https://github.com/bootandy/dust/releases/download/v${DUST_VERSION}/dust-v${DUST_VERSION}-${DUST_ARCH}.tar.gz"
  DUST_TMP="$(mktemp -d)"
  curl -fsSL "$DUST_URL" | tar xz -C "$DUST_TMP"
  mkdir -p "$HOME/.local/bin"
  cp "$DUST_TMP"/dust-v*/dust "$HOME/.local/bin/dust"
  chmod +x "$HOME/.local/bin/dust"
  rm -rf "$DUST_TMP"
  echo "  - dust $("$HOME/.local/bin/dust" --version) をインストールしました"
fi

# --- fd ---
echo "[+] fd をインストール中..."
if command -v fd &>/dev/null || [ -x "$HOME/.local/bin/fd" ]; then
  echo "  - fd は既にインストール済み"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  FD_ARCH="x86_64-unknown-linux-gnu" ;;
    aarch64) FD_ARCH="aarch64-unknown-linux-gnu" ;;
    *) echo "  - ERROR: 未対応アーキテクチャ: $ARCH"; exit 1 ;;
  esac
  FD_VERSION=$(curl -fsSL "https://api.github.com/repos/sharkdp/fd/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  FD_URL="https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${FD_ARCH}.tar.gz"
  FD_TMP="$(mktemp -d)"
  curl -fsSL "$FD_URL" | tar xz -C "$FD_TMP"
  mkdir -p "$HOME/.local/bin"
  cp "$FD_TMP"/fd-v*/fd "$HOME/.local/bin/fd"
  chmod +x "$HOME/.local/bin/fd"
  rm -rf "$FD_TMP"
  echo "  - fd $("$HOME/.local/bin/fd" --version) をインストールしました"
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
