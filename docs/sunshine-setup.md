# Sunshine + Moonlight セットアップ手順

Ubuntu 24.04 + GNOME (X11) + RTX 3090 環境での手順。
xRDP/VNC からの置き換えを想定。

## 環境

- OS: Ubuntu 24.04 LTS
- DE: GNOME (X11, GDM)
- GPU: RTX 3090 (NVENC 対応)
- ディスプレイ: `:0`（GDM管理）、`:10`（xRDP仮想）

## インストール

```bash
# GitHub Releases から Ubuntu 24.04 向け .deb をダウンロード
wget https://github.com/LizardByte/Sunshine/releases/download/v2025.924.154138/sunshine-ubuntu-24.04-amd64.deb -O /tmp/sunshine.deb

sudo apt install -y /tmp/sunshine.deb
```

## 初期設定

### udev ルール適用 / グループ追加

```bash
sudo usermod -aG input $USER
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo modprobe uinput
```

> `usermod` の変更は再起動するまでログインセッションには反映されない。
> 再起動前は下記の一時対処で回避する。

### /dev/uinput・/dev/uhid のパーミッション（一時対処）

再起動前の暫定措置として手動でパーミッションを緩める。再起動で元に戻る。

```bash
sudo chmod a+rw /dev/uinput /dev/uhid
```

再起動後も有効にするには udev ルールを上書きする：

```bash
sudo tee /etc/udev/rules.d/61-sunshine-override.rules << 'EOF'
KERNEL=="uinput", MODE="0666"
KERNEL=="uhid", MODE="0666"
EOF
```

### systemd サービス起動

```bash
systemctl --user enable sunshine
systemctl --user start sunshine
```

## xRDP 環境特有の問題と対処

### 問題

xRDP がログインセッションの `DISPLAY` 環境変数を `:10`（xRDP 仮想ディスプレイ）に上書きする。
そのため systemd ユーザーサービスの Sunshine が xRDP の仮想ディスプレイを見てしまい、
キャプチャ・入力ともに正しく動作しない。

**症状**
- ログに `Detected display: rdp0` と出る（正しくは `:0`）
- マウス・キーボード操作が Moonlight から効かない

### 対処：service override で正しい DISPLAY を指定

```bash
mkdir -p ~/.config/systemd/user/sunshine.service.d
cat > ~/.config/systemd/user/sunshine.service.d/override.conf << 'EOF'
[Service]
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/run/user/1000/gdm/Xauthority"
EOF

systemctl --user daemon-reload
systemctl --user restart sunshine
```

正常時はログに `Screencasting with NvFBC` と表示される。

## Moonlight から接続

1. Web UI でユーザー/パスワードを設定: `https://<ホストIP>:47990`
   - 証明書警告は無視して進む
2. Applications → Add New
   - **Application Name**: `Desktop`
   - **Command**: 空欄（デスクトップ全体をストリーム）
3. Moonlight でホストの IP を入力 → PIN を入力して接続

## 使用ポート

| ポート | 用途 |
|--------|------|
| 47984/tcp | HTTPS ストリーム制御 |
| 47989/tcp | HTTP |
| 47990/tcp | Web UI |
| 48010/tcp | RTSP |
| 47998-48000/udp | 映像・音声・制御 |
