# xRDP + XFCE4 セットアップ手順（参考）

> **注意**: 現在はSunshine + Moonlightに移行済み。本ドキュメントは参考記録として残す。

Ubuntu 24.04 + GNOME環境でxRDPからXFCE4デスクトップへ接続するための手順。

## インストール

```bash
sudo apt install -y xrdp xorgxrdp tigervnc-scraping-server
```

## ウィンドウマネージャの設定

xRDPはデフォルトで `~/.xsession` を参照してウィンドウマネージャを起動する。

```bash
cat > ~/.xsession << 'EOF'
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
xfce4-session
EOF
```

### ポイント

- `startxfce4` ではなく `xfce4-session` を使う
  - `startxfce4` はX serverの起動を試み、既存のものを検知して即終了する
- `DBUS_SESSION_BUS_ADDRESS` と `XDG_RUNTIME_DIR` をunsetする
  - 既存のGNOMEセッションとDBUSが競合して `xfce4-session` が即終了するのを防ぐ

## 起動・有効化

```bash
sudo systemctl enable xrdp
sudo systemctl start xrdp
```

## 接続方法

- ポート: `3389`
- ユーザー名: Linuxのユーザー名
- パスワード: Linuxのログインパスワード（sudoパスワードと同じ）

## トラブルシューティング

### パスワード認証に失敗する

pamtesterで認証テスト：

```bash
pamtester xrdp-sesman $USER authenticate
```

`successfully authenticated` が出ればPAMは正常。xRDPクライアント側の入力ミスを疑う。

### デスクトップに遷移せず即切断される

`~/.xsession-errors` を確認：

```bash
cat ~/.xsession-errors | tail -50
```

よくある原因：

| エラー | 原因 | 対処 |
|--------|------|------|
| `X server already running` | `startxfce4` がX serverを起動しようとしている | `xfce4-session` に変更 |
| `pam_authenticate failed` | パスワード誤り or DBUSの競合 | `unset DBUS_SESSION_BUS_ADDRESS` を追加 |
| `failed to load driver: nouveau` | NVIDIAプロプライエタリドライバ環境でのGLXエラー | 無視可（描画には影響しない） |
