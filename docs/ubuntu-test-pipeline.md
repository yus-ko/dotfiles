# Ubuntuテストパイプライン仕様

## M4 Ubuntuバージョン別セットアップテスト

### T-001 Docker Composeによるテストマトリクス

- `ubuntu:16.04`、`ubuntu:18.04`、`ubuntu:20.04`、`ubuntu:22.04`、`ubuntu:24.04`、`ubuntu:26.04` をベースイメージにしたサービスを `docker-compose.yml` で管理する。
- 各サービスは共通の `tests/docker/Dockerfile` を使用し、ビルド引数 `UBUNTU_VERSION` で対象バージョンを切り替える。
- イメージには `sudo`、`git`、`adduser`、`ca-certificates` を導入し、sudoを利用できる一般ユーザー `jhondoe` を作成する。
- テスト対象にはGitHub上の既存状態ではなく、Dockerイメージのビルド時点におけるローカル作業ツリーを使用する。

### T-002 セットアップ実行と結果検証

- 各サービスで `jhondoe` として `./setup.sh -y` を非TTY環境で実行する。
- 非TTY環境ではセットアップ完了後のログインzsh起動を省略し、検証スクリプトへ制御を戻す。
- セットアップ後に以下を検証し、いずれかを満たさない場合はサービスを異常終了させる。
  - `zsh`、`git`、`curl`、`tmux`、`fzf`、`unzip`、`batcat` が実行可能であること。
  - `ja_JP.UTF-8` ロケールが生成されていること。
  - `/etc/localtime` が `/usr/share/zoneinfo/Asia/Tokyo` を参照していること。
  - dotfilesの主要なシンボリックリンクが作成されていること。
- 全バージョンのテストは `docker compose up --build --abort-on-container-failure` で実行できること。
- テスト後のコンテナは `docker compose down` で削除できること。

### T-003 Ubuntu旧版の必須パッケージ補完

- APTのパッケージ一覧を更新後、各必須パッケージが提供されているか確認する。
- APTで提供されない `fzf` と `bat` は、Homebrewの導入後にインストールする。
- Ubuntu 16.04に同梱されるGitでも動作するよう、サブモジュールのクローンには `--shallow-submodules` を使用しない。
- Homebrew版 `bat` には `batcat` のシンボリックリンクを作成し、全Ubuntuバージョンで同じコマンド名を利用できるようにする。

## 実行方法

```bash
docker compose up --build --abort-on-container-failure
docker compose down
```

特定バージョンだけをテストする場合はサービス名を指定する。

```bash
docker compose run --rm ubuntu-24-04
```
