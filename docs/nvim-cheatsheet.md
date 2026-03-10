# Neovim Cheat Sheet

このドキュメントは `dot_config/nvim` 配下の設定を読み取り、現在の設定で使える操作を Markdown で網羅したものです。  
対象は 2026-03-10 時点のこのリポジトリで、設定ファイルに明示されたものと、設定がデフォルトを採用しているプラグインについてはその実効デフォルトも含めています。

## 前提

- `mapleader` は `<Space>`
- 主な参照元:
  - `dot_config/nvim/init.lua`
  - `dot_config/nvim/lua/plugins/*.lua`
  - `~/.local/share/nvim/lazy/mini.nvim/lua/mini/surround.lua` (`mini.surround` の既定値確認用)

## 読み方

- `n` = Normal
- `x` = Visual
- `o` = Operator-pending
- `i` = Insert
- `t` = Terminal
- `c` = Command-line

## 全体サマリ

- ウィンドウ移動は `Alt-h/j/k/l`
- バッファ移動は `<Tab>` / `<S-Tab>`
- ファイル探索は `-`, `<leader>o`, `<leader>O`, `<leader>pp`, `<leader>pf`
- 検索系は `s`, `S`, `n`, `N`, `*`, `#`, `g*`, `g#`
- LSP 通常操作は `gd`, `gD`, `gi`, `gr`, `K`, `<leader>rn`, `<leader>ca`
- Submode は `<leader>w`, `<leader>l`, `<leader>d`
- コメントは `<leader>cc`, `<leader>cb`, `<leader>c{motion}`, `<leader>b{motion}`
- Surround は `sa`, `sd`, `sr`, `sf`, `sF`, `sh`
- Treesitter text object は `af`, `if`, `ac`, `ic`, `aa`, `ia`

## ジャンル別ショートカット

### 基本移動・モード切替

| Key | Mode | Action | Source |
|---|---|---|---|
| `jj` | `i` | Insert から Normal に戻る | `dot_config/nvim/init.lua` |
| `jj` | `t` | Terminal から Normal に戻る | `dot_config/nvim/init.lua` |
| `j` | `n` | `accelerated-jk` による加速スクロール下移動 | `dot_config/nvim/lua/plugins/accelerated-jk.lua` |
| `k` | `n` | `accelerated-jk` による加速スクロール上移動 | `dot_config/nvim/lua/plugins/accelerated-jk.lua` |
| `<C-j>` | `n` | 画面下端へエッジ移動 | `dot_config/nvim/lua/plugins/edgemotion.lua` |
| `<C-k>` | `n` | 画面上端へエッジ移動 | `dot_config/nvim/lua/plugins/edgemotion.lua` |

### ウィンドウ・バッファ

| Key | Mode | Action | Source |
|---|---|---|---|
| `<M-h>` | `n` | 左ウィンドウへ移動 | `dot_config/nvim/init.lua` |
| `<M-j>` | `n` | 下ウィンドウへ移動 | `dot_config/nvim/init.lua` |
| `<M-k>` | `n` | 上ウィンドウへ移動 | `dot_config/nvim/init.lua` |
| `<M-l>` | `n` | 右ウィンドウへ移動 | `dot_config/nvim/init.lua` |
| `<Tab>` | `n` | 次バッファ | `dot_config/nvim/lua/plugins/barbar.lua` |
| `<S-Tab>` | `n` | 前バッファ | `dot_config/nvim/lua/plugins/barbar.lua` |
| `<leader>x` | `n` | バッファを閉じる | `dot_config/nvim/init.lua`, `dot_config/nvim/lua/plugins/barbar.lua` |
| `<leader>w` | `n` | WINDOW submode に入る | `dot_config/nvim/lua/plugins/submode.lua` |

### ファイル・ツリー・ピッカー

| Key | Mode | Action | Source |
|---|---|---|---|
| `-` | `n` | `Oil` で親ディレクトリを開く | `dot_config/nvim/lua/plugins/oil.lua` |
| `<leader>o` | `n` | `Oil` を float で開く | `dot_config/nvim/lua/plugins/oil.lua` |
| `<leader>O` | `n` | `Oil` を通常ウィンドウで開く | `dot_config/nvim/lua/plugins/oil.lua` |
| `<leader>e` | `n` | `Neo-tree` をトグル | `dot_config/nvim/lua/plugins/neo-tree.lua` |
| `<leader>pf` | `n` | Smart picker: `buffers`/`recent`/`git_files or files` | `dot_config/nvim/lua/plugins/snacks.lua` |
| `<leader>pp` | `n` | Files picker | `dot_config/nvim/lua/plugins/snacks.lua` |
| `<leader>pg` | `n` | Grep picker | `dot_config/nvim/lua/plugins/snacks.lua` |
| `<leader>f` | `n` | Floating terminal | `dot_config/nvim/lua/plugins/snacks.lua` |

### Oil バッファ内

| Key | Mode | Action | Source |
|---|---|---|---|
| `<CR>` | Oil | ファイルを開く | `dot_config/nvim/lua/plugins/oil.lua` |
| `<C-s>` | Oil | 垂直分割で開く | `dot_config/nvim/lua/plugins/oil.lua` |
| `<C-h>` | Oil | 水平分割で開く | `dot_config/nvim/lua/plugins/oil.lua` |
| `<C-t>` | Oil | タブで開く | `dot_config/nvim/lua/plugins/oil.lua` |
| `-` | Oil | 親ディレクトリへ戻る | `dot_config/nvim/lua/plugins/oil.lua` |
| `g.` | Oil | 隠しファイル表示の切替 | `dot_config/nvim/lua/plugins/oil.lua` |
| `q` | Oil | 閉じる | `dot_config/nvim/lua/plugins/oil.lua` |

### 検索・ジャンプ

| Key | Mode | Action | Source |
|---|---|---|---|
| `s` | `n/x/o` | Flash jump | `dot_config/nvim/lua/plugins/flash.lua` |
| `S` | `n/x/o` | Flash Treesitter jump | `dot_config/nvim/lua/plugins/flash.lua` |
| `r` | `o` | Remote Flash | `dot_config/nvim/lua/plugins/flash.lua` |
| `R` | `o/x` | Treesitter search | `dot_config/nvim/lua/plugins/flash.lua` |
| `<C-s>` | `c` | Flash search のトグル | `dot_config/nvim/lua/plugins/flash.lua` |
| `n` | `n` | 次の検索結果 + hlslens 表示更新 | `dot_config/nvim/lua/plugins/hlslens.lua` |
| `N` | `n` | 前の検索結果 + hlslens 表示更新 | `dot_config/nvim/lua/plugins/hlslens.lua` |
| `*` | `n` | カーソル下単語を前方検索 + hlslens | `dot_config/nvim/lua/plugins/hlslens.lua` |
| `#` | `n` | カーソル下単語を後方検索 + hlslens | `dot_config/nvim/lua/plugins/hlslens.lua` |
| `g*` | `n` | 部分一致前方検索 + hlslens | `dot_config/nvim/lua/plugins/hlslens.lua` |
| `g#` | `n` | 部分一致後方検索 + hlslens | `dot_config/nvim/lua/plugins/hlslens.lua` |

### LSP・診断

| Key | Mode | Action | Source |
|---|---|---|---|
| `gd` | `n` | 定義へ移動 (`Lspsaga goto_definition`) | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `gD` | `n` | 宣言へ移動 | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `gi` | `n` | 実装へ移動 | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `gr` | `n` | 参照一覧を独自 float で開く | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `K` | `n` | Hover | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `<leader>rn` | `n` | `IncRename` で rename | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `<leader>ca` | `n` | Code Action | `dot_config/nvim/lua/plugins/lspsaga.lua`, `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `[d` | `n` | 前の diagnostic | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `]d` | `n` | 次の diagnostic | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `<leader>q` | `n` | diagnostic を location list へ送る | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `<leader>l` | `n` | LSP submode に入る | `dot_config/nvim/lua/plugins/submode.lua` |

### トラブルシュート・Quickfix

| Key | Mode | Action | Source |
|---|---|---|---|
| `<leader>tt` | `n` | Trouble diagnostics | `dot_config/nvim/lua/plugins/trouble.lua` |
| `<leader>tq` | `n` | Trouble quickfix | `dot_config/nvim/lua/plugins/trouble.lua` |
| `<leader>tr` | `n` | Trouble references | `dot_config/nvim/lua/plugins/trouble.lua` |
| `<CR>` | Trouble | jump + close | `dot_config/nvim/lua/plugins/trouble.lua` |
| `]s` | quickfix | 次のサイン群トグル | `dot_config/nvim/lua/plugins/bqf.lua` |
| `[s` | quickfix | 前のサイン群トグル | `dot_config/nvim/lua/plugins/bqf.lua` |
| `gs` | quickfix | sign の visual mode トグル | `dot_config/nvim/lua/plugins/bqf.lua` |
| `gS` | quickfix | sign の buffer トグル | `dot_config/nvim/lua/plugins/bqf.lua` |
| `zS` | quickfix | sign 情報クリア | `dot_config/nvim/lua/plugins/bqf.lua` |

### 一時バッファ・特殊 UI

| Key | Mode | Action | Source |
|---|---|---|---|
| `<CR>` | LSP references float | 選択中 reference へジャンプ | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `q` | LSP references float | 閉じる | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `<Esc>` | LSP references float | 閉じる | `dot_config/nvim/lua/plugins/lspconfig.lua` |
| `j` | `n` (`ministarter`) | 次の項目へ | `dot_config/nvim/lua/plugins/mini.lua` |
| `k` | `n` (`ministarter`) | 前の項目へ | `dot_config/nvim/lua/plugins/mini.lua` |

### コメント・編集・変形

| Key | Mode | Action | Source |
|---|---|---|---|
| `<leader>cc` | `n` | 行コメント切替 | `dot_config/nvim/lua/plugins/comment.lua` |
| `<leader>cb` | `n` | ブロックコメント切替 | `dot_config/nvim/lua/plugins/comment.lua` |
| `<leader>c{motion}` | `n/o` | line comment operator | `dot_config/nvim/lua/plugins/comment.lua` |
| `<leader>b{motion}` | `n/o` | block comment operator | `dot_config/nvim/lua/plugins/comment.lua` |
| `<leader>s` | `n` | `TSJToggle` で split/join | `dot_config/nvim/lua/plugins/treesj.lua` |
| `<leader>aa` | `n/x` | `mini.align` 開始 | `dot_config/nvim/lua/plugins/mini.lua` |
| `<leader>aA` | `n/x` | `mini.align` プレビュー付き開始 | `dot_config/nvim/lua/plugins/mini.lua` |
| `<C-a>` | `n/x` | `dial.nvim` increment | `dot_config/nvim/lua/plugins/dial.lua` |
| `<C-x>` | `n/x` | `dial.nvim` decrement | `dot_config/nvim/lua/plugins/dial.lua` |

### AI・Codex

| Key | Mode | Action | Source |
|---|---|---|---|
| `<leader>ac` | `n` | Codex トグル | `dot_config/nvim/lua/plugins/codex.lua` |
| `<leader>af` | `n` | Codex にフォーカス | `dot_config/nvim/lua/plugins/codex.lua` |
| `<leader>as` | `v` | 選択範囲を Codex へ送る | `dot_config/nvim/lua/plugins/codex.lua` |
| `<leader>as` | `n` (`neo-tree`,`oil`) | 現在ファイルを Codex コンテキストへ追加 | `dot_config/nvim/lua/plugins/codex.lua` |

## Submode 一覧

### WINDOW submode

- 入り方: `<leader>w`
- 目的: ウィンドウ操作を一時的に集中して行う

| Key | Action |
|---|---|
| `h` | 左へ移動 |
| `j` | 下へ移動 |
| `k` | 上へ移動 |
| `l` | 右へ移動 |
| `s` | 水平分割 |
| `v` | 垂直分割 |
| `+` | 高さを増やす |
| `-` | 高さを減らす |
| `>` | 幅を増やす |
| `<` | 幅を減らす |
| `x` | ウィンドウを閉じる |
| `q` | submode を抜ける |

### LSP submode

- 入り方: `<leader>l`
- 目的: references / diagnostics / code action を一時モードで回す

| Key | Action |
|---|---|
| `r` | 次の reference |
| `R` | 前の reference |
| `d` | 次の diagnostic |
| `D` | 前の diagnostic |
| `a` | code actions を開く |
| `1`-`9` | code action を番号指定で適用 |
| `<CR>` | 現在の code action を適用 |
| `h` `j` `k` `l` | 通常移動 |
| `<Tab>` | 次バッファ |
| `<S-Tab>` | 前バッファ |
| `q` | submode を抜ける |

### DEBUG submode

- 入り方: `<leader>d`
- 目的: DAP 操作を一時モードで回す

| Key | Action |
|---|---|
| `c` | Continue / Start |
| `n` | Step over |
| `i` | Step into |
| `o` | Step out |
| `b` | Breakpoint 切替 |
| `B` | 条件付き breakpoint |
| `l` | Run last |
| `r` | REPL トグル |
| `t` | Terminate |
| `u` | DAP UI トグル |
| `h` `j` `k` `l` | 通常移動 |
| `<Tab>` | 次バッファ |
| `<S-Tab>` | 前バッファ |
| `q` | submode を抜ける |
| `<Esc>` | submode を抜ける |

## Operator 一覧

### 標準 Neovim operator

下記は設定追加ではなく、通常の Neovim として使える代表的 operator です。  
`{operator}{motion}` または `{operator}{text-object}` で使います。

| Operator | Meaning |
|---|---|
| `d` | delete |
| `c` | change |
| `y` | yank |
| `>` | indent |
| `<` | outdent |
| `=` | reindent / format |
| `!` | filter through shell command |
| `g~` | toggle case |
| `gu` | lowercase |
| `gU` | uppercase |
| `gq` | text format |
| `zf` | fold create |

### この設定で追加される operator / operator-like 操作

| Key | Type | Meaning | Notes |
|---|---|---|---|
| `<leader>c` | operator | line comment operator | 例: `<leader>ciw`, `<leader>cap` |
| `<leader>b` | operator | block comment operator | 例: `<leader>bi(` |
| `sa` | operator-like | surround を追加 | `mini.surround` 既定値 |
| `sd` | operator-like | surround を削除 | `mini.surround` 既定値 |
| `sr` | operator-like | surround を置換 | `mini.surround` 既定値 |
| `sf` | operator-like motion | surround を右方向に探す | `mini.surround` 既定値 |
| `sF` | operator-like motion | surround を左方向に探す | `mini.surround` 既定値 |
| `sh` | operator-like | surround をハイライト | `mini.surround` 既定値 |
| `s` | motion enhancer | Flash jump | `n/x/o` で operator と組み合わせ可 |
| `S` | motion enhancer | Flash Treesitter jump | `n/x/o` で operator と組み合わせ可 |
| `r` | operator-pending helper | Remote Flash | `o` のみ |
| `R` | operator/visual helper | Treesitter search | `o/x` |
| `<leader>s` | text transform | syntax node split/join | `.` repeat 対応 |

### `mini.surround` の suffix

| Key | Meaning |
|---|---|
| `l` | 直前候補を対象にする |
| `n` | 次候補を対象にする |

例:

- `sdn)` = 次の `)` surround を削除
- `srlf` = 直前の function-call surround を別 surround に置換

### `mini.surround` の surround identifier

| ID | Meaning |
|---|---|
| `(` `)` | 丸括弧 |
| `[` `]` | 角括弧 |
| `{` `}` | 波括弧 |
| `<` `>` | 山括弧 |
| `b` | bracket alias |
| `q` | quote alias |
| `?` | 対話入力 |
| `t` | HTML/XML tag |
| `f` | function call |
| その他 1 文字 | 同一文字で囲む |

## Text Object 一覧

### 標準 Neovim text object

| Text object | Meaning |
|---|---|
| `iw` / `aw` | inner / a word |
| `iW` / `aW` | inner / a WORD |
| `is` / `as` | inner / a sentence |
| `ip` / `ap` | inner / a paragraph |
| `i"` / `a"` | double quote |
| `i'` / `a'` | single quote |
| ``i` `` / ``a` `` | backtick quote |
| `i(` / `a(`, `i)` / `a)` | parentheses |
| `i[` / `a[`, `i]` / `a]` | brackets |
| `i{` / `a{`, `i}` / `a}` | braces |
| `i<` / `a<`, `i>` / `a>` | angle brackets |
| `it` / `at` | tag block |

### Treesitter 追加 text object

| Key | Meaning | Notes |
|---|---|---|
| `af` | function.outer | `x/o` で使用, `lookahead = true` |
| `if` | function.inner | `x/o` で使用 |
| `ac` | class.outer | `x/o` で使用 |
| `ic` | class.inner | `x/o` で使用 |
| `aa` | parameter.outer | `x/o` で使用 |
| `ia` | parameter.inner | `x/o` で使用 |

### Treesitter text object 移動

| Key | Meaning |
|---|---|
| `]m` | 次の function 開始 |
| `]M` | 次の function 終端 |
| `[m` | 前の function 開始 |
| `[M` | 前の function 終端 |
| `]]` | 次の class 開始 |
| `][` | 次の class 終端 |
| `[[` | 前の class 開始 |
| `[]` | 前の class 終端 |

### Text object と operator の組み合わせ例

- `daf` = function 全体を削除
- `cif` = function 内側を変更
- `yia` = 引数内側を yank
- `<leader>caf` = function 全体を行コメント化
- `saif)` = function 内側を `()` で囲む
- `gUac` = class 全体を大文字化

## 競合・上書きメモ

- `<leader>x` は `init.lua` と `barbar.lua` の両方で `BufferClose` に割り当てられている
- `<leader>ca` は `lspsaga.lua` と `lspconfig.lua` の両方で code action に割り当てられている
- `<leader>l` は `hlslens.lua` では `:noh`、`submode.lua` では LSP submode 入口に割り当てられている  
  実効上は後から定義された方が優先されるため、通常は LSP submode 入口として使う前提で読むのが安全

## 設定上の補足

- `Comment.nvim` は `ts_context_commentstring` と連携して filetype / Treesitter に応じた commentstring を使う
- `Treesj` は `dot_repeat = true`
- `Dial.nvim` の対象は decimal, hex, `%Y/%m/%d`, bool
- `Snacks` の smart picker は Git 管理下なら `git_files`、そうでなければ `files`
- `Oil` は `win_options.signcolumn = 'yes:2'`

## ソース一覧

- `dot_config/nvim/init.lua`
- `dot_config/nvim/lua/plugins/accelerated-jk.lua`
- `dot_config/nvim/lua/plugins/barbar.lua`
- `dot_config/nvim/lua/plugins/bqf.lua`
- `dot_config/nvim/lua/plugins/codex.lua`
- `dot_config/nvim/lua/plugins/comment.lua`
- `dot_config/nvim/lua/plugins/dial.lua`
- `dot_config/nvim/lua/plugins/edgemotion.lua`
- `dot_config/nvim/lua/plugins/flash.lua`
- `dot_config/nvim/lua/plugins/hlslens.lua`
- `dot_config/nvim/lua/plugins/lspconfig.lua`
- `dot_config/nvim/lua/plugins/lspsaga.lua`
- `dot_config/nvim/lua/plugins/mini.lua`
- `dot_config/nvim/lua/plugins/neo-tree.lua`
- `dot_config/nvim/lua/plugins/oil.lua`
- `dot_config/nvim/lua/plugins/snacks.lua`
- `dot_config/nvim/lua/plugins/submode.lua`
- `dot_config/nvim/lua/plugins/treesitter-textobjects.lua`
- `dot_config/nvim/lua/plugins/treesj.lua`
- `dot_config/nvim/lua/plugins/trouble.lua`
- `~/.local/share/nvim/lazy/mini.nvim/lua/mini/surround.lua`
