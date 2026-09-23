# Task 056: 重い試験を速くする

- 状態: **完了**（2026-09-23）。**テスト段階 289.5 秒 → 152.1 秒、試験ごとの時間の和 277.9 秒 → 130.7 秒。**
  **製品コードは1行も変えていない。**形状ハッシュ・件数（490）・assert は不変。結果は末尾の「結果」
- 当初: **指示書**（2026-09-23）。**worker へそのまま渡す。承認待ちの段は挟まない**（042 以降の型）
- 前提（先に読むこと）: **`docs/tasks/018-slow-mesh-test.md`**（同じことを一度やった。**型はこれに倣う**）、
  `AGENTS.md` のテストの規約
- 基準: **最新の main**（Task 009 の PR #39、マージコミット `99cc70a` 以降）。枝を切り直すこと。
- **製品コードに触れてよい。ただし出力は1ビットも変えない**（下の「動かしてはいけないもの」）

## 0. なぜ今これか

作者の決定（2026-09-23）:「テストは重いものを速くしよう」。

全件のテスト段階は上限 300 秒に迫っている。**レシピを1つ足すごとに約 9 秒増える**:

| 時点 | 件数 | テスト段階 |
| --- | --- | --- |
| Task 055 の最終 | 481 | 約 272 秒 |
| Task 009 を合わせた後 | 490 | **280.8 秒** |

**次のレシピ（010・011 など）で 290 秒前後、その次で上限を超える。** 超えた時点で全件が打ち切られ、
組み方を足す作業が全部止まる。**だから次のレシピより先にやる。**

## 1. 目標

- **テスト段階を 220 秒以下にする**（上限まで 80 秒——1レシピ約 9 秒なら、あと 8〜9 個足せる）。
- **レシピ1つを足したときの増分**も報告する。共有できるものを共有すれば、ここも縮むはず。

## 2. 動かしてはいけないもの

**Task 018 は 243 秒の試験を 22 秒にして、形を1頂点も動かさなかった。それと同じ条件で行う。**

- **形状ハッシュは全部不変**（丸源氏・平源氏・八つ金剛 S・Z・返し・丸四つ・江戸八つ）。
  **ハッシュが「出力を変えていない」証拠である。** 1つでも動いたら、その直しは戻す。
- **試験を消さない。`.disabled`・skip にしない。件数を減らさない。**
- **上限を上げない**（`-maximum-test-execution-time-allowance` と `.timeLimit` の例外は 018 で閉じた）。
- **別のテストプランへ逃がさない**（全件で数えない試験を作らない）。
- **assert を弱めない。** 標本を間引くなら、**その assert が何を保証しているか**を書き、
  間引いても保証が変わらないことを示す。**変わるなら間引かない。**
- **`.serialized` を外すときは、付いていた理由を確かめてから。** RealityKit の都合（Task 015）で
  付いているものは外さない。

## 3. 手順

### 3.1 まず測る（直す前に）

最新 main で全件を1回流し、**xcresult から1件ごとの時間を並べる**（Swift Testing と XCTest の両方）。
報告の最初に**上位 25 件の表**を置く（名前、秒、累積の割合、どのファイル・スイートか）。

**参考: 審査側が Task 054 の最終ログから数えたもの**（`.build/task054/work/final.log`。
Task 055・009 より前、427 件分しか拾えていない。**当てにせず測り直すこと**）:

| 秒 | 累積 | 試験 |
| --- | --- | --- |
| 14.73 | 6.4% | `theShippedSurfaceIsUnchanged` |
| 11.04 | 11.1% | `bothPathsAreDrawnStraightOnAndTurned` |
| 9.17 | 15.1% | `twistPhaseIsAffineAndThereforeContinuousInsideAStrand` |
| 8.95 | 18.9% | `aCameraThatDiscardsBackFacesFindsNoHole` |
| 8.41 | 22.6% | `theMeshTheScreenShowsIsTheSameOne` |
| 8.15 | 26.1% | `twistKeepsOneHandAndOneAngleOnEveryStrand` |
| 8.11 | 29.6% | `allMaterialGroupsBuildOneRealityKitMesh` |
| 7.52 | 32.8% | `whatEachPathDoesWithTheSameColouring` |
| 7.49 | 36.0% | `aTableThisCodeHasNotSeenIsDrawnByItsFamily` |
| 7.29 | 39.2% | `everyRegionCarriesTheRidgeIncludingBothEdges` |
| 6.55 | 42.0% | `theRidgeAngleIsIndependentOfTheRadiusAndTheRepeatCount` |

**上位 11 件で1件ごとの時間の合計（231.8 秒）の 42%。** 1件ごとの合計はテスト段階（約 280 秒）より
**約 50 秒短い**——試験の外（起動、テストホスト、シミュレータ、スイートの準備）に使われている時間がある。
**それがどこかも数えること。** 試験の中より安く削れるかもしれない。

### 3.2 何が重いのかを1件ずつ確かめる

名前から見る限り、上位は**メッシュを作る試験**である。**審査側の仮説（確かめること）**:

1. **同じレシピのメッシュを、試験ごとに作り直している。** 形状ハッシュ・「画面が見せるのと同じメッシュ」・
   RealityKit の材料グループ・決定性の試験が、それぞれ同じ族の同じ配色を一から作っていないか。
   → **一度だけ作って共有する**（スイートの `static let` や、レシピ ID をキーにした共有の出来上がり）。
   **ただし「決定性」を見る試験（`meshGenerationIsDeterministic` など）は、2回作ることが試験の中身なので
   共有しない。**
2. **ループの中で、ループに依らない計算をやり直している**——018 の正体がこれだった
   （頂点ごとに 1028 点の断面外形を引き直していた）。
3. **RealityKit のメッシュを何度も組んでいる**（`allMaterialGroupsBuildOneRealityKitMesh` が2か所にある）。
4. **標本が保証に対して過剰**——ただし2節のとおり、間引くなら保証が変わらないことを示してから。

**1つ直すごとに**、その試験の前後の秒数と、ハッシュが不変であることを記録する。

### 3.3 並列

Swift Testing は既定で並列に回す。**並列で回っていない重い試験**があれば、その理由を確かめる。
理由が無ければ並列にしてよい。RealityKit の都合で直列のものは触らない（2節）。

## 4. 予言（外れたらそれが答え）

- 上位 10 件ほどで全体の 4 割前後を占め、**その大半は同じメッシュの作り直し**である。
- 共有に直すと、**レシピ1つを足したときの増分も縮む**（いまは約 9 秒）。
- 試験の外の約 50 秒は、試験の中の直しでは減らない。

## 5. 報告に必ず入れるもの

1. **直す前**の上位 25 件の表と、1件ごとの合計・テスト段階・呼び出し全体の3つの秒数。
2. 直したもの1つずつ: 何が重かったか、どう直したか、その試験の前後の秒数。
3. **直した後**の同じ表と、同じ3つの秒数。
4. **形状ハッシュが全部不変であること**（族ごとに列挙）。**件数が同じであること。**
5. 間引いた標本があれば、その assert の保証が変わらない理由。
6. **レシピ1つを足したときの増分**（直す前と後で、見積もりでよい。見積もり方を書く）。
7. 試験の外の時間の内訳（分かった範囲で）。

## やらないこと

- 形・見た目を変えること。
- 手動確認（作者が保留した。Task 009 の 11節）。
- 新しいレシピ。

---

## 結果（2026-09-23）

### 0. 先に答え

| | 直す前 | 直した後 |
| --- | --- | --- |
| 件数 | 490（成功485・失敗0・スキップ5） | **490（成功485・失敗0・スキップ5）** |
| 試験ごとの時間の和 | **277.9 秒** | **130.7 秒** |
| テスト段階（xcresult の開始〜終了） | **289.5 秒** | **152.1 秒** |
| 呼び出し全体（`xcodebuild` の壁時計） | 292 秒 | 154 秒 |
| うち試験の前の起動 | 11.0 秒 | 20.8 秒 |

- **目標の 220 秒を 68 秒下回った。**上限 300 秒までは 148 秒ある。
- **製品コードは1行も変えていない**（`git diff -- Kumihimo/` は空）。直したのは試験の側だけである。
- 打ち切りは 0 件、ビルド警告 0 件。どちらも `.build/test-results/task056-before.xcresult`・`task056-after.xcresult`。
  条件は `AGENTS.md` のとおり（iPhone 16 `61B4E643…`、`-only-testing:KumihimoTests`、
  `-parallel-testing-enabled NO`、`-test-timeouts-enabled YES -default-test-execution-time-allowance 60`、
  `-maximum-...` は渡していない。機体に `DRAW_SHEETS` は無い）。
- 数え方は `Scripts/task056/test_times.py`（下の 1.1 の罠を避けてある）。

**予言の当たり外れ:**

1. 「上位 10 件ほどで 4 割前後、その大半は同じメッシュの作り直し」——**大筋で当たり。**上位 10 件で 33.9%、
   上位 25 件で 64.3%。上位 25 件のうち 19 件が丸源氏か平源氏の同じメッシュを自分で作り直していた。
2. 「共有すればレシピ1つの増分（約 9 秒）も縮む」——**前提が外れていた。**増分は 9 秒ではなかった（6節）。
3. 「試験の外の約 50 秒は試験の中の直しでは減らない」——**外れ。**約 50 秒のうち約 32 秒は
   **試験の中の時間が xcresult で小さく見えていたもの**だった（1.1）。本当に試験の外なのは起動の数秒〜20 秒である（2節）。

### 1. 直す前（main `99cc70a` と同じ木）

#### 1.1 xcresult の罠: 引数つきの試験は「平均」が載っている

審査側の表（約 232 秒）もこちらの最初の集計（245.8 秒）も、試験の欄の `durationInSeconds` を足していた。
**`@Test(arguments:)` の試験では、その欄は引数ごとの時間の和ではなく、ほぼ平均である。**
引数の実行 44.7 秒が 12.7 秒と出ていた。引数の時間を足すと **277.9 秒**で、スイートの所要時間の和
（277.9 秒）、最初のスイートの開始から最後の終わりまで（278.0 秒）と一致する。
**「試験の外の約 50 秒」の 32 秒はこれだった。**

#### 1.2 上位 25 件（直す前）

| # | 秒 | 累積 | スイート | 試験 |
| --- | --- | --- | --- | --- |
| 1 | 15.09 | 5.4% | BraidFlatGeneratorCellsFromOccupancyTests | theShippedSurfaceIsUnchanged |
| 2 | 11.04 | 9.4% | BraidSideBySideTests | bothPathsAreDrawnStraightOnAndTurned |
| 3 | 10.07 | 13.0% | MaruGenjiSurfaceMeshTests | oneRepeatMeasuresTheCircumferenceTimesTheDeclaredAspect ×4 |
| 4 | 9.42 | 16.4% | MaruGenjiSurfaceMeshTests | twistPhaseIsAffineAndThereforeContinuousInsideAStrand |
| 5 | 8.89 | 19.6% | MaruGenjiSurfaceMeshTests | theChevronDensityFollowsTheDeclaredAspectAtAnySize ×3 |
| 6 | 8.31 | 22.6% | BraidScreenChoosesByFamilyTests | theMeshTheScreenShowsIsTheSameOne |
| 7 | 8.04 | 25.5% | BraidOrientationTests | aCameraThatDiscardsBackFacesFindsNoHole |
| 8 | 8.01 | 28.4% | MaruGenjiSurfaceMeshTests | twistKeepsOneHandAndOneAngleOnEveryStrand |
| 9 | 7.90 | 31.2% | MaruGenjiSurfaceMeshTests | allMaterialGroupsBuildOneRealityKitMesh |
| 10 | 7.35 | 33.9% | BraidColourDiagnosisTests | whatEachPathDoesWithTheSameColouring |
| 11 | 7.35 | 36.5% | BraidFamilyDrawingTests | aTableThisCodeHasNotSeenIsDrawnByItsFamily |
| 12 | 7.29 | 39.1% | HiraGenjiSurfaceMeshTests | everyRegionCarriesTheRidgeIncludingBothEdges |
| 13 | 6.52 | 41.5% | BraidOrientationTests | everyTriangleFacesOutward ×3 |
| 14 | 6.49 | 43.8% | RoundTube8CardAgreesWithSolidTests | theCardShowsWhatTheSolidShowsAcrossARepeat ×3 |
| 15 | 6.44 | 46.1% | MaruGenjiSurfaceMeshTests | theRidgeAngleIsIndependentOfTheRadiusAndTheRepeatCount |
| 16 | 6.44 | 48.4% | BraidFamilyDrawingTests | aRecipeFindsADrawerWhenAndOnlyWhenItsFamilyHasOne ×7 |
| 17 | 5.42 | 50.4% | HiraGenjiSurfaceMeshTests | consecutiveTilesMeetOnTheSameSurface |
| 18 | 5.24 | 52.3% | RoundTube16StrandTipTests | aColouringMovesNoVertexAndOnePositionRecoloursOnlyItsOwnThread |
| 19 | 5.21 | 54.2% | MaruGenjiSurfaceMeshTests | meshGenerationIsDeterministic |
| 20 | 5.20 | 56.0% | BraidSideBySideTests | theFlatBraidIsDrawnBothWaysAndMeasured |
| 21 | 5.08 | 57.9% | RoundTube16SurfacePatternTests | colorChangeUpdatesThePatternConsumedByThumbnailAndSurfaceMesh |
| 22 | 4.68 | 59.5% | BraidMeshHashTests | theFlatBraidsMeshIsTheShapeItWas |
| 23 | 4.59 | 61.2% | RoundTube16StrandTipTests | atEveryCrossingTheBundleGoingOnCoversTheEndOfTheOneGoingUnder |
| 24 | 4.28 | 62.7% | BraidSideBySideTests | theRoundBraidIsDrawnBothWaysAndMeasured |
| 25 | 4.21 | 64.3% | BraidSurfaceWatertightnessTests | hiraGenjiSurfaceIsOpaqueInsideItsOwnOutline |

**スイートの型名とファイル名は違う**（018 の注意）: `MaruGenjiSurfaceMeshTests` は `RoundTube16SurfaceMeshTests.swift`、
`HiraGenjiSurfaceMeshTests` は `Flat16SurfaceMeshTests.swift`、`BraidFlatGeneratorCellsFromOccupancyTests` は
`BraidGeneratorCellsFromOccupancyTests.swift` にある。

**上位の底にあった数:** Debug ビルドでは丸源氏のメッシュ（419,184 頂点）1つに**約 2.6 秒**、
平源氏（361,350 頂点）に**約 3.6 秒**かかる。直す前の表で 2.6〜4 秒の試験が長く並んでいたのは、
ほとんどが「メッシュを1つ作って、少し見る」試験だった。

### 2. 試験の外の時間（報告7）

action ログ（`xcresulttool get log --type action`）のスイートごとの開始時刻から分けた。

| | 直す前 | 直した後 |
| --- | --- | --- |
| 起動（テスト開始〜最初のスイート） | 11.0 秒 | 20.8 秒 |
| 試験と試験の間 | 0.1 秒 | 0.1 秒 |
| 後始末（最後のスイート〜終わり） | 0.6 秒 | 0.7 秒 |

- **試験の外は起動だけで、起動は実行ごとに大きくぶれる。**Task 054 の最後の全件は 5.7 秒、
  Task 009 を合わせた後は 3.4 秒、今回は 11.0 秒と 20.8 秒だった。**`99cc70a` と同じ木で、テスト段階は
  280.8 秒（Task 009 の最後）と 289.5 秒（今回の直す前）だった。**差の 8.7 秒のうち 7.6 秒が起動、
  試験ごとの和の差は 1.0 秒である。
- **一度は起動が 84 秒かかった**（2 件だけの小さな実行で、試験の中は 0.009 秒）。直前に固まった
  `xcodebuild` を止めた後だった。テストホストは 20 秒遅れて立ち上がり、そのあと 64 秒何も記録せずに
  待っていた。8 分後に同じものを流すと 4.5 秒だった。**原因は特定していない。**
- **起動は試験の直しでは減らない**（予言3のこの部分は当たり）。減らすならテストホストの側の話で、
  このタスクの範囲では触っていない。
- コードカバレッジが有効になっている（結果の束にカバレッジの報告がある）。報告の作成は 0.03 秒で、
  計測のための命令が試験を遅くしている分は測っていない。

### 3. 何が重かったか、どう直したか（報告2）

#### 3.1 同じメッシュを試験ごとに作り直していた（審査側の仮説1、**当たり**）

同じ配色・同じ大きさのメッシュを、次の数だけの試験がそれぞれ作っていた。

| メッシュ | 読んでいた試験 |
| --- | --- |
| 丸源氏・青桃の試験用配色・既定の大きさ | `MaruGenjiSurfaceMeshTests` の 16 か所（引数つきの試験の既定の大きさを含む）、`UnrolledPatternThumbnailLayoutTests` |
| 平源氏・色見本を順に並べた配色 | `HiraGenjiSurfaceMeshTests` の 7 件、`BraidSurfaceWatertightnessTests` の 2 件 |
| 丸源氏・出荷の配色 | ハッシュ、画面、並べて描く2件、色の診断、向き、升からの形——7 か所 |
| 平源氏・出荷の配色 | 同じく 7 か所 |
| 丸源氏・青桃桃青の配色 | `RoundTube16StrandTipTests` の 2 件、RealityKit の試験（同じ配色の別名 2 つ） |
| 丸源氏・半径 0.2×7 回、1.35×3 回 | 引数つきの 2 件と `theRidgeAngleIsIndependent…` |

**置き換えた生成は 55 回で、中身は 10〜11 通りだった**（丸源氏6：青桃×4つの大きさ・出荷・青桃桃青、
平源氏4〜5：色見本・出荷・本の p97 左右。本の p96 は出荷と同じ色で、同じ鍵になっていると見られる）。

**直し方:** `KumihimoTests/SharedMeshes.swift` を足した。配色（位置と色の並び）と大きさを鍵に、
最初に頼まれたときに作り、あとの試験には同じものを渡す。ロックの下で作るので、並列に回しても
同じものを2度作らない。上の表の読み手はここから受け取るようにした（11 ファイル）。
方針は `docs/architecture.md`「試験が読むメッシュは、1回の実行で1度だけ作る」に書いた。

**共有していないもの（作ること自体が試験の中身だから）:**

- 2回作って同じかを見る `meshGenerationIsDeterministic`
- 悪い引数で `nil` が返るかを見る `malformedPatternAndParametersFailSafely`・`malformedInputsFailSafely`
- 製品の経路を通すことが中身の `BraidFamilyDrawingTests`（`BraidFamilyDrawing.mesh(for:on:)`）
- 配色を1か所替えて頂点が動かないことを見る2件（`aColouringMovesNoVertex…`、`colorChangeUpdates…`）。
  どちらも鍵がその試験だけのもので、共有しても速くならない

**共有しても試験が問うことは変わらない理由:** メッシュは値なので、ある試験が別の試験の読むものを
変えることはできない。生成器は呼び出しの間に状態を持たない（`static var` はすべて計算型で、乱数も
時刻も使っていない）。丸源氏は `meshGenerationIsDeterministic` が2回作って同じことを見ている。
**平源氏には同じ試験が無いので、一時的な調べ物で2回作って全フィールドを比べ、同じだった**（5節）。
形状ハッシュの試験は、共有されたメッシュを読んでも、その実行の生成器が作ったものを読んでいる。

**スイートが最初に頼んだ試験が、作る分を払う。**そのため直した後も数秒かかって見える試験がある
（例: `meshIsFiniteGroupedAndNondegenerate` 3.41 秒、`whatEachPathDoesWithTheSameColouring` 7.39 秒）。
どの試験が払うかは実行の順で変わる。**個々の試験の数字ではなく和で見ること。**

#### 3.2 ループの中で、ループに依らない探し物をしていた（仮説2、**1か所で当たり**）

`twistPhaseFit` が**1本の束ごとにメッシュ全頂点を歩いてその束の頂点を探していた**。64 本 × 419,184 頂点。
これを呼ぶ2件（`twistPhaseIsAffine…`、`twistKeepsOneHand…`）は、**同じファイルの別の試験が Task 052 で
直したのと同じ形**だった（`verticesBySegment` で1度だけ束ごとに分ける）。同じ直し方で揃えた。
**分けた頂点は昇順のまま渡るので、最小二乗の和は同じ順で足される。**

#### 3.3 RealityKit（仮説3、**外れ**）

`allMaterialGroupsBuildOneRealityKitMesh`（丸源氏 7.90 秒、平源氏 4.11 秒）の重さは `MeshResource` を
組むことではなく、**その前にメッシュを作ることだった。**共有すると 0.29 秒・0.28 秒。RealityKit の
部分は手を入れていない。

#### 3.4 標本の間引き（仮説4）

**やっていない。**どの試験も、見る点・見る頂点・見る視線は1つも減らしていない。

#### 3.5 並列（3.3 の指示）

**この条件ではすべての試験が直列に回っている。**試験ごとの時間の和（277.9 秒）が最初のスイートの
開始から最後の終わりまで（278.0 秒）と一致する。**原因は個々の試験ではなく、実行の旗**
（`-parallel-testing-enabled NO`）が Swift Testing の並列も止めているためとみられる（**旗を替えて確かめてはいない**）。旗は `AGENTS.md` の 4
（シミュレータをクローンさせない）が決めているので**触っていない**。加えて多くのスイートが
`@MainActor` で、並列にしても主アクターの上では1本ずつになる（試験のファイル 73 のうち 47）。**`.serialized` は1つも外していない。**
並列にするかどうかは、クローンの問題と合わせて作者の判断に残す。

### 4. 直した後（報告3）

| # | 秒 | 直す前 | 累積 | スイート | 試験 |
| --- | --- | --- | --- | --- | --- |
| 1 | 7.39 | 7.35 | 5.7% | BraidColourDiagnosisTests | whatEachPathDoesWithTheSameColouring（出荷の2つを最初に作る） |
| 2 | 7.33 | 7.35 | 11.3% | BraidFamilyDrawingTests | aTableThisCodeHasNotSeenIsDrawnByItsFamily |
| 3 | 7.31 | 15.09 | 16.9% | BraidFlatGeneratorCellsFromOccupancyTests | theShippedSurfaceIsUnchanged（本の p97 左右はここだけで作る） |
| 4 | 6.85 | 6.49 | 22.1% | RoundTube8CardAgreesWithSolidTests | theCardShowsWhatTheSolidShowsAcrossARepeat ×3 |
| 5 | 6.74 | 8.89 | 27.3% | MaruGenjiSurfaceMeshTests | theChevronDensityFollowsTheDeclaredAspectAtAnySize ×3（3つの大きさを最初に作る） |
| 6 | 6.42 | 6.44 | 32.2% | BraidFamilyDrawingTests | aRecipeFindsADrawerWhenAndOnlyWhenItsFamilyHasOne ×7 |
| 7 | 5.76 | 5.08 | 36.6% | RoundTube16SurfacePatternTests | colorChangeUpdatesThePatternConsumedByThumbnailAndSurfaceMesh |
| 8 | 5.40 | 5.21 | 40.7% | MaruGenjiSurfaceMeshTests | meshGenerationIsDeterministic |
| 9 | 5.16 | 5.24 | 44.7% | RoundTube16StrandTipTests | aColouringMovesNoVertexAndOnePositionRecoloursOnlyItsOwnThread |
| 10 | 4.72 | 11.04 | 48.3% | BraidSideBySideTests | bothPathsAreDrawnStraightOnAndTurned |
| 11 | 4.57 | 4.59 | 51.8% | RoundTube16StrandTipTests | atEveryCrossingTheBundleGoingOnCoversTheEndOfTheOneGoingUnder |
| 12 | 4.21 | 8.04 | 55.0% | BraidOrientationTests | aCameraThatDiscardsBackFacesFindsNoHole |
| 13 | 4.19 | 4.21 | 58.2% | BraidSurfaceWatertightnessTests | hiraGenjiSurfaceIsOpaqueInsideItsOwnOutline |
| 14 | 3.66 | 7.29 | 61.0% | HiraGenjiSurfaceMeshTests | everyRegionCarriesTheRidgeIncludingBothEdges |
| 15 | 3.41 | 2.98 | 63.6% | MaruGenjiSurfaceMeshTests | meshIsFiniteGroupedAndNondegenerate |
| 16 | 3.14 | 3.16 | 66.0% | BraidSurfaceWatertightnessTests | maruGenjiSurfaceIsOpaqueFromEveryLineOfSight |
| 17 | 2.76 | 2.68 | 68.1% | RoundTube8CardAgreesWithSolidTests | theFloorHardlyShows ×3 |
| 18 | 2.69 | 3.29 | 70.2% | HiraGenjiSurfaceMeshTests | consecutivePatternRepeatsKeepColorAndBoundaryMaterialPhase |
| 19 | 2.09 | 8.31 | 71.8% | BraidScreenChoosesByFamilyTests | theMeshTheScreenShowsIsTheSameOne |
| 20 | 2.01 | 2.00 | 73.3% | BraidFromRecipeTests | theNewPathIsDrawnForTheAuthorToLookAt |
| 21 | 1.98 | 2.11 | 74.8% | BraidFromRecipeTests | everyShippedRecipeBuildsAndDraws ×7 |
| 22 | 1.72 | 4.28 | 76.1% | BraidSideBySideTests | theRoundBraidIsDrawnBothWaysAndMeasured |
| 23 | 1.64 | 1.61 | 77.4% | Flat16CardAgreesWithSolidTests | theSolidShowsTheThreadTheCardsRuleNames |
| 24 | 1.52 | 5.20 | 78.6% | BraidSideBySideTests | theFlatBraidIsDrawnBothWaysAndMeasured |
| 25 | 1.50 | 1.51 | 79.7% | BraidReadingFixtureTests | aimingAtTheSeamReadsTheSameThreadTwice |

**直した試験の前後**（2 秒以上縮んだもの。全部で 147.2 秒縮んだ）:

| 試験 | 前 | 後 |
| --- | --- | --- |
| oneRepeatMeasuresTheCircumferenceTimesTheDeclaredAspect ×4 | 10.07 | 1.30 |
| twistPhaseIsAffineAndThereforeContinuousInsideAStrand | 9.42 | 1.24 |
| theShippedSurfaceIsUnchanged | 15.09 | 7.31 |
| twistKeepsOneHandAndOneAngleOnEveryStrand | 8.01 | 0.31 |
| MaruGenji…allMaterialGroupsBuildOneRealityKitMesh | 7.90 | 0.29 |
| bothPathsAreDrawnStraightOnAndTurned | 11.04 | 4.72 |
| theRidgeAngleIsIndependentOfTheRadiusAndTheRepeatCount | 6.44 | 0.22 |
| theMeshTheScreenShowsIsTheSameOne | 8.31 | 2.09 |
| everyTriangleFacesOutward ×3 | 6.52 | 0.35 |
| consecutiveTilesMeetOnTheSameSurface | 5.42 | 0.42 |
| meshHasNoEndCapTriangles | 4.20 | 0.02 |
| HiraGenji…allMaterialGroupsBuildOneRealityKitMesh | 4.11 | 0.28 |
| aCameraThatDiscardsBackFacesFindsNoHole | 8.04 | 4.21 |
| theFlatBraidsMeshIsTheShapeItWas | 4.68 | 0.97 |
| theFlatBraidIsDrawnBothWaysAndMeasured | 5.20 | 1.52 |
| hiraGenjiStandsProudOfThePlainOutlineRightRound | 3.75 | 0.09 |
| theDrawnSurfaceFallsAtEveryJoinWithoutReachingTheValley | 3.97 | 0.30 |
| everyRegionCarriesTheRidgeIncludingBothEdges | 7.29 | 3.66 |
| everySurfaceTriangleHasArea | 3.64 | 0.02 |
| meshIsAnOpenRoundedFlatBraidWithEveryRegion | 3.99 | 0.38 |
| theRoundBraidsMeshIsTheShapeItWas | 3.67 | 1.12 |
| theRoundBraidIsDrawnBothWaysAndMeasured | 4.28 | 1.72 |
| theChevronDensityFollowsTheDeclaredAspectAtAnySize ×3 | 8.89 | 6.74 |
| ほか `MaruGenjiSurfaceMeshTests` の 10 件、`RoundTube16StrandTipTests`・`BraidGeneratorCellsFromOccupancyTests`・`UnrolledPatternThumbnailLayoutTests` の各1件 | 各 2.5〜3.0 | 各 0〜0.5 |

伸びたものは3件で、どれも 0.7 秒未満（`colorChangeUpdates…` +0.69、`meshIsFiniteGroupedAndNondegenerate` +0.42、
`theCardShowsWhatTheSolidShows…` +0.36）。前の2つは共有していない生成と最初に作る分で、実行ごとのぶれの範囲である。

### 5. 動かしていないことの確かめ（報告4・5）

**形状ハッシュ**（全件の実行で、どれも通過）:

| 族 | 試験 | 値 |
| --- | --- | --- |
| 丸源氏 | `theRoundBraidsMeshIsTheShapeItWas`、`theMeshTheScreenShowsIsTheSameOne` | `0x13ed_1478_75ce_cc9e`（419,184 頂点） |
| 平源氏 | `theFlatBraidsMeshIsTheShapeItWas`、`theMeshTheScreenShowsIsTheSameOne` | `0x2df5_8dcc_177c_b981`（361,350 頂点） |
| 八つ金剛 S | `RoundTube8SurfaceTests.theMeshIsTheShapeItWas` | `0x089e_1f63_d1f1_6855` |
| 丸四つ | `MaruYotsuTests.theMeshIsTheShapeItWas` | `0x05ee_28f8_d5c8_3939` |
| 江戸八つ | `EdoYatsuTests.theMeshIsTheShapeItWas` | `0x4120_520e_ed66_35d5` |

**八つ金剛 Z と返しには値を固定した試験が無い。**そこで一時的な調べ物（**コミットしていない**。
`.build/task056/probe/`）で、**7つのレシピすべてについて、製品の経路（`BraidFamilyDrawing`）が作る
模様とメッシュの保存されているフィールドを1つ残らず**（位置・法線・接線・UV・色の群・束の番号…）
FNV で要約し、直す前と直した後で比べた。**7レシピと試験用の5つのメッシュ、すべて一致した。**
位置の要約は Z `a26b1ce0d5ad95cd`、返し `942b8a52433b9cb6`（直す前と同じ）。
平源氏を2回作って全フィールドが同じことも、同じ調べ物で見た（`flat16 twice same true`）。
**そもそも製品コードに差分が無い**ので、これは念のための確かめである。

- **件数:** 490 → 490。成功・失敗・スキップも同じ（485・0・5）。スキップ5は `DRAW_SHEETS` のシート
  （機体に変数が無いことを確かめた）。
- **消した試験・`.disabled`・skip:** 無い。**別のテストプランへ逃がしたもの:** 無い。
- **`.timeLimit`・`-maximum-test-execution-time-allowance`:** 付けていない・渡していない。
- **assert:** 1つも書き換えていない。変わったのは「どのメッシュの値を読むか」（自分で作った同じもの
  から、共有されたものへ）と、`twistPhaseFit` が束の頂点をどこから受け取るか（同じ頂点が同じ順で来る）だけ。
- **間引いた標本:** 無い（報告5は該当なし）。
- **番人** `sh Scripts/check-braiding-is-general.sh`: 通過。

### 6. レシピ1つを足したときの増分（報告6）

**「約 9 秒」は増分ではなかった。**試験ごとの時間の和は、Task 054 の最後（479 件）278.4 秒、
Task 009 を合わせた後（490 件）276.9 秒で、**11 件足して 1.5 秒減っている**（ぶれの範囲）。
表の 272 秒（Task 055 の最終）は結果の束が残っておらず確かめられないが、**同じ木を2回流して
280.8 秒と 289.5 秒だった**ので、8 秒の差は起動のぶれ（2節）の内に収まる。

**見積もり方:** レシピを引数に取る試験（`@Test(arguments: BraidMethodCatalog.recipes)` など）で
そのレシピの引数にかかった時間の和に、そのレシピ自身のスイートの時間を足した。

| レシピ | 引数の和 | 自身のスイート | 合計（直す前 → 後） |
| --- | --- | --- | --- |
| 江戸八つ（Task 009） | 0.26 | 0.14 | **0.4 → 0.4 秒** |
| 丸四つ（Task 054） | 0.05 | 0.23 | **0.3 → 0.3 秒** |
| 八つ金剛 S・Z・返し | 3.2〜4.4 | 0〜2.0 | 約 3〜5 秒（カードと立体を突き合わせる試験の引数にも入っているため） |
| 丸源氏・平源氏 | 3.3・4.1 | ― | 製品の経路でメッシュを作る分（2.6・3.6 秒）が大半 |

- **最近足した2つは 0.3〜0.4 秒だった。**次の 8 本・4 本のレシピも、同じ形ならこの程度と見る。
- **増分はこのタスクで縮んでいない。**増分を作っているのは製品の経路で作るメッシュとレシピごとの
  突き合わせで、どちらも共有しない側に入るからである（予言2が外れた理由）。
- **16 本の丸い組を足すと、族のメッシュ1つ（約 2.6 秒）が製品の経路の試験の分だけ加わる。**
  いまの残り 148 秒に対して、どちらでも余裕がある。

### 7. やらなかったこと・残ったこと

- **製品の生成器を速くすること。**許されていたが、目標に届いたので触っていない。見つけた余地は2つ:
  平源氏の `Flat16SurfaceMesh.append` は頂点ごとに法線を2度計算している（巻き方を決めるときと、
  格納するとき。同じ入力の純粋な関数なので1度で足りる）。丸源氏の `appendGrid` は格子の1点の
  座標枠を、そこに接する三角形ごとに（最大6度）計算している。**どちらも出力を1ビットも変えずに
  減らせる見込み**で、アプリの 3D の読み込みも速くなる。やるなら別のタスクにして、この調べ物の
  要約（全フィールド）で前後を比べること。
- **並列**（3.5）。**起動の 84 秒の原因**（2節）。
- 残った上位は、作ること自体が中身の試験（決定性、配色替え、製品の経路）と、描画・光線の試験である。

### 8. 途中で起きたこと

**調べ物の試験が 60 秒の上限で2回打ち切られ、そのたびに `xcodebuild` が戻らなくなった。**
全フィールドの要約を1件の試験でまとめて取っていたのが 60 秒を超えた。打ち切ると `xcodebuild` は
`simctl diagnose` を走らせ、1回目はそれが1時間を超えても終わらなかった。**`simctl diagnose` を
`kill -INT` すると結果を書いて終わった**（先に `xcodebuild` を殺すと結果が書かれない）。
**どちらの回も要約のファイルは打ち切りの前に全行書き終わっていた**（12:13:52 に書き、12:13:55 に
打ち切り）ので、5節の比較はそれを使った。調べ物はあとで 13 件に分けたが、**分けた版は走らせていない**
（製品コードに差分が無いので、走らせても同じ要約が出るだけである）。**打ち切られたのはコミットしない
調べ物だけで、全件の実行（直す前・後）には打ち切りが無い。**`AGENTS.md` の 2 に書き足した。

### 変えたファイル

- 足した: `KumihimoTests/SharedMeshes.swift`、`Scripts/task056/test_times.py`
- 試験（読み手を共有へ替えた）: `RoundTube16SurfaceMeshTests.swift`、`Flat16SurfaceMeshTests.swift`、
  `BraidMeshHashTests.swift`、`BraidScreenChoosesByFamilyTests.swift`、`BraidSideBySideTests.swift`、
  `BraidColourDiagnosisTests.swift`、`BraidOrientationTests.swift`、`BraidGeneratorCellsFromOccupancyTests.swift`、
  `BraidSurfaceWatertightnessTests.swift`、`UnrolledPatternThumbnailLayoutTests.swift`、`RoundTube16StrandTipTests.swift`
- 文書: この指示書、`AGENTS.md`（実測、打ち切り後の止まり方、数え方、共有の決まり）、
  `docs/architecture.md`（テスト方針に1節）、`docs/README.md`
