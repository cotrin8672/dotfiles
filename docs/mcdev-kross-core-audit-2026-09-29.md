**mc-dev-lsp・kross本体の問題とMixin可視化の取り込み方 — 2026-09-29**

対象はインストール済みの mc-dev-lsp `c3903f753c9eb9313e1646c5f1c6900b4cffc7d5`、kross.nvim `41181b76ae2a9f5d1592345caeae4d3cb9fc6b06`。調査時の `git ls-remote origin HEAD` と一致した。本体のソース・JARは変更していない。

Neovimを別プロセスで起動し、実際のLuaモジュールを読み、LSP応答・ジョブ起動をstubに置き換えて確認した。実プロジェクトのGradleビルド、ゲーム起動、稼働中JDTLSへの操作は行っていない。Java側の監視についてはソースに加え、インストール済み `kross-jdtls-0.2.0.jar` の該当Jobを `javap` で照合した。実環境での遅延時間やclasspath汚染の発生回数は未計測。

**先に直す不具合。** 「再現」は隔離試験で該当する結果を得たもの。「実装確認」は問題の条件と処理経路を確認したもので、実プロジェクトでの発生確認とは区別する。

| ID・優先 | 対象 | 問題と影響 | 確度 | 修正の方向 |
|---|---|---|---|---|
| K1・高 | kross JVM | Kotlin出力の変更通知から、同じJDTLS workspace内の無関係なGradle/Maven projectにも、その出力をclasspathへ追加する。既存kross entryも削除するため、別projectの出力を置換し得る | ソース・配布JARの実装確認 | 出力の所有projectを特定し、初回登録と監視更新で同じ判定を使う。対象外projectのclasspathを変更しない |
| K2・高 | kross Lua | ビルド中に届いた保存・明示ビルド要求を捨て、終了後も再実行しない。新しいKotlin変更がJava解析に反映されない原因になる | 再現：2要求に対して完了後も起動1回 | rootごとに追加要求を保持し、終了後に最新状態を1回ビルドする。失敗した世代を成功扱いしない |
| M1・高 | mcdev Lua | 標準LSP要求の列をbyte数で送る一方、ジャンプ表示では位置をUTF-8固定で読む。カスタムMC応答もUTF-16のままなので表示側の不整合がある。code actionの明示rangeもbyte列のまま | 要求・表示を再現。rangeの経路は実装確認 | 標準LSPはclientごとのoffset encoding、MC protocolはUTF-16へ統一。要求・応答・選択範囲をそれぞれ変換する |
| M2・中 | mcdev Lua | 複数clientの定義・参照・hover応答を個別に処理する。成功した後でも別clientの空応答でMC fallbackを実行し、表示callbackが複数回走る | 再現：成功＋空応答でcallback 2回、不要なfallback 1回 | 全応答を集約して結果を1回返す。全clientで結果がない場合だけMC fallbackする |
| M3・中 | mcdev Lua | 標準code actionを混ぜる際に提供clientを失い、`codeAction/resolve` を実行しない。title・kindだけの重複除去で異なる候補も消える | 再現：dataだけのactionは選択後の要求・編集・コマンドがすべて0。異なる2候補が1候補になる | clientとactionを対応付けて保持し、必要なresolveを実行してから正しいclient/encodingで適用する。タイトルだけで同一視しない |
| K3・中 | kross JVM | 出力のWatchKey処理ごとにJobを追加し、classpath再設定とbuildSupport.refreshを行う。更新をまとめる処理や、同一classpathなら省略する判定がない | 実装確認。体感への寄与は未計測 | project単位で通知をまとめる。classpath構成変更とclass内容の更新を分け、不要な再設定を避ける |
| K4・中 | kross Lua | ビルド失敗時に終了コードしか表示せず、stdout/stderr本文を保存・提示しない | 実装確認 | 最後のビルドログを参照可能にし、コンパイルエラーをquickfixへ返す |

K1は特に優先する。初回登録には `outputPath.startsWith(projectPath)` の判定があるが、監視側のJobにはない。しかも `setClasspathEntry()` は既存の全kross entryを除いてから新しい出力を追加する。単一projectだけなら別projectへの影響は出ないが、同一workspace内に複数projectがある場合に問題になる。

設定の `watch = false` で停止したのはLuaの保存→Gradleビルド監視。`M.attach()` が出力をJDTLSへ登録するとJava側の `registerWatcher()` は動くため、K1/K3の回避にはなっていない。

M1の実測例は `// 日本語 foo`。`foo` 直前のUTF-16列は7、byte列は13。標準要求は13を送った。また、UTF-16列7の応答をUTF-8として表示すると実際のカーソルはbyte列6になり、正しいUTF-16指定では13になった。

前回追加した設定側のMC専用ジャンプにもUTF-8指定を入れてしまっていた。この2か所は今回UTF-16へ訂正し、ジャンプの実カーソル位置とquickfixの実列を回帰確認した。mcdev本体の標準LSP併用処理・code action処理は未修正。

**連携設計の不足。** 次は単発のクラッシュ修正とは分けて扱う。

| ID | 対象 | 現状の限界 | 必要になる変更 |
|---|---|---|---|
| D1 | mcdev | KotlinソースはMC補完・診断の対象外。主な意味解析もJavaを前提としている | Kotlinの宣言・annotation・生成JVM名/descriptorに対応する。filetype追加だけでは解決しない |
| D2 | mcdev / 起動連携 | 現設定はJavaを開いたときにJDTLSが起動する。Kotlinや資源だけから開始するとMC拡張の接続先が準備されない | workspaceでMC機能を要求したときに接続先を確保する。Java以外を無理にJDTのJava解析へ流さない |
| D3 | kross | `build/classes/kotlin/main` と `src/main/kotlin` 固定。test・独自source set・複数module・別出力先を正しく扱えない | Gradle/JDT project modelから出力とソースの対応を取得する |
| D4 | kross | 定義が取れない場合、全managed rootのKotlinソースを同期読み込みし、単語名が最初に一致した宣言へ飛ぶ。呼出元root、owner、descriptorを使わない。class出力から転送する経路はソース先頭へ飛ぶ | まず対象rootとownerを限定する。メンバーの正確な位置は言語サーバー、JVM metadata、source map等で解決する。曖昧な候補を断定しない |
| D5 | mcdev / kross | krossが `vim.lsp.buf.definition/references` をglobalに置換し、両プラグインが既定でキーを登録する。mcdevの直接 `buf_request` はkrossの変換を通らない | 明示的な公開ナビゲーション関数と任意のキー登録を提供し、呼出側が合成できるようにする |

D4にはoverload・同名メンバー・複数workspaceで誤転送する余地がある。毎回のディスク走査も遅延の候補だが、今回その所要時間は計測していない。D5のキー競合は現在の設定で通常LSP/krossとMC専用キーを分けて回避済み。

**追加で確認する項目。** これらを現時点でCEMの症状の確定原因として扱わない。

- krossのJava監視はWatchKeyの失効後の復旧、終了時の監視資源解放、監視スレッド失敗後の再登録を扱っていない。`clean` による出力ディレクトリ削除・再生成で更新を追えるかを検証する。初期登録済み集合が失敗後も残る点に注意する。
- krossの拡張JAR自動ビルドは同期wait。現設定では `plugin_auto_build = false` なので回避済み。複数JARがあるとglobの先頭を選ぶが、現在存在するJARは1個なので古いJARが選ばれているとは断定しない。
- 既存ログのKotlin cancel警告、`.kt` をJDTの `ICompilationUnit` に解決できない記録、bundle reload未対応は発生元を未確定。method・client・URI・要求の寿命を記録してから所有プロジェクトへ振り分ける。
- 補完・診断の遅さは追加計測が必要。mcdevには既に診断のdebounce、実行中要求の集約、古い文書版の結果破棄、cache、health/debugがある。「すべて未実装」として作り直さない。
- version catalog変更時の再import不足にはkotlin.nvimやJDTLS設定も関係する。mcdev/krossだけの不具合と断定しない。

**Mixin Visualizer相当の機能はmc-dev-lspへ組み込める。** 現在の構成には、editor非依存の `mcdev-core`、project/classpathを扱うJDTLS拡張、protocol DTO、表示担当のLuaがある。

再利用できる実装は `BytecodeIndexService`、`BytecodeIndexAdapter`、`InjectionPointOccurrenceResolver`、MixinExtrasの式解析など。命令位置・ordinal・shiftを扱う部品は既にある。ただし汎用のslice範囲計算・描画や、適用前後のclass表示は追加が必要。既存のslice補完があることと、任意のslice条件を適用した可視化が完成していることは区別する。

| 部分 | 取り込み先 | 役割 |
|---|---|---|
| 注入候補・選択理由 | mcdev-core | `@At`、ordinal、slice、shiftでどの命令が選ばれたか計算し、未対応条件も明示 |
| 対象class・出力の取得 | mcdev-jdtls-extension | 既存project/classpath/mapping情報から入力を取得し、ビルド済み出力の状態を確認 |
| 応答 | mcdev-protocol | 可視化用コマンドとDTOを追加し、表示テキスト・位置・説明を返す |
| 表示 | mcdev-nvim | scratch buffer、Neovim標準diff、extmark、対象へのジャンプを提供 |

[Mixin Visualizerの処理本体](https://github.com/Weever1337/mixin-visualizer/blob/master/src/main/kotlin/dev/wvr/mixinvisualizer/logic/MixinProcessor.kt) はIntelliJのJava PSIで対象とビルド済みclassを探し、[独自ASM変換器](https://github.com/Weever1337/mixin-visualizer/blob/master/src/main/kotlin/dev/wvr/mixinvisualizer/logic/MixinTransformer.kt) へ渡してから逆コンパイルする。これらをmcdevのclasspath取得とNeovimの表示に置き換える形が考えられる。IDEA pluginをJDTLSへそのままロードする構成にはしない。

[LICENSE](https://github.com/Weever1337/mixin-visualizer/blob/master/LICENSE) はMITで、著作権表示・許諾表示を保持した移植が可能。配布に含める依存ライブラリは別途それぞれの条件を確認する。今回はコードをコピーしていない。

実装順は次がよい。

1. 既存の解析結果から注入位置・候補数・選択理由を表示する。bytecode表示は既存ASMを使える。重い処理はまず明示コマンドで実行する。
2. Mixin標準の `mixin.debug.export` で出た `.mixin.out` を読み、その起動でのMixin適用後classを比較する。失敗時の入力class取得には `mixin.dumpTargetOnFailure` がある。[Mixin公式説明](https://github.com/SpongePowered/Mixin/wiki/Mixin-Java-System-Properties)
3. 起動前に適用後の予測も見たい場合に、VisualizerのASM処理を移植・拡張する。部分的な模擬変換なので、未対応annotationや変換失敗を成功扱いせず、静的予測と実行時exportを区別する。

Visualizerの入口も `PsiJavaFile` に限定されるため、移植だけでKotlinソース対応は得られない。また独自ASM変換器の結果を、MixinExtras・他MOD・適用順序まで含むゲーム実行結果と同一視できない。現在のcore側には既にMixinExtras解析があるため、可視化UIのために別の解析系を重複して作る必要はない。

**修正・検証の順序。** K1/K2とM1を先に直し、M2/M3を続ける。K3は更新回数と所要時間を計測して修正効果を確認する。その後、CEMの開発範囲に合わせてD1/D3/D4を進め、Mixin可視化は既存解析を使って追加する。

修正の合格条件は、複数projectの出力が互いに混ざらないこと、ビルド中の連続保存が最後の内容まで処理されること、日本語・絵文字の前後でも位置と編集範囲が一致すること、複数clientの応答順を変えてもナビゲーションが1回だけ確定すること、resolveを要するcode actionが正しいclientで実行されること。

**根拠となるローカルソース。**

- K1/K3: [SetKotlinBuildOutputCommandHandler.java](C:/Users/gummy/AppData/Local/nvim-data/lazy/kross.nvim/src/main/java/io/github/cotrin8672/kross/jdtls/SetKotlinBuildOutputCommandHandler.java:123)。初回の対象判定は74行、既存entryの除去は104行、監視Jobの全project更新は147行。
- K2/K4: [kross/init.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/kross.nvim/lua/kross/init.lua:474)。実行中のreturnは482行、終了処理は495行。
- D3/D4/D5: [kross/init.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/kross.nvim/lua/kross/init.lua:36)。単語検索は110行、global置換は370行と413行。
- M1/M2/M3: [mcdev/lsp.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-nvim/lua/mcdev/lsp.lua:17)、[attach.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-nvim/lua/mcdev/attach.lua:9)、[code_action.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-nvim/lua/mcdev/code_action.lua:25)。応答をbyte列へ変換せず保持する処理は [convert.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-nvim/lua/mcdev/convert.lua:23)。
- D1: [buffer.lua](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-nvim/lua/mcdev/buffer.lua:119)。
- 可視化の再利用先: [InjectionPointOccurrenceResolver.kt](C:/Users/gummy/AppData/Local/nvim-data/lazy/mcdev-nvim/mcdev-core/src/main/kotlin/io/github/mcdev/core/mixinextras/InjectionPointOccurrenceResolver.kt:17)。

今回の隔離再現は [probe.lua](C:/Users/gummy/AppData/Local/Temp/nvim-mc-core-audit-20260929/probe.lua)、[結果JSON](C:/Users/gummy/AppData/Local/Temp/nvim-mc-core-audit-20260929/results.json)。Temp配下なので恒久保管ではない。主要な入力・結果は上記へ転記済み。設定側の回帰確認は [tests/nvim_mc_config.lua](C:/Users/gummy/.local/share/chezmoi/tests/nvim_mc_config.lua) に追加した。
