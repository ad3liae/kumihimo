# Task 058: 組紐台（丸台・角台）を選べるようにし、詳細をシートで開く

- 状態: **実装済み・PR #42 でマージ**（2026-09-24、Claude Code。枝 `claude/task-058-stand-and-detail`。作者が PR の作成とマージを許可した。見え方の受領ではない）。結果は末尾。**作者の見え方の確認は無い**。
  指示書は **worker へそのまま渡す。承認待ちの段は挟まない**（042 以降の型）
- 前提（先に読むこと）: **`docs/specifications/project-editor.md`**（「組紐台」「詳細」の節と受け入れ条件。
  審査側がこの指示書と同時に書き直した）、`docs/specifications/home-screen.md`（行に台を足した）、`AGENTS.md`
- 基準: 最新の main（Task 057 の PR #41、`0d38578` 以降）
- **製品コード（画面とデータ）に触れる。** PR の前に全件を1回通すこと

## 0. 作者の決定（2026-09-24）

「UI改善に移りたい」。

1. **丸台か角台かを選べるようにする。** 角台の組み方はまだ無いが、選べるようにしておく。リストボックス
   （＝メニューの `Picker`）。**保存済みの作品にも台を持たせ、一覧には「丸台」「角台」の文字で出す。**
2. **詳細はモーダルで開く。** iPhone 縦も iPad 横も。iPad 横では全画面を置き換えず、画面中央にウィンドウとして
   現れる形。いまは iPad 横で戻り方が分かりにくい。
3. **詳細のタイトルは組み方の名称、右上はテキストの「閉じる」。** 閉じるボタンは今のまま（文字列
   `ProjectEditorStrings.dismiss`、閉じる以外の動きを持たせない）。
4. **3Dと模様図を切り替えるセグメントは廃止し、3Dの下に模様図を置く。** 縦画面でも iPad 横でも、詳細は
   上下に2つ並ぶ。

（作者は模様図を「展開図」と呼んだ。いまセグメントの「模様図」側に出ているもの——`BraidPatternForRecipe`——の
ことである。一覧カードの展開図のサムネイルではない。）

## 1. いまの作り（審査側が読んだ）

- `ProjectEditorView` は、コンパクト幅では結果のタップで `fullScreenCover`（`compactPreviewPreset`）、
  十分な幅では右列を詳細へ置き換える（`previewPreset`、`isEmbedded: true`）。幅が変わると `onChange(of: layout)` で
  両者を移し替えている。**iPad 横で「戻る」が分かりにくいのは、右列が置き換わるだけでナビゲーションが無いから。**
- 詳細の中は `Picker(.segmented)`（`previewShowsFigure`）で「立体」と「模様図」を切り替える。全画面のときは
  `BraidPreviewForFamily.needsItsOwnWayOut` で「閉じる」を足している。3Dの描き手（`RoundTube16PreviewView`・
  `Flat16PreviewView` など）は、埋め込みでないときに自分の `NavigationStack` と閉じるを持つ。
- 本数は `ProjectDraft.supportedThreadCounts` のメニュー `Picker`。プリセットの絞り込みは
  `BraidPresetCatalog.availablePresets(threadCount:)`。
- 作品は SwiftData の `KumihimoProject`（`threadCount`・`selectedBraidRecipeID` など）。列の改名に
  `@Attribute(originalName:)` を使った前例がある。
- 配備対象は **iOS 17.0**。

## 2. 組紐台

### データ

- **台の種類を1つの型にする**（例 `BraidStandKind { round, square }`。表示名「丸台」「角台」は文字列の側）。
- **プリセットの台は、そのレシピの台から読む**——いまのレシピの台は全部 `BraidStands.round*`（組ひもディスクの
  組み方も丸い台に置いている）なので、全部丸台。**組み方の名前で分岐しない**（`check-braiding-is-general.sh`）。
  角台の台（`BraidStand`）はまだ作らない。
- 絞り込みは**台と本数の両方**で（例 `availablePresets(threadCount:standKind:)`）。
- **`KumihimoProject` に台を足す。既定値つきの保存属性**にして、**台を持たない既存の保存が丸台として開く**ように
  する。SwiftData の軽い移行で足りるはずだが、**既存の保存が開けることを確かめる試験を置くこと**（前のスキーマで
  作った store を新しいスキーマで開く。作るのが重ければ、その理由を書いて手動の確認に替える）。
- `ProjectDraft` にも台を持たせ、保存・名前をつけて保存・上書き保存の往復で保たれること。

### 画面

- 編集画面の先頭（本数の上）に「組紐台」の節。`Picker`（メニュー）で「丸台」「角台」。初期値は丸台。
- **台を変えて、選択中の組み方が新しい台に合わなければ、組み方の選択だけを解除し、配色は維持する**
  （本数を変えたときと同じ）。
- 角台では一覧に「**この台と本数の組み方はまだありません**」。いまの「この本数の組み方はまだありません」は、
  台も合わせた言い方に直す。
- **組紐台の俯瞰図（`KumihimoBoardView`）は、角台でも今のまま。** 角台の図は、角台の組み方を足すときに決める。
- ホーム画面の行: 「組み方 ・ 台 ・ 本数」（例「江戸八つ組 ・ 丸台 ・ 8本」）。VoiceOver の読み上げにも台を入れる。

## 3. 詳細をシートで開く

- **結果のカードのタップは、どの幅でも `.sheet` で詳細を開く。** `fullScreenCover` と、右列を置き換える経路
  （`previewPreset`・`onChange(of: layout)` の移し替え）は無くす。**回転や幅の変化で詳細が閉じたり移ったり
  しない**のもこれで済む。
- **iPad 横は、画面中央のカード。小さなフォームシートにはしない**（仕様の以前からの条件「iPad の小さなフォーム
  シート内へ3Dを閉じ込めない」は残る）。iOS 18 以降は `.presentationSizing(.page)`、iOS 17 は既定の `.sheet`。
  **iPad 横で出る大きさをスクリーンショットで示すこと。** 小さすぎたら報告して止める（自分で全画面に戻さない）。
- シートの中は `NavigationStack`。**タイトルは組み方の名称**（レシピの `name`、例「江戸八つ組」）、
  **右上にテキストの「閉じる」**（`ProjectEditorStrings.dismiss`）。下へのスワイプでも閉じてよい。
- **中身は上に3D、下に模様図。** セグメント（`previewShowsFigure`）と `needsItsOwnWayOut` は無くす。
  3Dの描き手は埋め込みの形（`isEmbedded: true`）で置き、**描き手が持っている自分の `NavigationStack`・閉じるは
  シートの中では出さない**（二重のナビゲーションバーにしない）。
- **3Dの上に縦スクロールを重ねない**（回転のドラッグと競合する）。模様図が収まらなければ模様図の領域だけを
  スクロールさせる。上下の割合は iPhone 縦・iPad 横で見て決め、決めた値と理由を書く。
- 試作の注記（`prototypeNotice`）と模様図の注記は残す。描く族の無い組み方では3Dの位置に「描けない」、模様図は出す。
- 回転の代替ボタン（左へ・正面・右へ）と VoiceOver の名前・ヒントは今のまま使えること。

### 気をつけること: シートを閉じるたびに `ARView` が解放される

**Task 053 の手動確認で、3Dを閉じたときに RealityKit の中（`ARView` の解放、`CoreRE`）で落ちた**（Task 015 と
同じ系統）。シートにすると閉じる回数が増える。**開いて閉じるを各族（丸源氏・平源氏・八つ金剛・丸四つ・江戸八つ）で
何度か繰り返し、落ちたら `.ips` の名前を記録して報告する。** 落ちを隠す回避（解放しない、使い回す）は
入れる前に報告すること。

## 4. 試験

- 絞り込み: 丸台×各本数でいまと同じプリセットが出ること、角台では空であること。
- 台を変えたときの選択の解除と配色の維持。
- 保存の往復で台が保たれること。**台を持たない既存の保存が丸台として開くこと**（2節）。
- ホームの行の文字と VoiceOver の文言。
- **形状ハッシュは全部不変**（描き手には触らない）。
- 足す試験は軽く。**テスト段階の秒数を報告すること**（056 のあと 150 秒前後）。

## 5. 手動（UI テストは Task 015 のため回せない）

シミュレータで、次の画面のスクリーンショットを `.build/task058/` に置く:

- iPhone 16 縦: 編集画面（台の節が見える）、詳細のシート（丸源氏と江戸八つ組）。
- iPad Pro 11 横: 編集画面、詳細のシート（中央のカードで、背後に編集画面が見えること）。
- iPad Pro 11 縦: 詳細のシート。
- 角台を選んだ編集画面（「まだありません」）。ホーム画面（行に台が出ている）。

作者は江戸八つ組の見た目の受領を保留しているので、**詳細の中の見た目の良し悪しはこのタスクでは問わない。**

## 6. 報告に必ず入れるもの

1. 台のデータの持ち方と、既存の保存が丸台として開くことの確かめ方。
2. iPad 横のシートの大きさ（スクリーンショット）と、3Dと模様図の上下の割合。
3. 開いて閉じるを繰り返した結果（落ちたか、`.ips`）。
4. 全件の件数・失敗・スキップ・テスト段階の秒数。形状ハッシュが不変であること。
5. 仕様（`project-editor.md`・`home-screen.md`）と違えた所があれば、その理由。

## やらないこと

- 角台の組み方・角台の台（`BraidStand`）・角台の俯瞰図。
- 組ひもディスク・組ひもプレートを台として別に選ばせること（ディスクの組み方は丸台に数える）。
- 詳細の中で色を替えること。
- 描き手・形の値に触ること。
- 製品側の高速化（056 の申し送り）。

## 結果（2026-09-24、Claude Code）

### 1. 台のデータの持ち方と、既存の保存が丸台として開くことの確かめ方（報告1）

- **型は `BraidStandKind { round, square }`**（`Kumihimo/Domain/Braiding/BraidStand.swift`）。`BraidStand` に `kind` を足し、
  `BraidStands.round(...)` が `.round` を入れる。**導出は `kind` を読まない**（`groups` と同じ扱い）。角台の `BraidStand` は作っていない。
  表示名「丸台」「角台」は `ProjectEditorStrings.standName(_:)` の1か所で、ホームの行もここから読む。
- **プリセットの台はレシピの台から読む**: `BraidPreset.standKind` = `BraidMethodCatalog.recipe(for:)` → `stand(for:)` → `kind`。
  レシピの無いプリセットは `nil` で、どの台にも出ない。組み方の名前では分岐していない（`check-braiding-is-general.sh` は通る）。
- 絞り込みは **`BraidPresetCatalog.availablePresets(threadCount:standKind:)`**。編集画面はこれだけを使う。
  **台を問わない `availablePresets(threadCount:)` は残した**——各組み方の試験（丸源氏・八つ金剛・丸四つ・江戸八つ…の7ファイル）が
  「この本数でこの組み方が出るか」を台と無関係に問うているため。丸台では2つが同じ結果になることを試験で押さえた。
- **`KumihimoProject` には既定値つきの文字列の列 `standKindRawValue: String = "round"`（private）**を足し、型のついた
  `standKind` を通して読み書きする。知らない値も丸台として読む。**enum を直接 SwiftData に置かなかった**のは、iOS 17 の
  SwiftData で enum の列と既定値の軽い移行の組み合わせが確かでなく、`threadAssignmentsData` と同じ「private の保存列＋型のついた読み口」の
  前例に揃えたため。
- `ProjectDraft.standKind`（初期値 `.round`）。`hasValidAssignments` と保存時の `validate(project)` は、選んだ組み方が**本数と台の両方**に
  合うことを求める（`architecture.md` の不変条件も「本数と台」に直した）。既存の保存は全部丸台・全部 `round*` の組み方なので、
  これで開けなくなる保存は無い。
- 台を変える: `ProjectEditorStore.selectStandKind(_:)`。**合わない組み方の選択だけを解除し、配色と本数は維持する。**
  本数を変えたときの解除と同じ関数（`clearBraidPresetIfUnavailable`）を通す。
- **確かめ方（試験を置いた）**: `BraidStandAndDetailTests.aSaveWrittenBeforeStandsOpensOnARoundStand`。
  試験の側に **`0d38578` 時点の `KumihimoProject` の保存列を写した `KumihimoSchemaBeforeStands`**（`VersionedSchema`、台の列なし）を置き、
  一時ディレクトリの**ディスク上の store** に江戸八つ組の作品を1件書く。それを**今のモデルで、アプリと同じ
  `ModelContainer(for: KumihimoProject.self, configurations: ModelConfiguration(url:))` で開く**（SwiftData の自動の軽い移行）。
  `standKind == .round`、組み方・配色がそのまま、`ProjectDraft` が有効、ホームの行が「江戸八つ ・ 丸台 ・ 糸 8本」。
  重くない（単独 0.09 秒、全件の中では 1.66 秒——その実行で初めてディスクの store を作るため）。
- **作者の機体・シミュレータにある実際の保存は開いていない。** アプリ本体（`AppRootView`）を起動引数なしで立ち上げると
  そこで移行が走るので、このタスクでは触らなかった。作者が新しいビルドを初めて開いたときに移行される。
- 保存の往復: `theStandSurvivesSavingOverwritingAndSavingAs`（新規保存で角台 → 上書きで丸台 → 名前をつけて角台。元の作品は丸台のまま）。

### 2. iPad 横のシートの大きさと、3Dと模様図の上下の割合（報告2）

- **iPad Pro 11 (M4) 横（画面 1210×834 pt）で、シートは約 704×744 pt の中央のカード**。左右に編集画面（組紐台・糸の本数・色の配置と
  右列の結果）が暗く見えている（`.build/task058/ipad-landscape-detail-maru-genji.png`）。3Dの描画領域は約 672×245 pt、
  下の部分は約 343 pt。**小さなフォームシートにはなっていない**ので、止めずに進めた。
  縦（834×1210 pt）では約 704×995 pt（`ipad-portrait-detail-maru-genji.png`）。
- **シートを開いたまま横→縦に回しても、シートは閉じず、同じ中身のまま**（UI テスト `testWideIPadEditorOpensDetailAsSheetThatSurvivesRotation`
  を単独で回して通った。`ipad-detail-after-turning-upright.png`）。
- **iOS 18 以降は `.presentationSizing(.page)`、iOS 17 は既定の `.sheet`**（`braidDetailSheetSizing()`）。**iOS 17 の見え方は確かめていない**
  ——この Mac のシミュレータは iOS 18.0・18.3・18.5 だけで、iOS 17 のランタイムが無い。
- **上下の割合は 0.5**（`BraidDetailSheet.solidShare`。ナビゲーションバーの下の高さの半分を上の部分に）。決めた経緯:
  - 最初は 0.62 で、試作の注記と操作の説明を**3Dの下（上の部分）**に置いていた。標準の文字サイズでは収まったが、
    **アクセシビリティ最大（AX-XXXL）では上の部分がスクロールしない（3Dの上に縦スクロールを重ねない）ため、注記が「反復色を使った…」で切れた。**
  - そこで**注記と操作の説明を下の部分の先頭へ移した**（上の部分は3Dと回転ボタンだけ、下の部分は「注記 → 模様図 → 模様図の注記」で、
    収まらなければこの部分だけがスクロールする）。上の部分から文字が抜けた分、0.5 でも iPhone 16 縦で3Dの描画領域は約 360×248 pt と
    0.62 のとき（約 226 pt）より高く、模様図は注記を除いた残りを取る。AX-XXXL では注記が全文出て、模様図は 160 pt まで縮んだあと下の部分がスクロールする
    （`iphone16-detail-hira-genji-dark-ax-xxxl.png`）。
  - 模様図の高さは、下の部分の高さから注記2つの**測った高さ**（`onGeometryChange`）を引いた残り（最小 160 pt）。
- 3Dの描き手は埋め込みの形（`isEmbedded: true`）で置き、**埋め込みの形から見出しと「結果へ戻る」を外した**（右列の詳細が無くなって使い手がシートだけになったため）。
  埋め込みの形では注記も出さない（`showsNotes: false`）。**単独の形（自分の `NavigationStack`・閉じる・注記）は変えていない**——
  UI テストの表面フィクスチャ起動と `YatsuKongoComparisonSolid` が使う。描き手の形の値・メッシュには触れていない。
- 下へのドラッグ: **3Dの上で下へドラッグするとシートは閉じず、組紐が回る**（`ARView` の自前のパン認識が取る）。
  ナビゲーションバーや下の部分からの下スワイプでは閉じる。

### 3. 開いて閉じるを繰り返した結果（報告3）

- iPhone 16（iOS 18.5）で、**丸源氏4回・平源氏2回・八つ金剛（Z・返しほか3種から）4回・江戸八つ3回・丸四つ2回、計15回閉じた**
  （「閉じる」と下スワイプの両方）。iPad Pro 11 では丸源氏を4回開き（UI テスト3回・手で1回）、2回閉じた。
  **シートを開いたままアプリを終了したのも3回**（iPhone 2・iPad 1）。
- **落ちなかった。** `~/Library/Logs/DiagnosticReports` の `Kumihimo-*.ips` は作業の前後で 25 件のまま（新しいものは無い。
  前後の一覧は `.build/task058/ips-before.txt`・`ips-after.txt`）。**解放しない・使い回すといった回避は入れていない。**
- 回した回数は Task 053 で落ちたときより少ないかもしれない。**落ちないことの保証ではない。**

### 4. 検証（報告4）

- **全件1回**（`.build/test-results/task058-full.xcresult`、iPhone 16 `9EF8CDC3…`（iOS 18.5）、`-only-testing:KumihimoTests`、
  上限 300000 ミリ秒・1件 60 秒、並列なし。機体に `DRAW_SHEETS` が無いことを実行前に確かめた）:
  **505件中 成功500・失敗0・スキップ5**（`DRAW_SHEETS` の描画シート5件）。**打ち切りは無い。** `simctl diagnose` も残っていない。
  **テスト段階 133.1 秒**（起動 5.8 秒）、試験ごとの時間の和 126.6 秒（Task 057 は 156.7 秒・129.0 秒。差のほとんどは起動のぶれ）。
- 件数 493 → 505: `BraidStandAndDetailTests` が +13、`BraidScreenChoosesByFamilyTests` の `aPreviewShownOnItsOwnCanAlwaysBeLeft`（−1）を外した
  （全画面の詳細が無くなり、`needsItsOwnWayOut` を消したため。シートは自分のバーに必ず「閉じる」を持つ）。新しい試験の和は 1.7 秒。
- **形状ハッシュは全部不変**（`BraidMeshHashTests` の2件、`theMeshTheScreenShowsIsTheSameOne`、各組み方の試験のハッシュ、すべて通過。描き手の形には触れていない）。
- `sh Scripts/check-braiding-is-general.sh` は通る。ビルドの警告は無い。
- **UI テスト**: 既定の検証には入れていない（Task 015）。**詳細の出方が変わったので、編集画面から詳細を開く5件を新しい振る舞いに書き直した**
  （ナビゲーションバーの名前「丸源氏組」「平源氏組」、「結果へ戻る」を無くす、iPad 2件の名前と中身、「この台と本数の組み方はまだありません」）。
  このうち **iPad の2件だけを単独で回して通った**（`.build/test-results/task058-ipad.xcresult`。スクリーンショットの取得も兼ねた）。
  iPhone の3件（`testSixteenThreadProjectOpensMaruGenji3DPreview`・`testSixteenThreadProjectSelectsAndOpensHiraGenji3DPreview`・
  `testNoCompatiblePresetStillShowsUndecidedSelection`）は**回していない**。

### 5. 手動（スクリーンショットは `.build/task058/`）

| ファイル | 中身 |
| --- | --- |
| `iphone16-editor-stand-section.png` | iPhone 16 縦、編集画面の先頭（組紐台 → 糸の本数 → 色の配置） |
| `iphone16-stand-menu.png` | 台のメニュー（丸台・角台） |
| `iphone16-detail-maru-genji.png` | 詳細のシート、丸源氏組 |
| `iphone16-detail-edo-yatsu.png` | 詳細のシート、江戸八つ組 |
| `iphone16-detail-hira-genji-dark-ax-xxxl.png` | 平源氏組、ダーク・AX-XXXL（注記が全文、下の部分がスクロール） |
| `iphone16-square-stand-empty.png` | 角台を選んだ編集画面（「この台と本数の組み方はまだありません」） |
| `iphone16-home-rows-with-stand.png` | ホーム（「組み方未選択 ・ 角台 ・ 糸 4本」などの行。角台で保存した作品を含む） |
| `ipad-landscape-editor.png` | iPad Pro 11 横、編集画面（左列に組紐台） |
| `ipad-landscape-detail-maru-genji.png` | iPad 横、中央のカードのシート（背後に編集画面） |
| `ipad-detail-after-turning-upright.png` | シートを開いたまま縦に回したところ |
| `ipad-portrait-detail-maru-genji.png` | iPad 縦、詳細のシート |

- ホーム: サンプル作品の起動引数で、「新しく編む」→ 角台 → 保存（名前は英字。シミュレータへの入力が ASCII しか通らなかった）→ 戻る、で
  行に「角台」が出た。VoiceOver の読み上げ文言は試験（`theHomeRowNamesTheBraidTheStandAndTheThreads`）で押さえた。**VoiceOver を実際に当てての確認はしていない。**
- 回転ボタン（左へ・正面・右へ）はシートの中で効いた。VoiceOver の名前・ヒントは描き手のものをそのまま使っている。
- 詳細の中の見た目の良し悪しは、指示どおり問うていない。

### 6. 仕様と違えた所（報告5）

仕様（`project-editor.md`・`home-screen.md`）は書き換えていない。違えた所・仕様が決めていなかった所:

1. **注記の位置**: 仕様は「中身は上下に2つ: 上に3D、その下に模様図」。試作の注記と操作の説明は、**3Dの下ではなく下の部分の先頭**（模様図の上）に置いた。
   理由は2節（上の部分はスクロールできないので、大きな文字で注記が切れる）。3Dと模様図が上下に並ぶことは変わらない。
2. **角台の空状態の説明文**: 見出しは仕様どおり「この台と本数の組み方はまだありません」。その下の説明文は、丸台では今のまま
   （「16本を選ぶと、丸源氏の試作シミュレーションを表示できます。…」）、**角台では「丸台を選ぶと、試作シミュレーションを表示できます。
   配色はこのまま保存できます。」**にした。角台で「16本を選ぶと…」と案内すると、選んでも何も出ないため。
3. **ホームの行**: 指示書の例は「江戸八つ組 ・ 丸台 ・ 8本」だが、**本数は今の表示「糸 8本」のまま**、組み方も保存している表示名（「江戸八つ」）のまま。
   並びは「組み方 ・ 台 ・ 本数」。
4. 詳細を開くカードの VoiceOver のヒントは今の「3D詳細を開きます」のまま（中身は3Dと模様図になった）。

### 7. 文書

- `docs/architecture.md`: 初期データモデルに `standKind` と保存の仕方、不変条件を「本数と台」に、適応レイアウトの「3Dを右側の主要コンテンツ」を
  「詳細はどの幅でもシート」に直した。
- `docs/README.md`: Task 058 の行を結果に差し替えた。

### 8. 残ること

- iOS 17 の既定のシートの大きさ（iOS 17 のシミュレータが無い）。
- iPhone の UI テスト3件（回していない）と、Task 015 の通しの落ち。
- 作者の実際の保存の移行（初めて開いたときに走る）。
- 角台の組み方・角台の俯瞰図（やらないこと）。

---

## 追補1（2026-09-24、作者）: 「組み方をまだ決めない」をカードにして、結果の見出しの上へ

作者:「組み方をまだ決めない、というのはなくていい。組み方は選択せず、台と本数、色の組み合わせのみを保存というような
文章になるかな？ カードにしていい。そして場所を組み方別シミュレーション結果のタイトルの上へ配置。組み方別〜は
八つ金剛などを引き続き配置。」

仕様（`project-editor.md` の「全体構成」「選択」と受け入れ条件）は審査側が書き直した。やること:

1. **`SimulationResultsBoundaryView` の先頭の「組み方をまだ決めない」の行を、その節から外す。**
   節（見出し「組み方別のシミュレーション結果」）の中は、組み方のカードだけにする。
2. **「組み方を選ばない」のカードを、その見出しの上に置く。** 見出し「組み方を選ばない」、説明
   「台と本数、色の組み合わせだけを保存します」（`ProjectEditorStrings`。旧 `undecidedBraid` は置き換える）。
   1列では「色の配置」と結果の見出しのあいだ、2列では右列の一番上。
3. **選択の示し方は組み方のカードと同じ**（チェックマークと境界線、色だけで示さない）。サムネイル・3D の印・
   詳細は持たない。タップで選択（`selectPreset(nil)`）。
4. 選ばれているのは、このカードと組み方のカードを合わせていつも1つ。新規作品の初期状態はこのカード。
5. アクセシビリティ識別子（`undecidedPresetButton`）は、試験と UI テストが使っているなら名前を変えずに移してよい。
   VoiceOver の名前は「組み方を選ばない」、値に選択状態。

**変えないもの**: 保存の中身（組み方を選ばない作品は `selectedBraidRecipeID == nil`、保存名は
`KumihimoProject.undecidedBraidName`＝「組み方未選択」のまま）。ホームの行の「組み方未選択」も今回は変えない。

**確かめること**: iPhone 16 縦と iPad Pro 11 横で、カードが結果の見出しの上にあるスクリーンショット
（`.build/task058/`）。選択の切り替え（カード ⇄ 組み方）で、選ばれているのがいつも1つであること。
全件の件数とテスト段階の秒数。

### 追補1の結果（2026-09-24、Claude Code。枝 `claude/task-058-addendum-1`。**PR #43 でマージ**——作者が PR の作成とマージを許可した）

1. **行を節から外した**: `SimulationResultsBoundaryView` は組み方のカードだけになった（計算中・失敗・「まだありません」の表示も
   この節の中のまま）。
2. **カード `NoBraidCard`**（`Kumihimo/Features/ProjectEditor/NoBraidCard.swift`）を、1列では「色の配置」と結果の見出しのあいだ、
   2列では右列の一番上に置いた。見出し「組み方を選ばない」、説明「台と本数、色の組み合わせだけを保存します」
   （`ProjectEditorStrings.noBraidTitle`・`noBraidMessage`。旧 `undecidedBraid` は消した）。
3. **選択の示し方は組み方のカードと同じ**: チェックマークの行（`BraidSelectionRow`）とカードの地・境界線（`braidChoiceCard(isSelected:)`）を
   組み方のカードから取り出して、両方で使う。組み方のカードの見た目は変わらない。サムネイル・3Dの印・詳細は無い。
   カード全体がボタンで、余白を押しても選べる（`selectBraidPreset(nil)`）。
4. **選ばれているのはいつも1つ**: `exactlyOneChoiceIsChosenAtATime`（4・8・12・16本それぞれ。画面と同じ判定
   `NoBraidCard.isSelected`・`SimulationResultsBoundaryView.isSelected` で数える）。新規作品はこのカードから始まる。
   シミュレータでも カード → 丸源氏 → カード と切り替えて、チェックと境界線がいつも1枚にだけ付くのを見た。
5. アクセシビリティ識別子は `undecidedPresetButton`（`project-editor.preset-undecided`）のまま移した。VoiceOver の名前は
   「組み方を選ばない」、説明はヒント、値は「選択中」／「未選択」。**VoiceOver を実際に当てての確認はしていない。**

**変えていないもの**: 保存の中身（`selectedBraidRecipeID == nil`、保存名「組み方未選択」）とホームの行。試験
`theNoBraidCardSaysWhatIsSaved` で保存名が変わっていないことも押さえた。

**スクリーンショット**（`.build/task058/`）: `addendum1-iphone16-no-braid-card-selected.png`（iPhone 16 縦、色の配置 → カード → 結果の見出し）、
`addendum1-iphone16-braid-selected.png`（丸源氏を選ぶとカードの印が外れる）、`addendum1-ipad-landscape-editor.png`
（iPad Pro 11 横、右列の一番上にカード。UI テスト `testWideIPadEditorOpensDetailAsSheetThatSurvivesRotation` を単独で回して撮った。通過）。

**検証**: 全件1回（`.build/test-results/task058a1-full.xcresult`、iPhone 16 `9EF8CDC3…`、`-only-testing:KumihimoTests`、上限 300000 ミリ秒・
1件 60 秒、並列なし）: **507件中 成功502・失敗0・スキップ5**。打ち切りなし。**テスト段階 166.9 秒**（起動 10.6 秒）、
試験ごとの時間の和 155.0 秒。件数は 505 → 507（試験2つ、うち1つは本数4通り）。新しい試験の和は 0.06 秒。
**和が前回（126.6 秒）より 28 秒長いのは、この変更と関係のない重いメッシュの試験が一様に 15〜30% 遅かったため**
（`test_times.py --compare` で上位 25 件すべて。この実行のときシミュレータが3台起動していた——iPhone 16・iPad Pro 11・作者の iPad 10th gen。
iPad Pro 11 はあとで落とした）。全件は回し直していない。形状ハッシュは不変、`check-braiding-is-general.sh` 通過、ビルドの警告なし。
UI テストは上の1件だけ回した（識別子を使う残りの3件は回していない）。

