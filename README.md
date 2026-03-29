# dotfiles

個人環境の設定ファイル管理リポジトリ。

## 含まれる設定

| ファイル | 説明 |
|---------|------|
| `.zshrc` | zsh 設定（Oh My Zsh + プラグイン） |
| `.p10k.zsh` | Powerlevel10k テーマ設定 |
| `.bashrc` | bash 設定 |
| `.wezterm.lua` | WezTerm 設定（ランダムダークテーマ） |
| `tmux.conf.local` | tmux 設定（Oh My Tmux カスタマイズ） |
| `nvim/` | Neovim (LazyVim) カスタマイズ設定 |
| `zsh-abbr/user-abbreviations` | zsh-abbr 略語定義 |
| `bin/` | カスタムスクリプト（imgcat） |

## zsh プラグイン

- [powerlevel10k](https://github.com/romkatv/powerlevel10k) - テーマ
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) - コマンドのシンタックスハイライト
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) - 履歴ベースの入力補完
- [zsh-abbr](https://github.com/olets/zsh-abbr) - 略語展開
- [fzf-tab](https://github.com/Aloxaf/fzf-tab) - fzf によるタブ補完

## CLIツール

セットアップスクリプトで以下のツールがインストールされます：

| ツール | 説明 |
|--------|------|
| [eza](https://github.com/eza-community/eza) | モダンな `ls` 代替（アイコン・Git対応） |
| [fd](https://github.com/sharkdp/fd) | モダンな `find` 代替（高速・.gitignore認識） |
| [dust](https://github.com/bootandy/dust) | モダンな `du` 代替（ツリー＋バーグラフ） |
| [duf](https://github.com/muesli/duf) | モダンな `df` 代替（テーブル表示） |
| [procs](https://github.com/dalance/procs) | モダンな `ps` 代替（カラー・ツリー表示） |
| [bottom](https://github.com/ClementTsang/bottom) | モダンな `top` 代替（グラフ・GPU対応） |
| [tealdeer](https://github.com/tealdeer-rs/tealdeer) | tldr クライアント（コマンドのチートシート） |
| [yazi](https://github.com/sxyazi/yazi) | ターミナルファイルマネージャ |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | スマート `cd`（使用頻度ベース） |
| [atuin](https://github.com/atuinsh/atuin) | シェル履歴管理（SQLite・デバイス間同期） |
| [lazygit](https://github.com/jesseduffield/lazygit) | Git TUI |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Docker TUI |
| [uv](https://github.com/astral-sh/uv) | Python パッケージマネージャ |
| [Neovim](https://github.com/neovim/neovim) | テキストエディタ（LazyVim構成） |

## セットアップ

```bash
git clone https://github.com/yus-ko/dotfiles.git
cd ~/dotfiles
./setup.sh
```

セットアップスクリプトは以下を自動で行います：

1. 必要パッケージのインストール（zsh, git, curl, tmux, fzf）
2. Oh My Zsh のインストール
3. Powerlevel10k テーマのインストール
4. zsh プラグインのインストール
5. 各設定ファイルのシンボリックリンク作成（既存ファイルは `tmp/` にバックアップ）
6. Neovim セットアップ（LazyVim starter + カスタマイズファイル）
7. zsh-abbr の略語設定の配置
8. CLIツールのインストール
9. デフォルトシェルを zsh に変更
