# Task 029: 平源氏のサムネイルを「一周ぶんの展開図」にする

- 状態: **完了**（2026-09-10）。**029 は 364 通過、029-2 まで入れて 370 通過・0 落ち・2 skip、打ち切り 0 件。** 結果は「029 の結果」と「029-2 の結果」
- 優先度: **高。一覧のカードの見え方**
- 前提: `docs/tasks/028-thumbnails-in-three-dimensions.md`（サムネイルは横長の展開図に戻した。
  左右 1/3・2/3 の構成は取り下げ済み）、`docs/tasks/007g-hira-genji-edge-phase.md`、
  `docs/tasks/007e-hira-genji-braid-fidelity.md`（ピッチ 0.3665）、`docs/architecture.md`

## 直すこと（作者の指示、2026-09-10）

**丸源氏のサムネイルは展開図で一周ぶん（4 面 8 列）すべてが出ているのに、平源氏は表だけしか
出ていない。平源氏でも表裏が出るようにする。**

**セルの縦横比は維持したまま、模様は細かくなる。** 枠の寸法は変えない。一周ぶんが同じ高さに
入るので、そのぶん模様が細かく見える——これは縮尺を変えることではなく、**枠に入れる一周の量を
変えること**である（下の「縮尺は動かない」）。

**判定（作者、2026-09-10）: 縁も出す。** 一周は **表 6・右縁 2・裏 6・左縁 2 ＝ 16 レーン**で
分ける。縁を落として 6:6 で並べる案は採らない。

## どう置くか

### 1. across は「一周」で測る

いまの `Flat16ThumbnailView` は `pattern.patches(in: .front)` だけを描き、表の region の
`u ∈ [0,1]` を枠の高さいっぱいに伸ばしている。**枠の高さを一周ぶんにする。**

**各 region が一周のどこを占めるかは `Flat16SurfaceMesh.arcSpan(of:)` がすでに持っている。**
**計算を二重に書かないこと**——立体と同じ切り方でなければ、展開図は立体の表面を開いたものだと
言えなくなる。

| region | start | length | 一周に対する割合 |
| --- | --- | --- | --- |
| 右縁 | 0.9375 | 0.125 | 2/16。**継ぎ目をまたぐ** |
| 表 | 0.0625 | 0.375 | 6/16 |
| 左縁 | 0.4375 | 0.125 | 2/16 |
| 裏 | 0.5625 | 0.375 | 6/16 |

**縁の 2 レーンは幅方向の 2 列ではなく、厚み方向の表側と裏側である**
（`Flat16SurfacePatternGenerator.occupant` のとおり）。図の上でも 2 本の細い帯に見える。

**表と裏の列は幅方向で同じ位置に来る。** 表のレーン順は織りの列順と逆、裏は同順という対応が
すでに付いている（同じ `occupant`）。**写すだけで図として正しく並ぶので、順番を作り直さない。**

### 2. patch の角を「一周座標」へ写してから layout に渡す

patch の `corners` は region-local である。描く前に一周座標へ写す:

    x' = span.start + x * span.length      （y はそのまま）

**写したあとで `layout.point` と `layout.displacement` を使う。** displacement は角の差から
出ているので、**繊維の斜線（`threadRole` で向きを変えている白い線）も自動で正しい縮尺になる**。
写す前と後を混ぜると、縁だけ斜線が 3 倍傾く。

**`UnrolledPatternThumbnailLayout` には引数を足さない。** across を region の側で写すので、
layout は今のままで足りる。

### 3. 右縁は同じ帯を二度描く

右縁は `x' ∈ [0.9375, 1.0625]` で継ぎ目をまたぐ。**`x'` と `x' - 1` の 2 回描き、枠に切らせる。**
新しいクリップは書かない（枠の外は Canvas が捨てる）。図の上では**上端と下端に半分ずつ**出る。

### 4. 縮尺——layout へ渡す比を「一周に対する比」にする

`pattern.aspectRatio` は**紐の幅**に対する 1 リピートの長さ（4 × 0.3665 ＝ 1.466）である。
一周を高さに載せるので、layout へ渡すのは**一周に対する比**:

    一周に対する比 = pattern.aspectRatio * broadFaceColumnCount / boardPositionCount
                  = 1.466 * 6 / 16 = 0.54975

**数字は書かず、`Flat16SurfacePatternGenerator` の
`broadFaceColumnCount` / `boardPositionCount` から取ること**（どちらも一般の導出から出ている）。
置き場所は `Flat16SurfacePatternGenerator` の `patternAspectRatioRoundTheBraid`。
**`patternAspectRatio`（紐の幅に対する比）は触らない**——mesh の `length()` がそれで長さを
決めている。

これは丸源氏の `RoundTube16SurfacePatternGenerator.patternAspectRatio`（0.65、**一周に対する比**）
と同じ意味の量になる。両族のサムネイルが同じ濃さで並ぶのはそのためである。

## 数（この指示が固定する値）

| 量 | 今 | 直したあと |
| --- | --- | --- |
| 枠の高さが表すもの | 表の幅 | **一周（16 レーン）** |
| layout へ渡す比 | 1.466 | **0.54975** |
| 1 リピートの長さ（高さ 112 pt） | 164.192 pt | **61.572 pt** |
| 枠に並ぶリピート数（幅 361 / 754 pt） | 4 / 6 | **7 / 14** |
| 1 レーンの高さ | 18.667 pt（表 6 列） | **7.0 pt ＝ 112/16。表も縁も同じ** |
| 1 段の長さ | 41.048 pt | **15.393 pt** |
| **セルの縦横比** | **2.199** | **2.199（同じ）** |
| 1 リピートに描く patch | 24（表だけ） | **72（64 ＋ 右縁の 8 を二度）** |
| カード 1 枚の patch | 96 / 144 | **504 / 1008** |

**縮尺は動かない。** セルの縦横比は今 `1.466 × 6 / 4`、直したあと `0.54975 × 16 / 4`——
**同じ 2.199 である**。**どのレーンも高さ 112/16 ＝ 7.0 pt**（糸 1 本ぶん）になるのは、
`arcSpan` が一周を糸の本数で割っているからで、こちらが選んだ値ではない。

**patch の数は 5〜7 倍になる**（表だけ → 一周ぶん、かつリピート数も増える）。
`UnrolledPatternThumbnailLayout.maximumRepeatCount`（64）は、比が 0.54975 だと
**枠の縦横比が 35 を超えるまで効かない**ので、カードでは当たらない。

## 気づいたこと（隠さず書く）

**「表の 6 レーンの弧 ＝ 紐の幅」という取り違えは、いまのサムネイルに既に入っている。**
輪郭（超楕円 exponent 5、幅/厚み 3.3359、半幅 0.72）を実際に測ると **一周 3.4533**、
**表の弧は 0.375 × 3.4533 ＝ 1.295** で、**紐の幅 2 × 0.72 ＝ 1.44 より 10.1% 短い**——
角の丸みが縁の region に入るためである。

**この task はそれを直さない。** 直すと一周に対する比が 1/2.398 ＝ **0.4170** になり、
**セルの縦横比が 2.199 → 2.446 と 11% 変わる**。作者の指示「縦横比は維持」に反するので採らない。
**形の話であり、初期リリースの外である**（`architecture.md`「初期リリースはレシピのある紐に
限る」）。**この 10% は今のサムネイルにも立体にも同じだけ入っているので、この変更で新たに
持ち込むものは何もない。**

**判定を仰ぐ 1 件**——**継ぎ目が右縁の真ん中に落ちる**（`arcSpan` がそう切っている）ので、
右縁は上端と下端に半分ずつ出る。**表・縁・裏・縁と連続して読ませたいなら、across 全体を
1/16 ずらすだけで足りる**（`arcSpan` は触らず、表示側で回す）。**見てから決めること。**

## 触らないもの

`pattern.aspectRatio`、`stitchPitchPerBraidWidth`、`faceStitchLean` / `edgeStitchLean`、
形の定数、`Flat16SurfaceMesh` と `arcSpan`（**読むだけ**）、丸源氏のサムネイル、
`UnrolledPatternThumbnailLayout` の計算と引数、立体プレビューの見え方、
詳細画面のマス目の図（`BraidPatternView`）。

## 検証

**新しいテスト**（`KumihimoTests/FlatUnrolledPatternThumbnailLayoutTests.swift` に足す、
または一周ぶん専用に 1 ファイル）:

1. 一周に対する比が `pattern.aspectRatio × 6/16` で、**0.54975 ± 1e-4**
2. カードの 2 寸法（361×112 / 754×112）で **repeatLength 61.572**、**リピート 7 / 14**
3. **どのレーンも高さが `height/16`**——表の 1 列と縁の 1 レーンを突き合わせる
4. **セルの縦横比が今と同じ 2.199**（縮尺が動いていないことの番人）
5. **4 つの region の across の範囲が `Flat16SurfaceMesh.arcSpan` と一致し、隙間も重なりもなく
   一周を覆う**（長さの合計が 1.0）
6. **右縁が上端と下端の両方に出る**（`x'` と `x' - 1` の両方が描かれ、枠内に見える面積の合計が
   縁 1 本ぶんになる）

**回し方**（`AGENTS.md`「テストの回し方」のとおり）: `-only-testing:KumihimoTests`、
Bash の `timeout` に 300000、`-test-timeouts-enabled YES`
`-default-test-execution-time-allowance 60` `-maximum-test-execution-time-allowance 300`。
**UI テストは既定に含めない**（Task 015 の既知のクラッシュ）。
番人 `sh Scripts/check-braiding-is-general.sh` を通すこと。

**手で確かめる**（Task 015 が自動検証を塞いでいるあいだ。項目は
`docs/tasks/027-4-manual-checks.md` に足す）:

- 一覧のカードで**平源氏の表と裏の両方が出ている**こと
- **矢羽が斜めに歪んでいない**こと（縮尺が縦横で同じであること）
- 縁の 2 本の帯が細く出ていること、継ぎ目の見え方
- ライト／ダーク、既定文字サイズとアクセシビリティ文字サイズ、iPhone と iPad

**完了報告に入れること**: 実測の repeatLength とリピート数（カード 2 寸法）、レーンの高さ、
セルの縦横比、**継ぎ目の見え方（判定を仰ぐ 1 件への材料）**、確認できなかった項目。

## 完了の条件

- 一覧の平源氏のカードが**一周ぶんの展開図**になっている（表 6・縁 2・裏 6・縁 2）
- **セルの縦横比が 2.199 のまま**で、模様が細かくなっている
- across の切り方が `Flat16SurfaceMesh.arcSpan` と一致している（テストで固定）
- ビルド警告なし、ユニット全通、打ち切り 0 件、番人通過
- **この文書に状態と結果を追記した**（消さない。`CLAUDE.md` のとおり）
- `git add -A` を使わず、足したファイルを明示した

## 029 の結果（2026-09-10）

### 直したもの

| ファイル | 何を |
| --- | --- |
| `Kumihimo/Domain/Flat16SurfacePattern.swift` | `patternAspectRatioRoundTheBraid` を足した。`patternAspectRatio × broadFaceColumnCount / boardPositionCount`——**数字は書かず、どちらも導出から取っている。** `patternAspectRatio` は触っていない |
| `Kumihimo/Features/BraidSimulation/Flat16ThumbnailView.swift` | 全 region の patch を描く。`Flat16SurfaceMesh.arcSpan(of:)`（**読むだけ**）で一周座標へ写してから `layout.point` / `layout.displacement` を呼ぶ。**繊維の斜線も写したあとの角から出している** |
| `KumihimoTests/FlatThumbnailRoundTheBraidTests.swift` | 新規。この文書の表の値を固定した |

**`UnrolledPatternThumbnailLayout` は計算も引数も変えていない。** across を region の側で写すので
足りた（指示のとおり）。**丸源氏のサムネイルは触っていない。**

**継ぎ目をまたぐ region は `x'` と `x' - 1` の 2 回描く。** どの region かは**名前ではなく
span から判定**している（`span.start + span.length > 1`）。新しいクリップは書いていない。

### 実測（組み上げたカードの画面から測った）

| 量 | 文書の値 | 実測 |
| --- | --- | --- |
| layout へ渡す比 | 0.54975 | **0.54975**（試験で固定、± 1e-4） |
| 1 リピートの長さ | 61.572 pt | **61.67 pt**（自己相関、iPhone。分解能 1/3 pt） |
| 1 段の長さ | 15.393 pt | **15.33 pt**（iPhone）／**15.50 pt**（iPad。分解能 1/2 pt） |
| 1 レーンの高さ | 7.0 pt | **7.000 pt**（16 本、iPhone・iPad とも） |
| セルの縦横比 | 2.199 | **2.199**（試験で固定） |
| 枠に並ぶリピート数 | 7 / 14 | **7 / 14** |

**枠の実寸は 329 pt（iPhone）と 770 pt（iPad）**で、文書が挙げた 361 / 754 pt とは少し違う
（カードの余白ぶん）。**リピート数は同じ 7 / 14 になる**——`ceil(329/61.572)+1 = 7`、
`ceil(770/61.572)+1 = 14`。

**16 レーンの並びが `arcSpan` どおりであることを画面から確かめた**（レーンの平均色を読んだ）:

    レーン 0        0..7 pt    右縁（下半分）
    レーン 1..6     7..49 pt   表
    レーン 7..8    49..63 pt   左縁
    レーン 9..14   63..105 pt  裏
    レーン 15     105..112 pt  右縁（上半分）

### 継ぎ目の見え方（判定を仰ぐ 1 件。実装していない）

**右縁の 2 レーンは、上端に 1 レーン・下端に 1 レーンとして出る。** `arcSpan` が右縁を
`[0.9375, 1.0625]` と切っているので、継ぎ目はその**真ん中**に落ちる。

そのため、**枠を上から下へ読むと 右縁(半) → 表6 → 左縁2 → 裏6 → 右縁(半) になり、
右縁だけが 2 本続きに見えない。** 左縁は 49..63 pt に 2 本続けて出るので、
**左右の縁が別々の見え方をしている。**

画面では、上端と下端の細い帯は**幅 7 pt で、表・裏のレーンと同じ太さ**である。色は
その位置の糸のもので、細い帯として読める。**歪んではいない。**

**直すなら across 全体を 1/16 ずらすだけで足りる**（`arcSpan` は触らず、表示側で回す）。
そうすると 右縁2 → 表6 → 左縁2 → 裏6 が連続して読める。**作者の判定を待つ。**

### 検証

- **ユニット 364 通過 / 0 落ち / 2 skip、打ち切り 0 件。** 直前の main は 353 / 0 / 2 で、
  **足した 11 件**がこの task のもの。`-only-testing:KumihimoTests`、
  `-test-timeouts-enabled YES`、既定 60 秒・上限 300 秒、UDID 指定、
  `-parallel-testing-enabled NO`。**UI テストは含めていない**（Task 015）
- 番人 `sh Scripts/check-braiding-is-general.sh` 通過
- ビルド **警告 0**

### 確かめていないもの

- **ライト／ダーク、既定文字サイズとアクセシビリティ文字サイズ**——手で確かめる項目に足した
  （`docs/tasks/027-4-manual-checks.md`）。この報告では見ていない
- **実機**は無い（接続されている端末はすべて simulator）

### つまずいたこと（隠さず書く）

**iPad に古いビルドが残ったまま測って、1 段 41.0 pt——修正前の値——を読んだ。**
`launch` が入れ直さずに起動しただけだったためで、`uninstall` してから入れ直すと 15.50 pt に
なった。**同じ数を 2 つの端末で測っていなければ気づかなかった。**

## 029-2: 継ぎ目を region の境目へ移す（作者の判定、2026-09-10。**完了**）

**判定: 回す。** 上から **右縁 2・表 6・左縁 2・裏 6** と、4 つの region が**続きで読める**
ようにする。右縁だけが上下に割れて 2 本続きに見えないのは、展開図として読みにくい。

### 回す量は導出から取る

**across 全体を `1 - arcSpan(of: .rightEdge).start`（＝ 1/16、右縁の半分）だけ回す。**

    x'' = fmod(span.start + rotation, 1) + x * span.length

**数字（1/16）を書かないこと。** 「**右縁の始まりを枠の上端へ持ってくる**」が意図であり、
`arcSpan` から引けばそう書ける。回したあとの並びは

| 枠の上から | region | 範囲 |
| --- | --- | --- |
| 0..14 pt | **右縁 2 レーン** | 0 〜 0.125 |
| 14..56 pt | 表 6 レーン | 0.125 〜 0.5 |
| 56..70 pt | 左縁 2 レーン | 0.5 〜 0.625 |
| 70..112 pt | 裏 6 レーン | 0.625 〜 1.0 |

（高さ 112 pt のとき。**1 レーン 7.0 pt は変わらない。**）

**枠の上端と下端は「裏と右縁の境目」になる。** どこかを切らないと輪は開けないので、
**切る場所を region の真ん中から境目へ移すだけである。**

### 回すのは描画だけ

**`Flat16SurfaceMesh.arcSpan` も mesh も触らない。** 立体の断面のどこに何が乗るかは
紐の側の話で、これは**図をどこで切るか**の話である。回す量はサムネイルの側に名前をつけて
置き、**「図の切り方であって紐の切り方ではない」と一言書くこと。**

**またぐ region を 2 回描く仕組みは消さないこと。** 回したあとは**どの region もまたがない**
ので実際には 1 回ずつになるが、**それは判定であって前提ではない**——`span` から
`start + length > 1` を見る書き方をそのまま残す（レーン数が変われば再びまたぐ）。

### 触れることになるテスト（`KumihimoTests/FlatThumbnailRoundTheBraidTests.swift`）

| テスト | どうなる |
| --- | --- |
| `theSeamFallsInTheMiddleOfTheRightEdge` | **`arcSpan` についての主張はそのまま正しい**（mesh は回さない）。**コメントの「作者の判定待ち」を、判定の記録に書き換える** |
| `theCardDrawsEveryRegionAndTheSeamTwice` | **数が変わる**（1 リピート 72 → 64 の描画）。**名前も変える**——いまは「またぐぶんを 2 回描く」ことを言っている |
| `theRightEdgeAppearsAtBothEndsAndAddsUpToOne` | **回したあとは上下に割れない。** 「右縁が 1 本続きの帯として、上端から edge ぶん占める」に書き換える |
| `theRegionsCoverTheTurnWithNoGapAndNoOverlap` / `aPatchCarriesIntoItsOwnSpan` / `everyLaneIsTheSameHeight` | **回したあとの座標で**同じことを確かめる（隙間なし・重なりなし・レーン 7.0 pt） |

**足すテスト**: 回した並びが**上から 右縁・表・左縁・裏**で、**どの region もまたがない**こと。
回す量が `1 - arcSpan(of: .rightEdge).start` であること（＝ 1/16、ただし式で書く）。

### Task 030 との関係

**独立だが、030 を先に入れるほうがよい。** 回すと**右縁の中央線が枠の中（上から 7 pt）に入る**
ので、**030 の「4 段に 1 本だけ直線」が右縁でも見えるようになる**——いまは枠の縁に載っていて
見えていない。**030 を入れずに回すと、直線の混じる帯が 1 本から 2 本に増える。**

### 検証

`-only-testing:KumihimoTests`、`timeout` 300000、`-test-timeouts-enabled YES` と 60 / 300。
UI テストは含めない（Task 015）。番人 `sh Scripts/check-braiding-is-general.sh`。
**mesh は触っていないので `BraidMeshHashTests` は通ったままのはず**（落ちたら、回す処理が
描画の外へ漏れている）。

**手で確かめる**: カードの平源氏が**上から 右縁・表・左縁・裏**の順に、4 本の帯として
読めること。**上端と下端に細い帯が分かれて出ていないこと。** iPhone と iPad、ライト／ダーク。

**完了報告に入れること**: 回したあとの 4 region の範囲（pt）、1 リピートに描いた patch の数、
書き換えたテストとその理由、この節への結果の追記。

## 029-2 の結果（2026-09-10）

### 直したもの

`Kumihimo/Features/BraidSimulation/Flat16ThumbnailView.swift` **だけ**。

    nonisolated static var seamRotation: Float {
        1 - Flat16SurfaceMesh.arcSpan(of: .rightEdge).start
    }

    let start = (span.start + Self.seamRotation).truncatingRemainder(dividingBy: 1)

**1/16 という数字は書いていない。** `arcSpan` から引いており、意図（「右縁の始まりを枠の
上端へ」）がそのまま式になっている。**`Flat16SurfaceMesh.arcSpan` も mesh も触っていない**
——`BraidMeshHashTests` は通ったままである（回す処理が描画の外へ漏れていない証拠）。

**回すのは図の切り方であって紐の切り方ではない**、と `seamRotation` の doc comment に書いた。

**またぐ region を 2 回描く仕組みは残した。** `start + span.length > 1` を span から見る
書き方はそのままで、**回した結果どの region もまたがなくなっただけ**である。
テスト `noRegionStraddlesTheFrameOnceTheDrawingIsTurned` が「またがない」ことを**判定として**
確かめている（前提にしていない）。

`seamRotation` は `nonisolated` にした。SwiftUI の `View` は main actor 隔離なので、
そのままだとテストから読めず**警告が 8 件出た**。断面の算術だけなのでアクターは要らない。

### 回したあとの並び（iPad の画面から実測、高さ 112 pt）

| 枠の上から | region | 実測 | レーン |
| --- | --- | --- | --- |
| 0..14 pt | **右縁 2 レーン** | **0.0..14.0 pt** | 0..1 |
| 14..56 pt | 表 6 レーン | **14.0..56.0 pt** | 2..7 |
| 56..70 pt | 左縁 2 レーン | **56.0..70.0 pt** | 8..9 |
| 70..112 pt | 裏 6 レーン | **70.0..112.0 pt** | 10..15 |

**指示書の表と一致した。1 レーン 7.000 pt も変わっていない。**
**上端と下端に細い帯が分かれて出ることは無くなった**——枠の両端は「裏と右縁の境目」である。

### 1 リピートに描く patch

**72 → 64。** またぐ region が無くなったので、右縁の 8 を二度描かなくなった。
カード 1 枚では **504 / 1008 → 448 / 896**（7 リピート / 14 リピート）。
**patch そのものは 64 のままで、増減はしていない。**

### 書き換えたテストと、その理由

| テスト | どうした |
| --- | --- |
| `theSeamFallsInTheMiddleOfTheRightEdge` → **`theBraidsOwnCutFallsInTheMiddleOfTheRightEdge`** | **主張は変えていない**（`arcSpan` は回していない）。**名前とコメントを直した**——「作者の判定待ち」を判定の記録に。**これは紐の切り方であって図の切り方ではない**と書いた |
| `theRightEdgeAppearsAtBothEndsAndAddsUpToOne` → **`theRightEdgeIsOneBandFromTheTopOfTheFrame`** | 上下に割れなくなったので、**「上端から edge ぶん 1 本続きの帯」**に書き換え。**面積が 2 レーンぶんであることは残した**（回して増減していないことの番人）。枠の下端が裏の終わりであることも確かめている |
| `theCardDrawsEveryRegionAndTheSeamTwice` → **`theCardDrawsEveryRegionOnce`** | **72 → 64**、カード 1 枚は 504/1008 → 448/896 |
| `theRegionsCoverTheTurnWithNoGapAndNoOverlap` | `arcSpan` の表はそのまま残し、**隙間・重なりの確認を回したあとの座標に**した。**先頭が 0、末尾が 1** も確かめている |
| `aPatchCarriesIntoItsOwnSpan` → **`aPatchCarriesIntoItsOwnBand`** | 回したあとの帯に入ることと、**枠の中に収まる**ことを確かめる |
| `everyLaneIsTheSameHeight` | 回したあとの座標で**16 本の境界を並べ、端から端まで 7.0 pt 刻み**であることを確かめるようにした |

**足したテスト 3 件**: `theDrawingIsTurnedByTheHalfEdgePastTheCut`（回す量が
`1 - arcSpan(of: .rightEdge).start` であり、縁の半分であり、1/16 でもあること）、
`theRegionsComeDownTheFrameInOrder`（上から 右縁・表・左縁・裏 と、pt の範囲）、
`noRegionStraddlesTheFrameOnceTheDrawingIsTurned`。

### 検証

- **ユニット 370 通過 / 0 落ち / 2 skip、打ち切り 0 件。** 直前（030 のあと）は 367 / 0 / 2
- **`BraidMeshHashTests` は通ったまま**——mesh は触っていない
- ビルド **警告 0**（`nonisolated` を付ける前は 8 件）
- 番人 `sh Scripts/check-braiding-is-general.sh` 通過

### 確かめていないもの

- **iPhone の画面**は navigate していない（iPad で測った。割り付けは比なので端末に依らず、
  ユニットが押さえている）
- **ライト／ダーク、文字サイズ**——`docs/tasks/027-4-manual-checks.md` の 3c/4.6 のまま
