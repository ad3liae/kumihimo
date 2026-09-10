# Task 030: 縁の傾きがリピートの端で消える（4 段に 1 本だけ直線になる）

- 状態: **完了**（2026-09-10）。**367 通過・0 落ち・2 skip、打ち切り 0 件。** 結果は末尾「030 の結果」
- 優先度: **高。一覧のカードで目に見える**
- 前提: `docs/tasks/029-flat-thumbnail-round-the-braid.md`（一周ぶんの展開図。**完了**）、
  `docs/tasks/007g-hira-genji-edge-phase.md`、`docs/tasks/007h-hira-genji-tile-seam.md`

## 症状（作者、2026-09-10）

**平源氏のサムネイルで、矢羽にならず直線が入る場所がある。しかも一定の間隔で繰り返す。
すべて矢羽になるのが正しいはずである。**

## 測った（作者のスクリーンショット、iPad、カードの平源氏サムネイル）

**枠の高さ 223 px（2x）＝ 16 レーン、1 レーン 13.94 px（6.97 pt）**——029 の割り付けは
効いている。**段の継ぎ目は 30.75 px（15.4 pt）ごと**、1 リピート 61.5 pt、
カードに**約 12 リピート**が見えている。ここまでは 029 の表のとおりである。

**おかしいのは縁の帯である。** 上から 8 番目と 9 番目のレーンの境界（＝左縁の中央線）で、
継ぎ目の間隔を測ると

| 位置 | 間隔 |
| --- | --- |
| 継ぎ目 1→2 | 31.0 px |
| 継ぎ目 2→3 | 30.5 px |
| 継ぎ目 3→4 | **24.0 px** |
| 継ぎ目 4→5 | **37.5 px** |

が**4 つ周期で繰り返す**。等間隔なら 30.75 px なので、**4 本に 1 本の継ぎ目だけが
6.75〜7.25 px（0.22〜0.24 段）ずれていない**。**`edgeStitchLean` の 0.24 段は
0.24 × 30.75 ＝ 7.4 px** なので、**ずれていない 1 本は「傾きが効いていない継ぎ目」である**。
**4 段 ＝ 1 リピート**なので、**リピートの継ぎ目のところだけ傾きが消えている。**

## 原因

`Kumihimo/Domain/Flat16SurfacePattern.swift` の `boundary(_:rowCount:offset:phase:)`:

    let leaning = (index > 0 && index < rowCount) ? offset : 0

**位相は端も含めて全ての継ぎ目に効くが、傾きだけがリピートの端で 0 に落とされる。**
Task 007G が「mesh がタイルの外へ持ち出せなかったから端を平らに留めた」名残であり、
**Task 007H が mesh に持ち出させるようにしたときに、位相は直り、傾きは直っていない。**

**`faceStitchLean` が 0 なので面では見えず、`edgeStitchLean` が 0.24 の縁でだけ出る。**
029 で縁を描くようになり、リピートが 4 本から 12 本に増えたので、**いま初めて見えた。
029 が持ち込んだものではない。同じものが 3D の mesh にも入っている**（縁が細いので
気づきにくいだけである）。

**組紐の側にこれを正当化するものは無い。** 傾きは継ぎ目ごとの性質で、4 本に 1 本だけ
違う継ぎ目があるわけではない。**タイルの都合であって、紐の形ではない。**

## 直すこと

**`leaning` の端の例外を消し、位相と同じく全ての index に適用する。**

**タイルは厳密に周期のままである**——`boundary(rowCount) == boundary(0) + 1` が
そのまま成り立つ（位相も傾きも定数の足し算だから）。したがって

- **サムネイル**: 隣のリピートの後端と自分の前端が**同じ形**になるので、噛み合って
  隙間も重なりも出ない。枠の両端に出る半端は枠が切る（029 で 1 リピート余分に置いてある）
- **mesh**: はみ出しは `Flat16SurfaceMesh.append` の `insideRange` が**タイルの両端で切る**。
  **007H が位相で通したのと同じ道である。** 新しい切り方を書かないこと

**もし端の例外を外すと mesh に穴が開くなら、例外を戻さずに止めて報告すること。**
その場合は「何がどう開いたか」がこの task の成果である。

## 触らないもの

`edgeStitchLean` の値 0.24（**未測定なのは別の問題**。この task は値ではなく**周期性**を
直す）、`faceStitchLean` の 0、`longitudinalPhases`、029 の周長の割り付けと縮尺、
丸源氏の側、`UnrolledPatternThumbnailLayout`。

## 通らなくなるはずのテスト（先に書いておく）

**`KumihimoTests/BraidMeshHashTests.theFlatBraidsMeshIsTheShapeItWas`**——頂点数
`366_552` とハッシュ `0x78b4_526d_00e7_4a38` を固定している。**形が変わるのだから
変わって当然である。** 新しい値を測って入れ替え、**旧値と新値の両方をこの文書に残すこと。**
**「同じ形のまま」を主張しているテストなので、黙って更新しない**——なぜ変わってよいのかを
1 行添えること。

通ったままのはずのもの（落ちたら報告）: `BraidSurfaceWatertightnessTests`、
`Flat16SurfaceMeshTests`、`Flat16SurfacePatternTests.everyStitchJoinRunsStraightAcrossItsLane`
（**面だけを見ているので影響を受けない**）、029 の `FlatThumbnailRoundTheBraidTests`。

## 足すテスト

1. **縁の継ぎ目が 4 段とも同じ形**——`.leftEdge` / `.rightEdge` の patch について
   `corners[0].y - corners[3].y`（レーンを横切る傾き）が**全ての row で等しく、0 でない**。
   面の外側レーンについて `everyStitchJoinRunsStraightAcrossItsLane` が既に立てている主張の、
   縁版である
2. **1 リピートがちょうど 1**——縁の region で
   `corners(row: rowCount-1)[1].y - corners(row: 0)[0].y == 1`（各 width 境界ごとに）
3. **直線が 1 本も混ざらない**（029 のテストに足す）——縁の中央線での継ぎ目の間隔が
   **4 本とも等しい**（いまは 1.24 / 1.00 / 1.00 / 0.76 段）

## 検証

`-only-testing:KumihimoTests`、Bash の `timeout` に 300000、`-test-timeouts-enabled YES`
`-default-test-execution-time-allowance 60` `-maximum-test-execution-time-allowance 300`。
UI テストは含めない（Task 015）。`sh Scripts/check-braiding-is-general.sh` を通すこと。

**手で確かめる**（`docs/tasks/027-4-manual-checks.md` に足す）: カードの平源氏の縁の帯に
**直線の継ぎ目が 1 本も混ざらない**こと、3D プレビューの縁が段ごとに同じに見えること、
ライト／ダーク、iPhone と iPad。

**完了報告に入れること**: 直した後の継ぎ目の間隔（4 本ぶん、上の表と同じ測り方）、
mesh の新しい頂点数とハッシュ、落ちたテストとその扱い。

## 完了の条件

- 縁の継ぎ目が**全ての段で同じ傾き**になっている（4 段に 1 本の直線が消えている）
- タイルの周期性が保たれ、mesh に穴が開いていない
- `BraidMeshHashTests` の新旧の値と、変わってよい理由をこの文書に書いた
- ビルド警告なし、ユニット全通、打ち切り 0 件、番人通過
- **この文書に状態と結果を追記した**。`git add -A` を使わない

## 030 の結果（2026-09-10）

### 直したもの——1 行

`Kumihimo/Domain/Flat16SurfacePattern.swift` の `boundary`:

    -   let leaning = (index > 0 && index < rowCount) ? offset : 0
    -   return (Float(index) + phase + leaning) / Float(rowCount)
    +   (Float(index) + phase + offset) / Float(rowCount)

**`edgeStitchLean`（0.24）も `faceStitchLean` も `longitudinalPhases` も 029 の割り付けも
触っていない。** 番人通過。

### 穴は開かなかった

**`BraidSurfaceWatertightnessTests` と `Flat16SurfaceMeshTests` は通ったままである。**
`Flat16SurfaceMesh.append` の `insideRange` がタイルの両端で切っており、**007H が位相で通した
のと同じ道**をそのまま通った。新しい切り方は書いていない。

### 継ぎ目の間隔（作者と同じ測り方。iPad、左縁の中央線＝レーン 7|8 の境界）

| | 直す前 | 直したあと |
| --- | --- | --- |
| 間隔の並び | **38, 31, 30, 24 px** が 4 つ周期 | **31, 31, 31, 31 px**（全部） |
| 最小〜最大 | 23 〜 38 px | **31 〜 31 px** |
| ばらつき | **7.50 pt** | **0.00 pt** |
| 1 段 | — | 31 px ＝ **15.50 pt**（導出値 15.393、2x では 0.5 pt 刻み） |

作者の測定（31.0 / 30.5 / 24.0 / 37.5 px）と**同じ 4 つ周期**で、始まりの位相だけが違う。
**直したあとは 4 本とも等間隔で、直線の継ぎ目は 1 本も無い。**

### 落ちたテストと、その扱い

**指示書は 1 件を予告していたが、実際は 3 件落ちた。** 3 件とも「形は前と同じ」を主張する
pin であり、**形は意図して変えたのだから落ちて当然**である。

| テスト | 旧値 | 新値 |
| --- | --- | --- |
| `BraidMeshHashTests.theFlatBraidsMeshIsTheShapeItWas` | `0x78b4_526d_00e7_4a38` | **`0x53c4_4c9b_835a_e598`** |
| `BraidScreenChoosesByFamilyTests.theMeshTheScreenShowsIsTheSameOne` | 同上（同じ mesh を画面の経路から見ている） | 同上 |
| `FlatPatternUnchangedByTheThumbnailTests.theFlatPatternIsTheOneItWas` | `0xa805_6cdc_c7b8_8a21` | **`0x4d72_b9e3_6b75_b461`** |

**変わってよい理由**（3 件それぞれのテストにも 1 行ずつ書いた）——
**縁の 0 段目と 4 段目の継ぎ目の頂点が `edgeStitchLean` のぶん動いた。それだけである。**
面は `faceStitchLean` が 0 なので 1 頂点も動いていない。**頂点数 366,552 は変わっていない**
（その `#expect` は落ちていない）。patch の数・色・region の割り当ても変わっていない。

**通ったままだったもの**（指示書の予想どおり）: `BraidSurfaceWatertightnessTests`、
`Flat16SurfaceMeshTests`、`Flat16SurfacePatternTests.everyStitchJoinRunsStraightAcrossItsLane`、
029 の `FlatThumbnailRoundTheBraidTests`。

### 足したテスト（3 件）

1. `Flat16SurfacePatternTests.everyJoinAtAnEdgeLeansTheSameInEveryRow`——
   縁の各 lane で `corners[0].y - corners[3].y` が**全ての row で等しく、0 でない**。
   反対側（`corners[1].y - corners[2].y`）も同じ量
2. `Flat16SurfacePatternTests.anEdgeLaneIsExactlyOneRepeatLong`——
   **4 つの region すべて**で、lane の前側・後側とも `最終段の高 − 0 段目の低 == 1`
3. `FlatThumbnailRoundTheBraidTests.theEdgesJoinsAreEvenlySpacedDownTheCard`——
   縁の中央線の**継ぎ目の間隔が 4 本とも 1 段**（以前は 1.24 / 1.00 / 1.00 / 0.76）

### 検証

- **ユニット 367 通過 / 0 落ち / 2 skip、打ち切り 0 件。** 直前は 364 / 0 / 2 で、
  **足した 3 件**がこの task のもの。`-only-testing:KumihimoTests`、
  `-test-timeouts-enabled YES`、既定 60 秒・上限 300 秒、UDID 指定、
  `-parallel-testing-enabled NO`、Bash の `timeout` 300000。**UI テストは含めていない**
- 番人 `sh Scripts/check-braiding-is-general.sh` 通過
- ビルド **警告 0**

### 確かめていないもの

- **ライト／ダーク、文字サイズ、3D プレビューの縁**——`docs/tasks/027-4-manual-checks.md` に
  足した。この報告では iPad の一覧のサムネイルしか見ていない
- **実機は無い**（接続されている端末はすべて simulator）
