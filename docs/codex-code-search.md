# Codex code search plugins

Windows の Codex 用に Codixing 0.48.0、ast-index 3.56.0、MCP Language Server 0.1.1-codex.1 を管理する。
前提は chezmoi、mise、ghq、rtk、Codex CLI。mise の shims をユーザーの PATH に含める。
Neovim の Mason で rust-analyzer と typescript-language-server をインストール済みにする。

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

MCP Language Server は同じ `codixing-local` マーケットプレイスの別プラグインとして登録する。
Mason の既定パス `%LOCALAPPDATA%/nvim-data/mason/packages` にある LSP 本体を再利用する。
ユーザー名は chezmoi が生成し、Mason のバージョン更新後も同じパスを使う。
`mcp-language-server` は ghq で取得し、v0.1.1 のコミット
`46e2950b7969334780675e7797e13f140d2d42ac` を一時フォルダーに展開してビルドする。
共有チェックアウトは変更しない。Windows の URI・UTF-16 の編集位置・ファイル監視を補正するパッチと回帰テストは
`dot_codex/language-server/windows.patch` で管理する。修正済みバイナリとライセンスは
`~/.local/share/codex-language-server/0.1.1-codex.1` に配置し、同じパッチなら再ビルドしない。
ビルドには mise の Go 1.27.1 を使い、既存の Go／Rust／Node の選択を更新しない。
Rust の標準ライブラリ解析用に rust-src を追加する。
TypeScript はプロジェクト内の tsserver を優先し、なければ mise の TypeScript 5.9.2 にフォールバックする。
既存のグローバル TypeScript の選択は変更しない。

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

MCP Language Server は `lsp-rust` と `lsp-typescript` の2つの MCP 接続を提供する。
「LSP でこの関数の定義・参照・型・診断を調べて」と依頼する。TypeScript と JavaScript は同じ接続を使う。
行・列番号は1始まり。`rename_symbol` と `edit_file` は実際のファイルを変更する。
Rust は Cargo.toml のあるプロジェクトで使い、初回の解析中に結果が空または `content modified` なら少し待って再照会する。
MATLAB は導入対象外。

## 検証

```powershell
rtk proxy powershell -NoProfile -File "$HOME/.local/share/chezmoi/tests/codex_code_search.ps1"
```

別 OS への自動インストールは対象外。mise のリリース選択は移植可能だが、復元タスクは Windows 用。
