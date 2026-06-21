# セットアップ仕様

## M2 batcat の導入

### T-001 batcat を必要パッケージへ追加

- `setup.sh` の必要パッケージとして bat をインストールする。
- Debian / Ubuntu では `bat` パッケージが提供する `batcat` コマンドを使用する。
- Homebrew では `bat` パッケージをインストールし、`batcat` のシンボリックリンクを作成する。
- APTで `bat` が提供されないUbuntuでは、Homebrewから補完する。
- 対話確認とヘルプには、利用者が実行するコマンド名として `batcat` を表示する。

## M3 Ubuntuのロケールとタイムゾーン設定

### T-001 ja_JP.UTF-8とAsia/Tokyoを設定

- Debian / Ubuntuでは必要パッケージとして `locales` と `tzdata` をインストールする。
- `locale-gen ja_JP.UTF-8` で日本語UTF-8ロケールを生成する。
- `update-locale LANG=ja_JP.UTF-8` で既定ロケールを設定する。
- セットアップ中の環境にも `LANG=ja_JP.UTF-8` を反映し、直後に起動するzshとtmuxへ継承する。
- `/etc/localtime` を `/usr/share/zoneinfo/Asia/Tokyo` へのシンボリックリンクにする。
- rootでない場合は、システム設定コマンドを `sudo -E` 経由で実行する。
