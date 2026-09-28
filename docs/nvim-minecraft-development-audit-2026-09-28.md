**Neovim / Minecraft MOD開発環境の調査結果 — 2026-09-28**

2026-09-29追記: 以下は修正前の調査記録。後続作業でNeovim設定を修正した。Tree-sitterのeager load、Javaの不正linter指定の削除、Kotlin lintの保存時限定・stdinファイル名指定、Java packageのセミコロン、Kotlinへの未保存Java同期、Masonの自動更新停止を適用。mcdev・kross本体は変更していない。

保存時のkrossビルドは停止し、必要時に `:KrossBuild` で実行する。通常の `gd` / `gr` / `K` はLSP・kross、MC固有の定義・参照・hoverはそれぞれ `<Space>md` / `<Space>mr` / `<Space>mh`。Overseer設定を修正し、`:OverseerRun` → `Gradle wrapper` で `classes` / `runClient` / `runServer` / `runData` 等のタスク名を入力して実行できるようにした。出力は `:OverseerToggle`、診断はquickfixで確認する。`KrossBuild` はJavaファイルを開く前でもコマンドでロードできる。

Kotlin parserは後続作業での再確認時点で対応版に更新済みだった。新しいNeovimプロセスで問題のhighlight queryが通ることを確認。起動済みプロセスへの設定の差し替えはしていないため、適用にはNeovimを再起動する。回帰確認は [tests/nvim_mc_config.lua](C:/Users/gummy/.local/share/chezmoi/tests/nvim_mc_config.lua) をリポジトリrootから `rtk proxy nvim --headless -u NONE -l tests/nvim_mc_config.lua` で実行する。

提示されたTree-sitterエラーはローカルで再現した。さらに、Java lintの設定誤り、ktlintのstdin整形の例外、保存時ビルドの取りこぼし、定義ジャンプの競合を確認した。複数の確定不具合と、Kotlin・Java・Gradle・MC専用機能の連携不足が重なっている。

本調査では設定・プラグイン・CEMのソースを変更していない。設定リポジトリへの追加はこのレポートだけ。調査時に存在した `init.lua` のKotlin向けCR除去処理、`conform.lua` のKotlin formatter削除、およびCEMの未コミット変更を保持している。以下の修正案・新規プラグイン案は未実装。

**調査対象と確度。** 有効な設定は [chezmoi内のNeovim設定](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/init.lua)。`AppData/Local/nvim` のジャンクションがここを指す。対象プロジェクトは [CreateEnchantableMachinery](C:/Users/gummy/IdeaProjects/CreateEnchantableMachinery/build.gradle.kts)、ブランチは `mc1.21.1/neoforge/dev`。1.20.1の別ブランチでの起動・ビルド試験は行っていない。

| 対象 | 確認した状態 |
|---|---|
| Neovim | 0.12.5、Windows、LuaJIT |
| プラグイン | lazy-lock.jsonに111件。調べた主要プラグインのHEADはlockと一致 |
| Lua構文 | 設定の138ファイルをloadfileで検査、構文エラーなし |
| CEM | MC 1.21.1 / NeoForge 21.1.248 / Create 6.0.10-280 |
| ビルド | Kotlin 2.4.0 / Gradle wrapper 9.6.1 / ModDevGradle 2.0.142 / Java toolchain 21 |
| LSP・整形 | JDTLS 1.60.0 / Kotlin LSP 263.4702.0 / ktlint 1.8.0 / google-java-format 1.35.0 |
| 主なソース | main配下にKotlin 93、Java 25、JSON 43、NBT 11ファイル |

「再現」は隔離したheadless Neovimや外部ツールで実際に結果を得たもの。「実装確認」は現在のコードから処理経路を確認したもの。「要実機計測」は発生条件・体感への寄与が未確定のもの。実行中エディタへの読み取りRPCは応答を得られなかったため、現在のクライアント接続・マッピング・補完p95を取得できていない。実プロジェクトのGradle再ビルド、ゲーム起動、DAP接続も今回は実行していない。

**最優先で直す箇所は次のとおり。**

| 優先 | 問題 | 確度 | 主な影響 |
|---|---|---|---|
| 1 | Kotlin Tree-sitter parserとqueryの不一致 | 同じ391行目のエラーを再現 | quickfixプレビュー等でLua例外 |
| 1 | Javaに存在しない `checklint` を指定 | 例外を再現 | 保存・InsertLeaveでエラー |
| 1 | ktlint 1.8.0のstdin formatが `%` を書式として処理 | CEMの実ファイルで3/3回例外 | Kotlin整形失敗。現在の設定では削除済み |
| 1 | 新規Javaファイルのpackageに `;` が付かない | バッファで再現 | 作った直後からJava構文エラー |
| 2 | krossが実行中に来たビルド要求を捨てる | ジョブをstub化して再現 | 最新Kotlinの変更がJava解析へ反映されない可能性 |
| 2 | InsertLeaveごとにktlint、保存ごとにGradle classes | 実装確認・lintを計測 | 小さな編集でも高コスト処理を繰り返す |
| 2 | mcdevとkrossが `gd` / `gr` を上書き | attach順序を隔離環境で再現 | Kotlinソースへの転送・参照フィルタを迂回 |
| 2 | mcdevの標準LSP要求でbyte列をUTF-16列として使用 | 13対7の不一致を再現 | 同じ行の手前に日本語があると位置がずれる |
| 3 | Gradle実行・デバッグ・資源検証の統合不足 | 設定・実装確認 | MC開発の反復作業が手動・不安定 |

**1. 提示エラーの直接原因はKotlinのparser/query不整合。**

現在のKotlin parserの記録は `93bfeee1555d2b1442d68c44b0afde2a3b069e46`、nvim-treesitterが要求するrevisionは `1852ea17b7f60fb3f9d84e0b1555d56b46b39fb1`。実際に読み込まれる `site/queries/kotlin/highlights.scm` をコンパイルすると、報告と同じ `Invalid node type "interpolation_expression_start"` が391行目で発生した。

21言語×5種類のqueryを照合し、例外になったのはKotlinのhighlights。存在しない種類のqueryはエラーに数えていない。Matlab・LaTeXにもrevisionの差はあったが、この検査ではqueryエラーにならなかった。

[treesitter.lua](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/treesitter.lua:27) は `BufReadPost` / `BufNewFile` で遅延ロードし、起動時に `treesitter.install(parsers)` を呼ぶ。現在のmainの `install()` は既にインストールされたparserを更新しない。`build = ":TSUpdate"` 自体はあるが、現物のKotlin parserとqueryは揃っていない。更新が完了しなかった経緯までは特定できていない。

通常のバッファでは `pcall(vim.treesitter.start, ...)` が失敗を飲み込む。一方、[bqfのプレビュー処理](C:/Users/gummy/AppData/Local/nvim-data/lazy/nvim-bqf/lua/bqf/preview/treesitter.lua:17) がhighlighterを生成する経路で例外が表に出る。したがってCursorMovedやbqfは発火箇所で、壊れている組合せはKotlinのparser/query。

修正時はparser/queryを同じ対応版に揃え、`TSUpdate kotlin` の完了・ログ・queryコンパイルまで確認する。必要なら強制再インストールし、既にロード済みのparserを使い続けないよう再起動する。mainの公式方針に合わせてeager loadにし、更新失敗を見えるようにする。[nvim-treesitter公式README](https://github.com/nvim-treesitter/nvim-treesitter)

**2. Java lintの指定はそのままでは必ず失敗する。**

[nvim-lint.lua:34](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/nvim-lint.lua:34) の `java = { "checklint" }` に対応するlinterはインストール済みnvim-lintにない。隔離呼び出しで `Linter with name 'checklint' not available` を再現した。保存とInsertLeaveがこの処理を呼ぶ。

Javaの意味解析はJDTLSに任せ、追加のスタイル検査が必要な場合だけCheckstyleを設定する。`checkstyle` への綴り変更だけでは完了しない。実行ファイル、ルールXML、プロジェクト側の方針も必要で、現在Checkstyleは未導入。

**3. ktlintは遅延とクラッシュを別々に持っている。**

Masonのktlint 1.8.0に、CEMの [EnchantableDrillRenderer.kt](C:/Users/gummy/IdeaProjects/CreateEnchantableMachinery/src/main/kotlin/io/github/cotrin8672/cem/content/block/drill/EnchantableDrillRenderer.kt:90) をstdinで渡した。lintは診断JSONを返すが、Conform相当の `--format --stdin --log-level=none` は3回とも `UnknownFormatConversionException: Conversion = ' '` で失敗した。

同ファイルには `(time * speed) % 360` がある。ktlint 1.8.0の該当実装は整形後のソース文字列を `PrintWriter.printf(formattedFileContent)` に渡しており、ソース内の `%` を書式指定として解釈してしまう。ローカルの例外スタックとも一致する。[ktlint 1.8.0の実装](https://github.com/ktlint/ktlint/blob/1.8.0/ktlint-cli/src/main/kotlin/com/pinterest/ktlint/cli/internal/KtlintCommandLine.kt#L555)

現在の [conform.lua](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/conform.lua:5) からKotlinのktlint指定を外した変更は既に存在する。今の設定はKotlinでLSP formatへfallbackするため、上の外部formatterを毎保存で使う状態とは区別する。ただしlint側にはktlintが残っている。復活させる場合は、修正版または動作確認済みの版で `%` を含むソースの回帰試験を通す必要がある。

| 外部処理 | 1回目 | 2回目 | 3回目 | 中央値 | 結果 |
|---|---:|---:|---:|---:|---|
| ktlint / 1行のKotlin | 1,415ms | 1,262ms | 1,297ms | **1,297ms** | スタイル診断 |
| ktlint / CEM renderer | 1,627ms | 1,459ms | 1,384ms | **1,459ms** | スタイル診断 |
| ktlint format / 同ファイル | 1,649ms | 1,733ms | 1,903ms | **1,733ms** | 全回例外 |
| google-java-format / CEM Java | 330ms | 71ms | 78ms | **78ms** | 全回成功 |

プロセス起動を含む連続3回の壁時計計測。元ファイルは書き換えていない。ktlint lintのexit 1はスタイル違反の検出であり、クラッシュ扱いではない。Java formatterはWindows native実行ファイルだった。入力・実装が違うので言語間の一般的な性能比較ではない。UIが1.46秒停止すると測ったわけでもなく、診断が戻るまでの外部処理時間を示している。

1行でも約1.3秒という結果から、起動など入力サイズに依存しない費用の寄与が大きいと推測できる。正確な内訳はJVM内をprofileしていない。モードを抜けるたびに全体を起動する運用を避け、保存時・明示実行・十分なidle後などに限定する価値が高い。

Kotlin formatterとlintの整形規約も統一する。現在はLSPによる整形とktlintの規約が混在し得る。CEMに `.editorconfig` は見当たらず、nvim-lintのktlint定義は `--stdin` で元ファイル名を渡していないため、将来のディレクトリ別EditorConfigも正しく解決できるか確認が必要。

**4. 保存後の処理は部分的に調停されているが、ビルドまで一貫していない。**

[lint coordinator](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/config/lint.lua:16) はConformの完了を待つ仕組みを持つ。既にあるこの処理は活用する。ただしInsertLeaveには変更有無の判定や言語ごとの実行方針がなく、その都度lintを呼ぶ。

[kross設定](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/kross.lua:5) の `plugin_auto_build = false` はJDTLS拡張自体の自動ビルドを止める設定。プロジェクトのKotlin保存監視は有効で、デフォルトの300ms debounce後に `gradlew.bat classes` を起動する。[krossの実装](C:/Users/gummy/AppData/Local/nvim-data/lazy/kross.nvim/lua/kross/init.lua:482)

実行中フラグが立っていると次の要求は即returnし、完了後の再実行予約がない。実ジョブを起動しないstub試験で、ビルド中に次の要求を送り、最初のジョブを完了させても起動回数は1のままだった。これは実装上の取りこぼしである。実際にどの保存内容が取り残されるかはGradleがそのファイルを読むタイミングにも依存する。

Conformの非同期整形が内容を変えると `vim.cmd.update()` で再保存される。lint側は `conform_applying_formatting` を考慮するがkross側は考慮しない。そのため整形前の保存でビルドが始まり、最終内容の保存要求がビルド中として捨てられる可能性がある。debounceでまとまる場合もあり、毎回二重ビルドすると断定はできない。

さらに [CEMのgradle.properties](C:/Users/gummy/IdeaProjects/CreateEnchantableMachinery/gradle.properties:1) は `org.gradle.daemon=false`、`-Xmx3G`。保存ごとのCLI実行でGradle JVM再起動の費用を払い得る。Tooling APIからのLSP importは別経路で、Gradle公式ではTooling APIはdaemonを利用するとされる。この設定だけを根拠に「全LSP importが毎回no-daemon」とは言えない。[Gradle Daemon公式説明](https://docs.gradle.org/current/userguide/gradle_daemon.html)

修正は、保存した版を記録し、ビルド中の変更があれば完了後に最新状態を1回処理する方式が必要。失敗ログを保持してquickfixへ出し、最終整形後の保存を基準に動かす。まず明示ビルドまたはidle時ビルドで体感を比較する。混在言語・生成物の依存を確かめず `classes` を `compileKotlin` に変えるのは避ける。

現在はmainのKotlin出力・ソースパスを固定的に扱っている。test、独自source set、複数moduleへ広げるならGradleのモデルから出力先を取得する必要がある。ビルド失敗時は終了コード通知しか出ず、エラー本文を確認しにくい点も改善対象。

**5. ジャンプの担当が3か所に分かれ、最後に登録した処理が勝つ。**

共通 [LspAttach](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/lsp.lua:79) が `gd` / `gr` を設定し、krossも後から設定し、さらに [jdtls.on_attach](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/jdtls.lua:59) がscheduleした `mcdev.attach.setup` が上書きする。現在のNeovimではLspAttachイベントの後にclientのon_attachが呼ばれる。

実際のモジュールを使ってこの順序を再現した結果は、`gd = Mcdev go to definition`、`gr = Mcdev find references`、`grr = kross Kotlin references` だった。mcdevは標準LSPへのfallbackで直接 `vim.lsp.buf_request` を呼ぶ。krossが置き換えた `vim.lsp.buf.definition/references` を通らないため、Kotlinソースへの転送・classfile参照の除外を迂回する。

設定上の競合は確定。実行中エディタの最終マップはRPCが取得できなかったため未確認。修正は、mcdev・kross・通常LSPを選ぶ入口を1つにし、Java→Kotlin、Kotlin→Java、Mixin文字列→対象メソッドを同じキーで試験する。単に登録順だけを変更すると、別の経路の機能を失い得る。

**6. mcdevの標準LSP fallbackには日本語で位置がずれる不具合がある。**

[mcdev/lsp.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-nvim/lua/mcdev/lsp.lua:17) はNeovimのbyte列をそのまま `position.character` に入れる。また [attach.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-nvim/lua/mcdev/attach.lua:68) は標準LSPから返った位置にも `utf-8` を指定する。

`// 日本語 foo` の `foo` 直前はUTF-16では7だが、実装は13を送った。clientと交渉したoffset encodingで要求・結果を変換する必要がある。カスタムMC protocol側には変換処理があり、主な修正対象は標準LSPへつなぐ部分。日本語が別の行にあるだけで発生するわけではない。

**7. Kotlin中心のCEMに対して、MC専用機能の起動・対象範囲がJava中心。**

mc-dev-lspには既にMixin、MixinExtras、AW/AT、bytecode index、診断・補完・code action等が実装されている。この資産は有力。ただし [対象バッファ判定](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-nvim/lua/mcdev/buffer.lua:119) はJava・JSON・AW/ATを通し、Kotlin・JSONC・TOMLを通さない。Kotlinで実装されたバックエンドであることと、KotlinのMODソースを解析できることは別である。

JDTLSの起動条件もJava FileTypeだけ。Kotlinや資源だけを開いて作業し始めると、MC拡張の土台が起動しない。JSON/AW/ATから既存のworkspace JDTLSを利用する経路はあるが、そのworkspace serverを準備する契機が不足している。

Kotlin対応を足す際はfiletypeの許可だけでは足りない。Java ASTを前提とする解析を洗い出し、Kotlinの宣言、use-site annotation、companion/object、生成されるJVM名・descriptorを扱う意味解析が必要。Java専用解析へKotlin URIを投げない経路設計も必要。

**8. LSP間の連携とプロジェクト再同期に未解決事項がある。**

[lsp.log](C:/Users/gummy/AppData/Local/nvim-data/lsp.log) の9月28日分では、Kotlinのcancel対象requestが見つからない記録が115件、`.kt` がJDTの `ICompilationUnit` に解決できない記録が10件、`_java.reloadBundles.command not supported on client` が5件あった。これは該当文字列の一致件数で、ユーザー操作の失敗回数とは同一ではない。

cancelの記録はNeovimのrequest管理から出ており、完了済み要求をcancelする競合などが候補。これだけでKotlinサーバークラッシュとは判断できない。`.kt` がJDTLS側へ渡る経路とともに、request method・client・呼出元を短時間記録して特定すべき。標準エラーに出たJava起動メッセージまで全て障害として数えるべきではない。

[kotlin.lua](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/kotlin.lua:19) は `java_files=false`。現在のkotlin.nvimではJavaへのattachは「同一rootの未保存Java編集をKotlin解析へ同期する」ために実装され、Kotlinサーバー自体がJava言語機能を提供する前提ではない。この設定によりその同期を止めている。現行版で同一root限定の同期を検証し、Javaの補完・診断の担当はJDTLSのまま保つ構成を検討する。[インストール済み実装](C:/Users/gummy/AppData/Local/nvim-data/lazy/kotlin.nvim/lua/kotlin.lua:418)

また [Kotlinの自動再import](C:/Users/gummy/AppData/Local/nvim-data/lazy/kotlin.nvim/lua/kotlin/workspace.lua:10) の監視はbuild.gradle(.kts)、settings.gradle(.kts)、pom.xmlに限られ、`gradle/libs.versions.toml`、gradle.properties、wrapper propertiesを含まない。CEMの主要versionはcatalog管理なので、依存更新後に両LSPのモデルを揃える操作が必要。JDTLS側のworkspace Buildship設定にもauto.sync=falseがある。サーバー側が独自に追従する範囲もあるため、これは設定した再同期経路の不足として扱う。

ログにはKotlin起動23:10:26からimport成功23:10:53.726まで約27秒、内部Gradle処理約20秒、依存ソースの取得が記録されていた。これは依存解決を含む起動事例であり、補完が常に27秒かかるという意味ではない。cold import、cacheのある再起動、通常編集時の遅延を分けて測る必要がある。

Kotlin LSPは公式にAlphaとして提供され、DAPにも実験段階の機能がある。常に最新版へ揃えるだけで安定性が得られるとは限らず、CEMで検証した版と既知の制限を管理する。[Kotlin LSP公式](https://github.com/Kotlin/kotlin-lsp)、[リリースノート](https://github.com/Kotlin/kotlin-lsp/blob/main/RELEASES.md)

**9. JDK・daemon・索引の寿命が明示的に整理されていない。**

CEMのtargetはtoolchain 21で明示されている。一方、実際のJDTLSはmiseのOpenJDK 21、シェルのJAVA_HOMEはOracle 21、観測されたGradle daemonにはJBR 21とOracle 22が存在した。異なるJava homeやJVM引数はdaemon共有を妨げる。同一プロジェクトのビルド経路は揃える価値があるが、LSP起動JDKとMODのtarget JDKを無理に同一にする必要はない。

Kotlin LSPはbundled runtimeで動作し、`JAVA_HOME` は設定上symbol resolutionにも使われる。JDTLSについてもserver起動用JDKと解析対象runtimeは別に扱える。[nvim-jdtlsのJava runtime説明](https://github.com/mfussenegger/nvim-jdtls)

観測時のworking setはKotlin server約1.53GiB、JDTLS約0.9GiB、Gradle daemon各約0.65〜0.68GiB。複数の索引・JVMを維持する構成だが、これは一時点の使用量で、メモリ不足やCPU飽和の証拠ではない。累積CPU時間をCPU使用率として解釈していない。

JDTLS workspace名にroot hashを付けている点は適切。ただし保存先は `stdpath('cache')` で、このWindows環境ではTemp配下。索引の長期保持が必要なら安定したstate/data領域を検討する。Temp掃除が今回の原因だったという証拠はない。

**10. Overseerの設定が有効な場所に渡っていない。**

[overseer.lua](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/overseer.lua:4) は `opts={dap=true}` の外側にtemplates、components、component_aliasesを置いている。実際にsetupへ渡るoptsはdapだけで、意図したunique・quickfixの設定は反映されない。

加えてインストール済みOverseerの現行設定は `template_dirs` / `disable_template_modules` 方式。古い `templates` を単にoptsへ移すだけでは解決しない。[現在の設定定義](C:/Users/gummy/AppData/Local/nvim-data/lazy/overseer.nvim/lua/overseer/config.lua:110)

組み込みにGradle templateはなく、CEM向けuser templateやVS Code tasksも確認できなかった。既存のOverseerにclient/server/data/compile/GameTestのタスク定義とエラーパーサーを足せば、ターミナルを手で管理する作業を減らせる。Gradle pluginに合わせて実在するタスクを使い、Forge用のIDE生成タスク名をNeoForgeへそのまま当てはめない。

**11. デバッガの土台はあるが、NeoForgeの起動と結びついていない。**

nvim-dap、dap-ui、virtual-textは導入済み。独自dap設定はMATLAB中心で、JDTLS用java-debug/java-test bundleは未設定。ただし現在のkotlin.nvimはJava/Kotlin向けのDAP設定と `KotlinDebug [port]` を実装している。「Java/Kotlinを一切デバッグできない」状態ではない。[既存のKotlin DAP実装](C:/Users/gummy/AppData/Local/nvim-data/lazy/kotlin.nvim/lua/kotlin/dap.lua:529)

不足するのは、NeoForgeの正しいrun classpath・引数で起動し、JDWP待機を検出してattachし、停止時に関連プロセスを整理する一連の流れ。KotlinのSMAP、MC/Parchmentソース、Mixin適用後の実行位置も検証対象になる。まず既存DAPのCEMでの適合性を試し、不足が明確ならJava debug adapterを追加する。

CEMにはclient/server/data runがあり、client/serverでGameTest namespaceを指定しているが、専用gameTestServer runはない。ModDevGradleはgameTestServer種別を提供するので、自動テスト用runを設けられる。実際のテスト登録・終了条件を含めて確認する。[ModDevGradleのruns](https://github.com/neoforged/ModDevGradle#runs)、[NeoForge 1.21.1 GameTest](https://docs.neoforged.net/docs/1.21.1/misc/gametest/)

**12. リソース編集はMCバージョンと意味情報への対応が不足。**

jsonlsにSchemaStoreを渡しており、lang、pack.mcmeta、tags等のMC schemaは既に存在する。しかしインストール済みcatalogのLoot Table fileMatchは `data/*/loot_tables/**/*.json`。CEM 1.21.1の実ファイルは `data/.../loot_table/blocks/...` なので一致しない。同様にrecipe/advancement等の単複・バージョン差を考慮した割当が必要。[jsonls設定](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/plugins/lsp.lua:185)

構文schemaだけではregistry IDの存在、依存MODのresource、Create固有recipe、generated resourceの生成元まで解決できない。blockstates/models、NeoForge mods.toml、Mixin JSONもMC・loaderの版に応じた検査を整える必要がある。TOML自体にはtaploが設定されているが、NeoForge固有の意味検査とは異なる。

| ファイル | 現状のfiletype判定 | 評価 |
|---|---|---|
| pack.mcmeta / mixins.json | json | 基本設定あり |
| neoforge.mods.toml | toml | 基本設定あり。NeoForge固有検証は別途 |
| accesstransformer.cfg | cfg | mcdevは名前から判定できる。専用表示を整える余地 |
| .accesswidener | 未検出 | mcdevの独自判定はあるが標準filetypeがない |
| build.gradle.kts | kotlin | Kotlin LSPの対象 |
| build.gradle | groovy | この設定ではGroovy専用LSP/parserなし |
| .mcfunction | 未検出 | 編集支援未整備 |
| .nbt | **numbat** | Minecraftのbinary NBTと拡張子が衝突 |

CEMにはPonder用のNBTが11個ある。NBTを通常テキストとして開く経路を避け、型・圧縮を保持するviewer/editorと構造diffを用意する意義がある。生成済みJSONについては、生成元のKotlin/Javaへ案内する機能も必要。

**13. 新規Javaテンプレートが壊れている。**

[java_kotlin_package.lua:48](C:/Users/gummy/.local/share/chezmoi/dot_config/nvim/lua/shared/java_kotlin_package.lua:48) がJava/Kotlin共通で `package example` を挿入する。Javaに必要なセミコロンがない。空の仮想Javaバッファを `src/main/java/example/Audit.java` として作り、同じ結果を確認した。Javaの場合だけ `;` を付ける修正でよい。

package推測もmain/testの固定パスに依存する。CEMの通常ソースでは使えるが、将来の複数module・独自source setではGradleモデルからsource rootを得る方が確実。

**14. 更新後の組合せを検証する仕組みが不足。**

lazy-lock.jsonはあり、調べた主要プラグインはlockのcommitと一致していた。ただしparser binary、Masonのサーバー・formatter、ビルドしたJDTLS extension JARは別管理。現在のmcdevはversion順で最新のJARを選び、0.7.7を使う構成。古いJARも残っている。jarが古いという証拠はなく、Lua commitとJARの対応を確認する情報が不足しているという指摘。

Mason tool installerにはauto_updateがあるが、コマンドで遅延ロードするため「毎起動で必ず更新される」とは言えない。一方、初期セットアップ時もensure_installedが起動しない経路がある。初期導入・更新・rollbackを明示し、Neovim、Lua plugins、parser revision、Mason packages、extension JARを一組としてhealth checkするのがよい。

Snacksのprofilerやbigfile対応は既にある。111プラグインという数だけで遅さの原因とは断定しない。アニメーション・装飾・診断描画の寄与は、同じ操作で無効化したA/B計測をしてから判断する。privateな `vim._core.ui2` の使用もNeovim更新時の互換性検査対象になる。

**修正の実施順。**

| 段階 | 実施する内容 | 完了を判定する試験 |
|---|---|---|
| A: 操作時の例外をなくす | Kotlin parser/query整合、checklint除去または正規設定、ktlint formatterの版確認、Java package修正 | Kotlin quickfix移動、Java保存・InsertLeave、新規Java作成、`%` 入りKotlinの整形 |
| B: 保存と解析を整える | ktlint頻度、format→最終保存→lint/buildの順序、ビルド要求の保持、ログ収集、gd/gr統合、文字位置変換 | 連続保存・ビルド中保存・日本語行・Java/Kotlin相互参照・失敗時quickfix |
| C: MC開発の反復操作を整える | Gradle再同期、JDK選択、Overseerタスク、NeoForge DAP、資源schema、NBT/filetype | client/server/data/GameTest、breakpoint、version catalog変更、欠落resourceの検出 |
| D: 更新を検証可能にする | 各実体の版とhealth snapshot、再現用fixture、性能記録 | 更新前後で同じfixtureを走らせ、失敗した組合せを採用しない |

修正後の速度評価では、UIの応答、補完候補の初回表示と最終表示、定義ジャンプ、意味診断、スタイルlint、ビルド、cold importを分ける。例としてwarm補完100〜200ms、定義ジャンプ200ms程度を目標に置けるが、これは今の測定値や保証ではない。同じCEM操作を十分な回数測り、中央値とp95、cache有無、編集中のファイル数を記録して目標を調整する。

**作成・拡張を提案するプラグイン。** 以下は新規設計案で、まだ使える製品名ではない。現在のmc-dev-lsp、kross、Overseer、DAPで解ける部分を基盤とし、MC固有の不足へ開発を集中する。規模は相対的な実装難度で、費用上限による絞り込みではない。

| 案 | CEMで得られる体験 | 基盤・規模 | 優先 |
|---|---|---|---|
| MC開発環境Doctor | 何が壊れていて何秒待っているか1画面で分かる | 既存health/profilerを統合、中 | 最初 |
| NeoForge workspace/run統合 | client/server/data/test/debugを同じ場所から操作 | Overseer・DAP＋Gradle model export、中〜大 | 高 |
| krossの連携強化 | 最新のJava/Kotlin変更で相互ジャンプ・参照・診断 | 既存kross＋Kotlin/JDTLS、大 | 高 |
| MC resource/registry graph | IDからコード・JSON・texture・生成元へ移動 | mcdev-coreの拡張、大 | 高 |
| Mixin Lens | 注入位置・ordinal・適用結果を可視化 | 既存mc-dev-lsp＋bytecode解析、大 | 高 |
| 開発用runtime bridge | 実行中のBlockEntityやItemStackをNeovimから検査 | 開発用MOD＋エディタ、非常に大 | 中〜高 |
| Create/Ponder workbench | NBT構造とPonderシーンをコードと往復 | NBT/3D preview＋runtime、大〜非常に大 | CEMでは高 |
| バージョン移行・検証matrix | 1.20.1/1.21.1の差をコンパイルと資源検証で追う | Gradle・compiler・mapping、大 | 中 |
| IntelliJ解析基盤とのbridge | IDEAの意味解析・refactorをNeovimで使う | IDEA側plugin＋LSP/RPC、非常に大 | 長期の有力案 |

**案A: MC開発環境Doctor。** `McdevHealth`、kotlin.nvim health、Snacks profilerに情報を足す。parser/queryの実コンパイル、各bufferの言語機能の担当、JDK・toolchain・Gradle・JARの版、source set、資源schemaを一覧にする。保存1回をformat/lint/build/import/diagnosticに分解してtimelineに出す。要求のcancel・timeout・古い結果の破棄も数える。「Kotlin parserが古い」「Java linter名が無効」「Gradleが実行中」「Java解析がKotlin出力の更新待ち」を区別できることが価値。更新やcache削除を自動で繰り返す仕組みにはしない。

**案B: NeoForge workspace/run統合。** Gradle Tooling APIまたは小さなmodel export pluginから、MC/loader/version、source set、JDK、依存ソース、run引数、生成資源を取得する。build.gradleを正規表現だけで推測しない。wrapper/catalog/build設定の変更でモデルを無効化し、2つのLSPへ同期する。最初の実装はOverseerのCEM向けtemplateとログparserで足り、複数プロジェクトへの展開時にmodel exportを加える。

例えば `McRun client`、`McDebug client`、`McData`、`McTest` を入口にし、ビルド失敗はquickfix、ゲーム起動後は最新ログ、debug時はJDWP待機後にattachする。データ生成後は生成diffと変更元へ移動する。client専用クラスをdedicated serverへ混ぜた事故もserver runで確認する。ModDevGradleはrunをGradleモデルで保持しており、ここを正として使う。[公式ModDevGradle](https://github.com/neoforged/ModDevGradle)

**案C: krossの連携強化。** まずglobal関数の差し替えとキーの取り合いを解消し、単一のnavigation入口を設ける。Java/Kotlinのbuffer version、最終ビルド成功版、class出力の世代を結び、古い出力を使っている場合は明示する。ビルド中の保存は最新状態を1回再実行し、失敗した出力を最新とみなさない。source set・module単位に扱う。

さらに進めるなら、同名メソッドを文字列検索だけで選ばず、JVM descriptor、Kotlin metadata、source mapを使って、overload・extension・companion・synthetic methodを解決する。相互renameとsafe deleteは両言語にまたがる参照を列挙し、preview付きの一括編集とする。これは単なるLSPキー設定を超える開発になる。

**案D: MC resource/registry graph。** `cem:enchantable_drill` から登録コード、Block/BlockEntity、blockstate、model、texture、lang、loot table、recipe、tag、Ponder structureまで辿れるようにする。依存JARの資源とgenerated resourceも索引に含め、どのMOD・生成元が所有するかを表示する。

MC版に対応したschema/codecの検証とregistry照合を組み合わせ、存在しないID、欠けたtexture、循環model parent、競合するtag、誤ったresourceディレクトリを検出する。ID renameは変更候補をpreviewし、generated fileは生成コードの修正へ誘導する。最初のCEM向け成果物は1.21.1のloot_table、Create recipe、lang keyの横断ジャンプがよい。

**案E: Mixin Lens。** 既存のMixin補完・診断に、対象bytecodeと `@At` / ordinal / slice の位置表示を追加する。注入候補数、overload descriptor、mappingの対応、MixinExtrasの対象式をカーソルで確認できるようにする。実行時のMixin export/失敗ログを読み、静的予測と実際の変換結果を比較する。

「候補を補完できる」から「なぜここに刺さり、なぜ今回は刺さらないか説明できる」へ進める案。適用順序や他MODの変換は静的解析だけで確定しないため、runtime結果と区別して表示する。新しい汎用Mixin LSPを一から重複実装する必要はない。

**案F: 開発用runtime bridge。** 開発環境だけでロードする補助MODから、registry、tag、recipe、BlockEntity状態、ItemStackのcomponent/NBT、network payload、tick処理の情報を取得する。Neovimでコードを見ながら「狙っているブロックの状態」「このrecipeが見つからない理由」「client/serverで値が違う箇所」を検査できる。

資源reloadとコードHotSwapは別操作にする。通常のJVM HotSwapが許す変更範囲を判定し、クラス構造・登録・起動時処理の変更で必要ならrestartを案内する。任意の変更が無再起動で反映されるとは約束しない。接続はloopbackを基本とし、開発用MODを成果物へ混入させない。

**案G: Create/Ponder workbench。** 11個のNBT構造を、binary/gzip・tag型を保ったまま表示・差分比較する。3D previewとblock ID検索から、Ponder sceneのKotlinコードへ移動する。Ponderの時間軸をscrubし、どのscene命令が表示中の動作を生んだか示す。Createのstress/RPM・回転方向はruntime bridgeから可視化する。

画像・3Dは補助ウィンドウやブラウザを利用し、Neovimがコード・検索・操作の中心を担う。terminalだけに全てを押し込む必要はない。CEM固有の効果が大きく、汎用Java IDEでは薄い部分を強化できる。

**案H: バージョン移行・検証matrix。** プロジェクトrootごとにMC/loader/JDK/Gradleモデルとcacheを分離する。1.20.1系のJava 17と1.21.1のJava 21を扱いつつ、LSP自身の起動runtimeとは分ける。[Forge 1.20.1の開発要件](https://docs.minecraftforge.net/en/1.20.1/gettingstarted/)、[NeoForge 1.21.1の開発要件](https://docs.neoforged.net/docs/1.21.1/gettingstarted/)

API/mapping/resource formatの差を一覧にし、コンパイラの結果と対応付ける。resource directory、ItemStack component、Create API、Mixin target等を対象に、候補パッチを出してcompile・server起動・GameTestで検証する。未コミット作業のあるブランチを勝手に切り替える設計にはせず、独立workspaceを前提とする。

**案I: IntelliJ解析基盤とのbridge。** コストを度外視するなら有力な選択肢。Neovimを編集フロントエンドにし、IDEA側に独自pluginを置いて、Gradle project model、Java/Kotlin PSI、refactor、inspection、Minecraft Development pluginの機能をLSP/RPCで公開する。

狙いは、未保存文書の意味解析とJava/Kotlin横断refactorを一つの基盤で扱い、2サーバーのclass出力を接着する負担を減らすこと。IDEA用Minecraft DevelopmentはNeoForge等のMOD開発機能を持つが、現在のmc-dev-lspとは別製品である。[Minecraft Development公式](https://mcdev.io/)、[ソース](https://github.com/minecraft-dev/MinecraftDev)

これは既製の設定変更ではなく、IDEA側のread/write action、文書version、indexing状態、cancellation、VFS、編集適用、SDK互換性を扱う独立した開発プロジェクトになる。Kotlin LSPがIntelliJ由来だからといって任意のIDEA pluginをそのままロードできるとは限らない。Kotlin LSPには非公開部分もあるため、その配布物の改造を前提にせず、独自IDEA plugin方式の実現性を先に検証する。[Kotlin LSPの公開範囲](https://github.com/Kotlin/kotlin-lsp)

最初の実証はCEMで「未保存Java変更をKotlinから参照」「Kotlin/Java相互rename」「Mixin targetへ移動」を行うこと。その結果でbridgeへ寄せる範囲を決める。並行してMC resource graph・runtime bridgeを独立した機能として育てれば、解析基盤を変更しても再利用できる。

**検証記録。** 再現スクリプトと生の計測結果は一時ディレクトリに保存した。Temp配下なので恒久保管ではないが、今回の結論に必要な値・revision・失敗条件は本レポートへ転記している。

| 記録 | 内容 |
|---|---|
| [probe.lua](C:/Users/gummy/AppData/Local/Temp/nvim-mc-audit-20260928/probe.lua) / [結果](C:/Users/gummy/AppData/Local/Temp/nvim-mc-audit-20260928/probe.json) | parser/query照合、checklint例外 |
| [config_checks.lua](C:/Users/gummy/AppData/Local/Temp/nvim-mc-audit-20260928/config_checks.lua) / [結果](C:/Users/gummy/AppData/Local/Temp/nvim-mc-audit-20260928/config-checks.json) | Lua構文、Java package、filetype、MC対象判定、schema、Overseer、ビルド要求破棄 |
| [navigation_check.lua](C:/Users/gummy/AppData/Local/Temp/nvim-mc-audit-20260928/navigation_check.lua) / [結果](C:/Users/gummy/AppData/Local/Temp/nvim-mc-audit-20260928/navigation-check.json) | gd/gr/grrの登録順とUTF-16位置 |
| [benchmark.ps1](C:/Users/gummy/AppData/Local/Temp/nvim-mc-audit-20260928/benchmark.ps1) / [結果](C:/Users/gummy/AppData/Local/Temp/nvim-mc-audit-20260928/benchmark.json) | 外部lint/formatの起動込み3回計測、stdout/stderrは同じフォルダ |

主要な検査対象commitは nvim-treesitter `f603a2f`、nvim-jdtls `6e9d953`、nvim-bqf `c282a62`、kotlin.nvim `74119c9`、kross.nvim `41181b7`、mcdev-nvim `c3903f7`、conform.nvim `016802d`、overseer.nvim `a93d9f6`。結果はこの組合せと調査時の設定・Mason実体に対するもの。
