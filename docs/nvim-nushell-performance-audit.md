# Neovim / Nushell パフォーマンス監査

調査日: 2026-07-21  
環境: Windows, Neovim 0.12.2, Nushell 0.112.2

## 結論

Nushell の主要な待ち時間は起動ではなく、プロンプト復帰ごとの同期プロセスである。Neovim の主要な待ち時間は、起動直後の `VeryLazy` 一括ロード、ファイルタイプごとの初回ロード、`InsertEnter`・`LspAttach`・保存/InsertLeave に紐付く同期処理である。

本書の値は、特記しない限り当該PC上の読み取り専用調査で得た実測値である。単発値には「単発」と明記し、設定変更の優先順位を決めるためのスクリーニング値として扱う。

## Nushell

| 箇所 | 実測 | 影響 | 提案 |
|---|---:|---|---|
| `dot_config/nushell/mise.nu:10-11,55-58` | `mise hook-env -s nu` median 137.6ms, p95 148.7ms | `pre_prompt` と PWD変更で重複起動する | 同一PWDでの`mise use`即時反映を守るためhookは維持。上流側の高速化なしに削除しない |
| `dot_config/nushell/prompt.nu:58` | `git status --porcelain=v2 --branch` median 63.8ms | プロンプトごとに起動 | 表示が古くなるPWD/TTL cacheは使わず、stash取得と1プロセスへ統合 |
| `dot_config/nushell/prompt.nu:117` | `git stash list` median 86.7ms, p95 104.5ms | プロンプトごとに全stash列挙 | `git status --show-stash`へ統合し、stash表示は維持 |
| `PROMPT_COMMAND` 全体 | median 150.7ms, p95 165.6ms | Git repo内でプロンプト復帰を阻害 | 非repoでGit起動を避け、失敗コマンド後だけ更新 |
| `dot_config/nushell/config.nu:23-36` | 補完14本の無条件sourceは +58.8ms (515KB, 7,672行) | 起動コスト | git/uv/cargo/ghからオンデマンド化 |

通常のプロンプト復帰は mise と Git prompt の合計で約288ms median、`cd` 後は約426ms規模になる。zoxide PWD hook は median 0.435msであり優先度は低い。

## Neovim: イベント別計測

### 起動後の遅延ロード

空バッファで `User VeryLazy` を明示発火したところ、同期ロードは初回 **1,502.592ms**、続く2回は **192.894ms / 176.954ms**、ロード増分はいずれも **30プラグイン**だった。このイベントは起動時間から外れて見えるが、最初の画面表示後に操作不能感を作る。初回と後続の差はOS/bytecode/ファイルキャッシュの影響を示すため、以降はcold/warmを分けて10回ずつ測る。

同時にロードされた主なUI/編集系: `noice.nvim`, `lualine.nvim`, `dropbar.nvim`, `statuscol.nvim`, `satellite.nvim`, `tiny-inline-diagnostic.nvim`, `gitsigns.nvim`, `neoscroll.nvim`, `flash.nvim`, `mini.clue`, `mini.surround`, `mini.comment`, `mini.move`, `nvim-dap`, `nvim-dap-ui`, `toggleterm.nvim`, `overseer.nvim`, `denops.vim` 関連。

**改善方針:** `VeryLazy` を汎用イベントとして使わない。各プラグインを `CmdlineEnter`、対象キー、`LspAttach`、対象filetype、明示コマンドに移し、最初のidleへ一括移動しない。特にDAP、Overseer、Toggleterm、Git UI、検索拡張、視覚効果はキー/コマンド起動に戻す。

### ファイルタイプ初回ロード（command-ready、単発）

| ファイル種別 | 値 | 空バッファ111.0msとの差 | command-ready時のロード数 | 観測 |
|---|---:|---:|---:|---|
| 空バッファ | 111.0ms | - | 13 | 基準 |
| Nushell | 224.7ms | +113.7ms | 27 | TS系の共通装飾群 |
| JSON | 295.3ms | +184.4ms | 29 | jsonls / SchemaStore経路 |
| TOML | 299.9ms | +188.9ms | 28 | taplo経路 |
| Lua | 323.4ms | +212.4ms | 30 | lua_ls / lazydev経路 |
| Markdown | 333.0ms | +222.0ms | 29 | render-markdown経路 |
| Java | 364.2ms | +253.2ms | 32 | jdtls が blink を強制require |
| Kotlin | 586.4ms | +475.4ms | 29 | kotlin.nvimがOil/ Troubleを連鎖ロード |
| MATLAB | 668.8ms | +557.8ms | 27 | matlab_ls接続開始 |

この表は異なる実ファイルまたは未保存バッファを使ったスクリーニングで、ファイル内容・OSキャッシュの影響を含む。比較対象として有用だが、変更後は各行を反復測定して中央値へ更新する。

### 編集開始・LSP attach

* JSONバッファの `InsertEnter`: 同期 **86.006ms**、ロード増分7。
* Markdownバッファの `InsertEnter`: 同期 **103.966ms**、ロード増分8。
* Markdownの差分には `blink.cmp`、LuaSnip、autopairs、wise-backspace、mcdev、LaTeX補完が含まれる。
* Rustでは `rust_analyzer` attach後にロード数30。`fidget`, `neodim`, `tiny-code-action`, `inc-rename` がLspAttach連鎖に含まれる。
* TypeScriptのプローブではts_ls初期化がワークスペース内TypeScriptを見つけられずエラー終了した。対象ワークスペース外での値なので性能値には使わないが、プロジェクト外ファイルを開くUX上の失敗経路である。

### 描画ホットパス

Neovim APIで現在のtabline/statusline/statuscolumnを繰り返し評価した。レンダラ全体の時間ではないが、描画ごとに必ず発生するLua部分の下限として使える。

| 対象 | 実測 | 判定 |
|---|---:|---|
| Tabby tabline、バッファ1個、100回 | 67.989ms = 0.680ms/回 | 既に無視できない |
| Tabby tabline、バッファ51個、100回 | 296.735ms = 2.967ms/回 | 120Hzの8.33msフレーム予算の36% |
| statuscol、200行評価 | 2.063ms = 0.010ms/行 | 現時点ではTabbyより低優先 |
| lualine statusline、100回 | 0.245ms = 0.002ms/回 | キャッシュが効く通常状態では低優先 |

Tabbyは`tabby.lua:163-180`で全listed bufferを列挙し、各々で`isdirectory`、アイコン解決、highlight取得/生成をするため、バッファ数に比例する。この評価値は診断やGit状態を含む実表示時にはさらに変動する。最初にキャッシュ化またはtabline自体をmini.tabline等の軽量実装へ置換する。

Gitリポジトリ内の実ファイルでVeryLazyを発火すると、同期部分は251.330msで、gitsignsがバッファへattach完了するまで513.394msだった（後半は非同期）。起動直後の操作をブロックしない設計ではあるが、最初の表示直後にGit差分計算とsign redrawが重なる。gitsignsは`VeryLazy`一括群から外し、`BufReadPost`で開始するか、large repository / large fileではattachを遅延・無効化する。

## UXの性能予算（目標値）

これはハードウェア/プラグインに依存しない「守るべき上限」であり、計測値の合否を判定するための設計目標である。

| 操作 | 目標 | 絶対上限 | 適用 |
|---|---:|---:|---|
| キー入力から画面反映 | < 8ms | 16.67ms | 120Hz/60Hzでフレーム落ちを避ける。同期プロセスは禁止 |
| カーソル移動・スクロール | < 4ms | 8ms | TS/extmark/line number/tablineを含む |
| 通常ファイルのopenから編集可能 | < 100ms warm | 200ms | LSPの初期化は非同期。UIを待たせない |
| heavy language fileのopenから編集可能 | < 150ms warm | 300ms | Rust/Java/Kotlin/MATLAB。解析完了は後続でよい |
| InsertEnter / 最初の補完可能化 | < 16ms | 33ms | JSON 86ms、Markdown 104msは失格 |
| 補完候補の更新 | < 16ms | 50ms | sourceはキャンセル可能/非同期。documentationは遅延表示 |
| 保存の同期ブロック | < 50ms | 100ms | formatter/linterを同期で待たない。結果は後追い |
| バッファ切替 | < 16ms | 33ms | checktime、Git、LSP UI更新を同期で走らせない |
| 起動画面後の追加同期作業 | < 16ms | 50ms | VeryLazyの1,502ms/177msは失格 |
| プロンプト復帰 | < 10ms | 30ms | Nushellの288ms/426msは失格 |

## Neovim: 個別の改善候補

| 優先 | 箇所 | 根拠 | 改善案 |
|---|---|---|---|
| P0 | `plugins/*` の `event = "VeryLazy"` | 30プラグイン / 1,502.6ms同期ロード | イベントを分割し、キー/コマンド主体へ戻す |
| P0 | `plugins/kotlin.lua:3-8` | Kotlin初回586.4ms。OilとTroubleをdependencyとしてロード | 連携機能を維持したまま、上流が対応する場合だけ内部requireをオンデマンド化 |
| P0 | `plugins/jdtls.lua:28-30` | Java初回でblink/LuaSnip等を引き込む | capabilityを失わない静的生成経路へ移せるか検証。現状は完全なcapabilityを優先 |
| P0 | `config/matlab/lsp.lua:13-14` | MATLAB初回668.8ms、matlab_lsが開いた時点で接続 | 自動接続を維持し、接続処理を非同期化できる上流APIを検証 |
| P0 | `plugins/nvim-lint.lua:21-26` | InsertLeaveごとに外部lint | 表示タイミングを変えない範囲で同一changedtickの重複実行だけ抑止 |
| P0 | `plugins/luasnip.lua:8-9` | TextChangedIごとに更新 | eventは維持し、LuaSnip側の重複更新有無をprofileしてから最適化 |
| P1 | `init.lua:116-119` | `checktime`をBufEnter/WinEnter/FocusGainedで実行。ローカル100回3.221ms | 外部変更検知を維持するためイベントは残し、同一buffer/tickでの重複だけ抑止 |
| P1 | TS装飾群 | 全filetypeでTS、rainbow、context、hlchunk、mini.indentscope、hipatterns、cursorwordが重複 | 機能は維持し、共有parse/callbackの重複と再描画回数をprofileして削減 |
| P1 | `tiny-inline-diagnostic.lua:11-18` | cursorline全診断と複数行の表示 | 表示は維持し、診断未変更時の再計算・再描画を抑止できるか上流で検証 |
| P1 | `tabby.lua:163-180` | tabline描画ごとにバッファ全走査、ディレクトリ判定、icon/HL生成 | バッファアイコン/HLをキャッシュ |
| P1 | `shared/java_kotlin_package.lua:34-41` | Java/Kotlin初回Enterで全行取得し空行走査 | BufNewFile限定、既存ファイルで全走査しない |
| P2 | `plugins/obsidian.lua:5-14` | `event`が二重テーブルでLazy specとして不正な形 | proper event specへ修正。性能前に意図した遅延ロードを保証 |

### ファイルタイプ固有の追加所見

* Java: `plugins/jdtls.lua:28-30` はcapability取得のために `blink.cmp` を `pcall(require, ...)` する。Blink自体は`InsertEnter`指定だが、このrequireによりJavaを開いただけでBlink、LuaSnip、latex補完、mcdevまで初期ロードされる。補完を使う前のコストなので、最初に切るべき依存連鎖である。
* Kotlin: `plugins/kotlin.lua:4-8` がOilとTroubleをdependencyに置く。Kotlinプラグインの設定にそれらは不要なので、Kotlinを開くたびの初期化経路にUIプラグインを混ぜている。`jvm_args = { "-Xmx4g" }` とinlay hints有効も、Kotlin language server稼働時のメモリ/描画コストとして別途監視する。
* MATLAB: `config/matlab/lsp.lua:11-14` は `indexWorkspace=false` である一方、`matlabConnectionTiming="onStart"` とtelemetry有効である。プローブでは1.2秒以内にmatlab_ls attachを確認した。編集前に接続する必然性がないならonDemand化が安全な最適化点である。
* HTML/JSON/TOML: 各々html/jsonls/taploがバッファopen後にattachすることを確認した。LspAttachでfidget/neodim/tiny-code-action/inc-renameをさらに載せるため、軽い設定ファイルを開くだけでもLSP UI装飾の追加ロードが起きる。

### 補完・キー待機・描画ガード

* 現在のBlink設定は全filetypeで `snippets`, `lazydev`, `copilot`, `buffer`, `path`, `lsp`, `mcdev` をsourceとして列挙する。標準はLSP/path/snippet/bufferの4本なので、Lua/Minecraft/Copilot以外でも追加provider判定をしている。`mcdev`はJava関連、`lazydev`はLua、Copilotは有効時だけに絞る。
* `completion.documentation.auto_show=true` は候補選択時にTreesitterベースのdocumentation window描画を許可する。Blink自身の設定検証はdocumentationのupdate delayを50ms未満にすると「noticeable lag」と明示している。表示機能は維持し、既定delay未満へ短縮しない。
* Blinkの公開ベンチマークは1文字ごと0.5--4ms（async, single core）をうたう。この値をcompletion coreの理論目標とし、設定側の初回InsertEnter 86--104ms、追加source、documentation、ghost textを別予算で監視する。
* 実効設定は `timeoutlen=1000`, `ttimeoutlen=50`, `updatetime=4000`, `redrawtime=2000`。`timeoutlen`を明示していないため、曖昧な通常マッピングは最大1秒待機し得る。`mini.clue`は`g`、`[`, `]`, `<Leader>`を独自のkey-query triggerにし、既定window delayも1000msである。操作ガイドを残すならdelay 150--250ms、キー即応を最優先するならmini.clueの常時triggerを無効化する。
* `redrawtime=2000` は複雑なsyntax/hlsearch/async Treesitter parseに最大2秒を許す安全弁である。短縮するとhighlightが打ち切られるため維持する。large-bufferでも機能を切らず、上流のincremental parseと重複callback削減を優先する。

## 次の計測

1. 上記の各P0を一つずつ無効化したA/Bを各10回行い、中央値・p95・ロードプラグイン差分を記録する。
2. 代表プロジェクト（TypeScript、Rust、Java/Kotlin、MATLAB、Markdown vault）でLSP初期化、診断到着、補完1文字目、保存を別々に計測する。
3. GUI接続状態で `:profile` とフレーム描画を採取し、extmark/診断数とキー入力レイテンシを対応付ける。

## 2026-07-21 実装した対策と再計測

ここまでの表には「速度だけを最大化する候補」も含むが、最終実装では表示・補完・診断・lint・format・LSP・Git signなどの機能を減らす候補は採用していない。大容量ファイルでも同じ機能を維持する。

* `VeryLazy`一括群を、キー/コマンド/機能が必要になるイベントへ移動した。DAP/Overseer/Toggleterm/Flash/mini編集操作とNeoscrollは全対応モードの初回キーでロードし、そのキーをプラグインへ再送する。lualineはVimEnter、gitsigns/Dropbar/Satellite/tiny-inline-diagnosticはBufReadPost/BufNewFileでロードする。起動後の通知・command UI・空バッファのstatus columnを変えないため、Noice/statuscolはVeryLazyを維持する。
* 機能維持後のwarm測定ではVeryLazy同期ロードが **30プラグインから12プラグイン**、**176.954/192.894msから122.643/151.675ms**（各n=2）になった。機能を無効化した過渡的な8プラグイン/64.500ms値は最終結果として採用しない。
* Blink/LuaSnip/autopairs/wise-backspaceをBufReadPost/BufNewFileで準備し、最初の入力にロードを持ち込まない。Blinkのghost text、menu、documentation、source順序、全providerとJava capabilityは元の機能を維持する。最終設定でのJSON warm InsertEnterは **0.607ms、ロード増分0**（単発。直前の同条件値1.425ms/10.549ms）。
* KotlinのOil/Trouble依存、JavaのBlink capability、MATLABの自動起動/onStart接続、InsertLeave lint、TextChangedI snippet更新、500ms formatter待機は元のまま維持する。
* Treesitter、rainbow delimiters、mini.indentscope、mini.hipatterns、複数行diagnostic、untracked fileのgitsigns、undo animationはサイズやfiletypeによらず維持する。25,000行のLuaバッファでもTreesitter activeを確認した。
* Tabbyのアイコン・highlight解決結果だけをバッファ単位でキャッシュし、表示内容は変えずに再描画コストを削減した。
* Nushellのmise pre_prompt hookは、同一PWDでの`mise use`直後の環境反映を守るため維持した。Git promptは鮮度を落とすcacheを使わず、`git status --porcelain=v2 --branch --show-stash`一回でstatusとstash数を取得する。同一run各5回のmedianはstatus **394.231ms** + stash **322.636ms** 相当から統合 **299.274ms** となり、表示内容を保ったまま約 **417.6ms（58.3%）** 削減した（dirty worktreeでの補正計測）。

## 外部の基準・一次資料

* [Google RAIL performance model](https://web.dev/articles/rail): 60Hzの1フレームは16msで、アプリ処理の目安は10ms。入力への見える反応は100ms以内。
* [Neovim option reference](https://neovim.io/doc/user/options/): `redrawtime` はsyntax/hlsearch/async Tree-sitter parseを制限する安全弁で、現行既定値は2000ms。
* [blink.cmp](https://github.com/Saghen/blink.cmp): core completionの公称値は1文字ごと0.5--4ms async/single core。これは設定全体ではなくBlink coreの目標値として扱う。
* [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter): Tree-sitter highlightingはNeovim側の機能であり、設定はfiletypeごとにstartする。large-file無効化は高速化候補になるが、機能維持要件に反するため採用していない。
