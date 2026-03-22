# dotfiles

個人環境の設定ファイル管理リポジトリ。

## 含まれる設定

| ファイル | 説明 |
|---------|------|
| `.zshrc` | zsh 設定（Oh My Zsh + プラグイン） |
| `.p10k.zsh` | Powerlevel10k テーマ設定 |
| `.bashrc` | bash 設定 |
| `.tmux.conf` | tmux 設定 |
| `nvim/` | Neovim (LazyVim) カスタマイズ設定 |
| `zsh-abbr/user-abbreviations` | zsh-abbr 略語定義 |

## zsh プラグイン

- [powerlevel10k](https://github.com/romkatv/powerlevel10k) - テーマ
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) - コマンドのシンタックスハイライト
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) - 履歴ベースの入力補完
- [zsh-abbr](https://github.com/olets/zsh-abbr) - 略語展開

## セットアップ

```bash
git clone https://github.com/yus-ko/dotfiles.git
cd ~/dotfiles
./setup.sh
```

セットアップスクリプトは以下を自動で行います：

1. Oh My Zsh のインストール
2. Powerlevel10k テーマのインストール
3. zsh プラグインのインストール（syntax-highlighting, autosuggestions, abbr）
4. 各設定ファイルのシンボリックリンク作成（既存ファイルはバックアップ）
5. Neovim セットアップ（LazyVim starter + カスタマイズファイル上書き）
6. zsh-abbr の略語設定の配置
