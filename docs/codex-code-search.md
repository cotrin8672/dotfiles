# Codex code search plugins

Windows の Codex 用に Codixing 0.48.0 と ast-index 3.56.0 を管理する。
前提は chezmoi、mise、ghq、rtk、Codex CLI。mise の shims をユーザーの PATH に含める。

## 復元

通常の `chezmoi apply` 後に実行する。

```powershell
rtk proxy mise run codex-code-search-install
```

スクリプトは必要な設定だけを適用し、公式リリースの CLI を mise で導入する。
Codixing のローカルマーケットプレイスを `~/.codex/plugin-sources/codixing-local` に配置し、
ast-index の公式 Codex プラグインは `ghq get --branch v3.56.0` で取得する。
Codex 用の manifest・スキル・ライセンスを `~/.codex/plugin-sources/ast-index-plugins` に取り込む。
Claude 用 bash フックと初期設定コマンドは Codex が自動検出してしまうため、取り込み対象から外す。
既存の ghq チェックアウトは変更せず、プラグインのバージョンが合わなければ停止する。
最後にユーザー共通のプラグインとして登録・有効化する。Codex を再起動して新しいチャットで使う。

MCP の起動コマンドは chezmoi の `lookPath "mise"` で生成するため、ユーザー名やインストール先を固定しない。
Codex のプラグインコピーはシンボリックリンクを省くため、プラグインのファイルは `.tmpl` から通常ファイルとして配置する。
Codixing は mise 経由で指定バージョンの MCP を起動し、チャットの作業フォルダーを索引化する。
認証情報、Codex の設定ファイル全体、セッション、プラグインキャッシュ、検索用データベースは Git に含めない。

## 使用

Codixing は「Codixing でこのプロジェクトを GraphRAG 検索して」と依頼する。
読み取り専用の reviewer プロファイルで、BM25 検索と AST 依存グラフを使う。ベクトルモデルは未導入。
編集後に `codixing sync .` しても起動中の MCP が古い結果を返す場合は、新しいチャットで読み直す。

ast-index は公式スキルと CLI の構成で、MCP サーバーは含めない。
対象プロジェクトで初回に索引とグラフを作る。

```powershell
rtk proxy mise exec ast-index@3.56.0 -- ast-index rebuild
rtk proxy mise exec ast-index@3.56.0 -- ast-index graph build
rtk proxy mise exec ast-index@3.56.0 -- ast-index explore "authentication" --rwr
rtk proxy mise exec ast-index@3.56.0 -- ast-index update
```

## 検証

```powershell
rtk proxy powershell -NoProfile -File "$HOME/.local/share/chezmoi/tests/codex_code_search.ps1"
```

別 OS への自動インストールは対象外。mise のリリース選択は移植可能だが、復元タスクは Windows 用。
