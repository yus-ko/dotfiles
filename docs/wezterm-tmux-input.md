# Windows WezTerm + SSH + tmux 入力安定化仕様

Windows にインストールした WezTerm から SSH でこの PC へ接続し、Linux 側 tmux を使うときに、マウス操作と `Ctrl+Arrow` によるペイン移動を安定して扱うための設定。

## M1: 入力シーケンスの明示化

### 背景

入力は `Windows WezTerm -> ssh -> Linux tmux` の順に届く。WezTerm 側で修飾キー付き矢印が別機能に消費されたり、tmux 側で拡張キー・マウスレポートの解釈が揃っていなかったりすると、アプリケーションのモードや端末判定によってマウス操作や `Ctrl+Arrow` が効かないことがある。

### T-001: WezTerm と tmux の入力シーケンスを明示する

#### Windows 側 WezTerm

- この設定は Windows 側で WezTerm が実際に読み込む `.wezterm.lua` に反映する。
- `config.enable_csi_u_key_encoding = true` を有効にする。
- `Ctrl+Left/Down/Up/Right` は WezTerm のデフォルト処理に任せず、端末内アプリケーションへ `SendKey` で渡す。

#### Linux 側 tmux

- `mouse on` を維持する。
- `xterm-keys` と `extended-keys` を有効化する。
- 外側端末 `wezterm` に対して `RGB`、`clipboard`、`extkeys`、`mouse` の terminal features を宣言する。
- SSH 越しに `$TERM=xterm-256color` として届く環境でも True Color を維持する。
- tmux のキー表記は `C-Left` のように標準的な大文字表記へ統一する。

## 動作確認

Windows 側 WezTerm の設定を反映したうえで、SSH 接続後の既存 tmux セッション内で次を実行する。

```bash
tmux source-file ~/.tmux.conf
```

その後、複数ペインを作成して以下を確認する。

- `Ctrl+Left/Down/Up/Right` でペイン移動できる。
- マウスクリックでペイン選択できる。
- マウスドラッグでペイン境界をリサイズできる。
- copy-mode や TUI アプリ利用後も上記操作が維持される。
