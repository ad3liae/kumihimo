# Task 025: 初期リリースの描画（レシピのある紐だけを、それらしく）

- 状態: **025-1（棚卸し）完了**（2026-09-08）。**次は 025-2（レシピの型と模様図）。** 結果は末尾「025-1 の結果」
- 優先度: **最高。Task 020 の本体を製品へ載せる段である**
- 作成日: 2026-09-08
- 前提: **新しいセッションで始めてよい。** 先に読むもの——`CLAUDE.md`・`AGENTS.md`、
  `docs/architecture.md` の「初期リリースはレシピのある紐に限る（作者の決定）」
  「組み台の力学」「正本の読み方」「山は糸の半径から出る」、
  `docs/measurement-procedures.md`（**とくに「5. 構成した紐の読み方」**）、
  `docs/tasks/020-general-braid-simulator.md` の「これまでの誤り」と末尾の里程標、
  `docs/tasks/024-crest-by-half-diameter.md` の末尾「024 を区切る」

## 作者の決定（2026-09-08）

> 初期リリースは、**レシピ（bookC の手順）のある伝統的な紐に限る。**
> **見た目がそれらしく見えればよい。物理シミュレートは要らない。**
> **自分で組み方を編み出す版になったら**、物理（021〜024 の保留分）を**再検討する。**

**したがってこのタスクは、物理を1つも載せずに、紐を描き切るところまでを作る。**

## レシピとは何か（3つそろって1つ）

1. **手順表** — bookC の記法から生成する（Task 020 積1、`BraidDiskNotation`）。
2. **配色** — 糸の位置に色を割り当てたもの。
3. **測った形の値** — 資料の写真と本から測った寸法。
   `tasks/020-general-braid-simulator.md`「測ってある値」の表が出どころである。

**この3つがそろっている紐だけが初期リリースに載る。** そろっていない紐は載せない。
**推定して載せてはならない。**

### 形の値は測定値として持ち込む。導出値と混ぜない

**コードの型が出どころを持つこと。** `BraidCrossSection.Source` が
`.standRim` / `.reference(String)` で出どころを分けているのと同じ形にする。

- **測った値**は `.observed(出どころ)` と明記する。畝の高さ 0.45、断面比 3.3359、
  山形の密度 1.8〜2.15 はこれである。
- **導いた値**は `.derived(...)` と明記する。潰れた断面 w = 面の幅 ÷ 面の糸数、
  t = d²/w はこれである（Task 024）。
- **1手のピッチは `pitchPerStep = .derived(積み重ね模型, k)` とする。**
  **k は数えて出すこと。リテラルで 3 と書かないこと。** 通過する場所にも層を置くと
  平源氏で k = 3 になり、pitch = k·d が実測 0.3665 と +2.3% で合う
  （`tasks/020-general-braid-simulator.md`「導出の前提」）。
  **これが積3 の宙ぶらりんを解く。** 積3 を保留していた理由は「通過する場所にも層が積まれる
  という読みが模型の言葉に無い」ことだったが、**その読みは 024 の構成が実際に使って
  正本と一致している。** よって**読みを型に書いて確定させる。**

**見た目に合わせて数字を動かしてはならない。** 合わないときは、動かすのではなく報告して止まる。

## 作るもの

### 1. レシピ（Recipe）

手順表・配色・形の値を1つに束ねたもの。**組み方の名前を持ってよいのはここだけである。**
置き場所は `Kumihimo/Domain/BraidMethodCatalog.swift` の側。

**受け入れ: レシピを1つ足すのに要るのが、手順表・配色・測った値の3つだけであること。**
導出やレンダラに手を入れなければ足せない、という状態にしないこと。

### 2. 模様図（2D）— 占有履歴から

**面に見えるのは、そこに留まっている糸である**（`architecture.md`「組み台の力学」）。
占有履歴（`Scripts/task021/occupancy.py` が Python で持っているもの）を導出側へ移し、
そこから模様図を描く。

- 平源氏: いまの図を占有履歴由来に置き換える。
- **丸源氏: 新しい図を作る。** 8列は**閉じの対で畳んだ列**で、
  **列の角度は着地する場所の角度**である（`occupancy.closing_columns`）。
  **45° 等分ではない。**（`measurement-procedures.md` 5-3）

### 3. 立体（3D）— 024 の構成から。**Task 020 段階3 である**

`Scripts/task024/build.py` の構成を Swift へ移す。**solver は移さない。**

- **留まりは面の上、渡りは中を通る。**
- **山は面の法線に沿って外へ d/2。** 対ごとに決めない。**上下の取り違えは構成上 0 になる。**
- **山の形は弧、幅は 2√(d²−s²)。複数の山は足さずに各点で最大を採る。**
- **表裏を入れ替わる対は腹の中を ±w/2 で横にすれ違う。**
- **潰れた断面は導出**（w = 面の幅 ÷ 面の糸数、t = d²/w）。**縁と管は潰さない。**
- **長手は k·d。**
- **山の高さは `.observed`（bookA 0.45）を持ち込んでよい。**
  構成そのものは丸で 0.50 d・楕円で 0.375 d を出し、**実測 0.45 を挟んでいる**（024）。

### 4. 描いて読むこと（z バッファ）を Swift へ

`Scripts/task024/render.py` の描き方と読み方を移す。**これが判定の道具である。**
読み方の手順は `docs/measurement-procedures.md`「5. 構成した紐の読み方」に従う。
**新しい読み方を作らないこと。**

## 段階（各段階の終わりに報告して止まる。承認を得てから次へ）

### 025-1: 棚卸し（**docs と Scripts のみ。product code は変更しない**）— **完了**（2026-09-08）

作者が指示した6項目。結果は下の「025-1 の結果」にある。

1. **移すものの一覧。** `Scripts/task020〜024` のうち 025-2 / 025-3 が Swift へ持っていく部品を
   列挙する。部品ごとに**入力・出力・依存・定数**（d だけのはず）を書く。
   **移さないもの**（solver 一式、Jolt harness、`finish.py`）も明記する。
2. **今の product code の棚卸し。** `Kumihimo/Domain/Braiding/`、`BraidMethodCatalog`、
   `BraidPatternFigure`、凍結中の2生成器とその形の値が、025 のどの部品に置き換わるか／残るか。
   **名前の番人が今どこまで見ているか。**
3. **正解データ（fixture）を Python から書き出す。** 占有履歴の表、構成した中心線、
   描いて読んだ結果、断面の数値、長手（k、pitch）。**書式と置き場所を決めて記録する。**
4. **レシピの型の設計だけ書く**（実装は 025-2）。
5. **025-2 と 025-3 の作業単位**を、1コミットずつに切れる粒度で列挙する。
6. **テストの回し方の確認。** product code を触らないのでこの段では回さない。
   **025-2 で回す前提を書く。**

**この段階では product code を変更しない。よってテストは走らせず、その旨を報告に書く。**

### 025-2: レシピの型と模様図（2D）

1. レシピの型を作り、手順表・配色・形の値を束ねる。**出どころの型を入れる。**
2. 占有履歴を導出側へ移し、模様図を描く。**丸源氏の新しい図を含む。**
3. `pitchPerStep = .derived(積み重ね模型, k)`。**k は数えて出す。**
4. **検証**: 平源氏 bookA p97 の3実験、丸源氏 Task 004 の 8×4。**Python と同じ結果になること。**

### 025-3: 立体（3D）— 024 の構成と z バッファ

1. 構成を Swift へ移す。2. 描画と読み取りを移す。
3. **検証**: 025-2 と同じ2つの正本を、**絵から読んで**通すこと。

### 025-4: 凍結中の2生成器の退役

`MaruGenjiSurfaceMeshGenerator` / `HiraGenjiSurfaceMeshGenerator` は凍結中である。

**退役させてよいのは、新旧を並べた図が、資料の写真と本の実験に合ったときだけである。**
並べ方と測り方は `docs/measurement-procedures.md`（1・2・3・4節）に従う。
**「新しいほうが正しいはずだ」で退役させないこと。合わなければ、凍結したまま報告して止まる。**

## 守ること

- **規則を足さないこと。** 説明できない現象が出たら、規則を足さずに報告して止まる。
- **見た目に合わせた定数を置かないこと。** 測定値は `.observed` と明記して持ち込む。
- **承認された設計が破綻したら、代替を作らずに止まって報告すること。**
- **導出（`Kumihimo/Domain/Braiding/`）に組み方の名前を入れないこと。**
  `sh Scripts/check-braiding-is-general.sh` で確かめる。組み方ごとのものは
  `Kumihimo/Domain/BraidMethodCatalog.swift` 側へ置く。
- **物理を載せないこと。** 021・022・023 と 024 の保留分は保留のままである。
- `git add -A` を使わない。**docs / product code / Scripts のコミットは分ける。**
- テストは `AGENTS.md`「テストの回し方」に従う。**打ち切りが起きたら、その旨と上限値を書く。**
  **product code を変更していない段階では、テストを走らせず、その旨を書く。**

## 受け入れ（全体）

1. **レシピを1つ足すのに、手順表・配色・測った値の3つだけで足りる。**
2. **平源氏 bookA p97 の3実験が、絵から読んで両面で通る。**
3. **丸源氏 Task 004 の 8×4 が、絵から読んで 32/32 で通る**（鏡像は一致とみなす。E/W は未決）。
4. **形の値が、測定値か導出値かを型で見分けられる。**
5. **`Kumihimo/Domain/Braiding/` に組み方の名前が無い。**
6. **物理の solver が製品コードに1行も入っていない。**

## 引き継ぐもの・保留するもの

- **引き継ぐ**: Task 024 の「立つもの」6項目（`tasks/024-crest-by-half-diameter.md` 末尾）、
  Task 020 積1 の手順表生成、占有履歴、`measurement-procedures.md` 5節の読み方。
- **保留**: 表面の山どうしの食い込み、交差での局所的な潰れ、横糸の Z 方向の圧縮、
  仕上げの射影（024 の「保留するもの」）、Task 021・022・023。
  **編み出せる版になったら再検討する。**
- **初期リリースの外**: Task 020 の段階4（編み出した組み方の寸法）と段階5（角台）。

---

# 025-1 の結果（棚卸し）（2026-09-08）

**product code は1行も変更していない。よってテストは走らせていない**（回し方は下の6節）。

## 1. 移すものの一覧

**定数は d（糸の直径）だけである。** 下の表に「d 以外の定数」の欄があり、**空でないのは
1行だけ**（面の幅 8 と面の糸数 6。どちらも数えられる量で、較正した数ではない）。

| # | 部品 | いまの場所 | 入力 | 出力 | 依存 | d 以外の定数 |
|---|---|---|---|---|---|---|
| A | bookC の記法から手順表 | **すでに Swift**（`BraidDiskNotation`、Task 020 積1） | ディスクの対の列 | `BraidMethod` | `BraidStand` | 無し |
| B | 占有履歴 | `task021/occupancy.py`（`cycle_moves` `closing_columns` `occupancy` `maru_grid` `hira_lanes` `matches`） | 手順表・環・周期数 | 周期の境目ごとの「場所→留まっている糸」、畳んだ8列、閉じの対 | `braid_geometry.cycles` | 無し |
| C | 積み重ね模型の長手 | `task021/braid_geometry.py`（`occupied_places` `stacks` `lengthwise`） | 手順表・環・畳みの有無 | 場所ごとの層番号、**k**、pitch = k·d | B | 無し |
| D | 断面と畳み | `braid_geometry`（`RING_HIRA` `WIDTH_HIRA` `FACE_HIRA`）／`task024/faces.section` | 環、畳みの有無 | 場所ごとの座標・外向き法線・面の名前 | — | 無し |
| E | 32ノッチと束の入口 | `braid_geometry`（`NOTCHES` `DISK_TO_STAND` `notch_distance` `notch_ring_coordinate` `notch_carries`） | ディスクの手 | ノッチ座標と束の入口の座標（**別の座標系2つ**） | A | 無し |
| F | 構成（留まり・渡り・山・腹のすれ違い） | `task024/build.py`（`build` `pieces` `crest` `hand_over` `side_step`）＋`task023/construct.py`（`trajectories` `normal_at`、`rounds=0`） | 手順表・環・周期数・畳み・潰しの有無 | 糸ごとの折れ線と、各点が留まりか渡りか | C・D・G | 無し |
| G | 楕円の導出 | `task024/faces.flattened` | 面の幅・面の糸数 | w = 幅 ÷ 糸数、t = d²/w | — | **面の幅 8・面の糸数 6**（数える量） |
| H | z バッファの描画 | `task024/render.py`（`frame` `paint` `box_for` `save` `unroll`） | 折れ線・視線・箱・見かけの幅と厚み | 画素ごとの「手前にいる糸」と深さ | F | 画素密度 8/d（**描画の解像度であって形の値ではない**） |
| I | 読み方の5手順 | `render.read_hira` `read_maru` `maru_columns` `maru_rows` `symmetric`＋`occupancy.matches` | H の絵、B の列 | p97 の割合、Task 004 との一致、表裏の対称 | B・H | 無し |

**A はすでに Swift にある。** 025 で新しく移すのは **B〜I** である。

### 移さないもの（**製品コードに1行も入れない**）

| 何 | どこ | なぜ |
|---|---|---|
| 緩和・逐次・与えた長さの solver | `task021/relax.py` `sequential.py` `given_length.py` | 物理。**初期リリースは物理を載せない**（作者の決定） |
| 台の上で組む一式 | `task022/`（`braid.py` `taut.py` `stand.py` `run.py` ほか） | 同上。Task 022 は閉じた記録 |
| Jolt harness | `Scripts/task022/jolt/` | 準静的の決定で採らなかった。**記録として残す**（`architecture.md`「組み上がりの解き方は準静的である」） |
| 向き付き射影・自由化・詰め | `task023/directed.py` `free.py` `settle.py` | 保留（solver の研究） |
| 仕上げの射影 | `task024/finish.py` | **使えない**（022 の内側は球が d 間隔である前提。024 の間隔では成り立たない）。記録として残す |
| 検分・図の道具 | `task024/look.py` `column.py` `crest.py`、`task021/figures.py` `compare.py`、`task022/figures.py` `face.py` `crossings.py`、`task023/figures.py` | **Python のまま残す判定の道具。** 製品には要らない |

## 2. 今の product code の棚卸し

### `Kumihimo/Domain/Braiding/`（一般。**残る**）

| 型 | いまやっていること | 025 でどうなるか |
|---|---|---|
| `BraidStand` / `BraidPosition` / `BraidGroup` / `BraidStands` | 台の位置と並び | **残る。** 部品 E の受け皿 |
| `BraidMove` / `BraidStep` / `BraidMethod` / `BraidStandState` / `BraidCycle` / `BraidWorking` | 手順列と1周期 | **残る。** 部品 A の出力 |
| `BraidCrossSection` / `BraidFace` / `BraidFold` | 環と、環を畳んだ幅・面・縁 | **残る。** **`BraidFold` は幅と面を導出している**——Python が `WIDTH_HIRA` / `FACE_HIRA` という表で持っているものを、Swift はすでに反射から導いている。**ここは Swift のほうが進んでいる。移植は Python → Swift ではなく、Python 側の表を Swift の導出と突き合わせること。** |
| `BraidThreadCourse` / `BraidChord` / `BraidCrossing` / `BraidPatternCell` / `BraidDerivation` | 糸の道すじ、弦、交差、升 | **残るが、面の見えの担当が変わる。** `BraidPatternCell` の上下は**弦モデル**から来ている。**面の見えは占有履歴（部品 B）が答える**（`architecture.md`「組み台の力学」）。弦モデルは**丸源氏で通らないことが分かっている**（`020`「弦モデル」）。**弦は捨てず、占有履歴を隣に足して、面の見えの出どころを占有履歴へ移す。** |

**足りないもの**: 占有履歴（B）、積みの長手と k（C）、構成（F）、楕円（G）、描画（H）、読み（I）。
**`BraidShape` という型は存在しない。** 形の値はいま**2つの生成器の中のリテラル**である（下記）。

### `Kumihimo/Domain/BraidMethodCatalog.swift`（組み方ごと。**残る。ここがレシピになる**）

いま持っているもの: `stand16`、`diskRestingNotches`、`maruGenjiDisk` / `hiraGenjiDisk`（bookC
の記法）、`maruGenji16` / `hiraGenji16`（`BraidMethod`）、両者の `BraidCrossSection`。

**持っていないもの: 配色と、測った形の値。** 025-2 でこの2つを足して**レシピになる。**

### `Kumihimo/Features/BraidPattern/BraidPatternFigure.swift`（模様図。**作り替える**）

- `BraidFigure` / `BraidFigureBuilder.figure(...)`。**平らな紐しか描けない**——
  `guard let fold = derivation.fold` で、**畳めない紐（管）は `nil` を返す。**
  **丸源氏の模様図は存在しない。** 025-2 で新しく作る（部品 B・I）。
- 見えるか潜るかを `BraidPatternCell`（弦モデル）から決めている。**占有履歴へ移す。**

### 凍結中の2生成器と、その形の値（**025-4 まで凍結のまま**）

`Kumihimo/Features/BraidSimulation/HiraGenjiSurfaceMeshGenerator.swift`、
`MaruGenjiSurfaceMeshGenerator.swift`。**`BraidShape` 型は無く、値は `static let` のリテラルで
散らばっている。** 025-3 が置き換える先を書き添える。

| 値 | いまの場所 | 出どころ | 025 では |
|---|---|---|---|
| `widthToThicknessRatio` 3.3359 | Hira 生成器 | **測定**（周長＝16本、厚み＝2本） | **`.observed`** |
| `minimum/maximumWidthToThicknessRatio` 3.1 / 3.7 | Hira 生成器 | 許容帯 | `.observed` の帯として持つ |
| `crestHeightRatio` 0.45 | Hira 生成器 | **測定**（bookA p96） | **`.observed`**。構成は 0.375〜0.50 でこれを挟む |
| `stitchPitchPerBraidWidth` 0.3665 | `HiraGenjiSurfacePattern` | **測定**（bookA p96 / bookB p23） | **`.observed`**。導出は `pitchPerStep = .derived(積み重ね模型, k)` |
| `crestHeightRatio` 0.12 / `patternAspectRatio` 0.65 | Maru 生成器 / `MaruGenjiSurfacePattern` | **積だけが写真に縛られる。個別には未検証**（Task 005J） | **`.observed` だが「積のみ」と明記する。個別の値として使わない** |
| `superellipseExponent` 5、`twistAngleDegrees` 30、`overCrossingLift` 0.16、`underCrossingDip` 0.55、`valleyDepthRatio` 0.03、`boundaryWidth` 0.035 ほか | 両生成器 | **見た目合わせ** | **持ち込まない。** 構成が山と谷を出す |
| `defaultHalfWidth` 0.72 / `defaultRadius` 0.48 | 両生成器 | 表示の大きさ | 表示側の値。形の値ではない |

**見た目合わせの定数を新しい道へ持ち込まないこと。** 持ち込めば 025 の意味が消える。

### 名前の番人が今どこまで見ているか

`Scripts/check-braiding-is-general.sh` は **`Kumihimo/Domain/Braiding/` と
`Kumihimo/Features/BraidPattern/` の2つだけ**を見て、`MaruGenji` / `HiraGenji` を探す。
**いま通る**（`Kumihimo/Domain/Braiding Kumihimo/Features/BraidPattern name no braid.`）。

**見ていないところに 27 の product ファイルが組み方の名前を持っている**——
`Kumihimo/Domain/` 直下の6ファイル（`HiraGenjiWeaveDerivation` `HiraGenjiSurfacePattern`
`MaruGenjiSurfacePattern` ほか）と `Features/BraidSimulation/` の15ファイル、
`Features/ProjectEditor/` の3ファイル、`App` と `BraidStrandSurface`。
**これは違反ではない**（番人の定義どおり、組み方ごとのものは外にある）。
**025-3 で 3D を一般化するとき、`Features/BraidSimulation/` を番人の見る範囲へ入れるかどうかを
決めること。** 025-1 では決めない。**入れるなら、入れた時点で 15 ファイルが引っかかる。**

## 3. 正解データ（fixture）

**書き出しは `Scripts/task025/fixtures.py`。** 置き場所は **`KumihimoTests/Fixtures/`**、書式は
**JSON**（1ファイル1話題、キーは並べ替え済み、小数は6桁）。**Python を2回走らせて同一である
ことを確かめた**（バイト一致）。各ファイルは `made_by` に**どの関数が作ったか**を持つ。

| ファイル | 中身 | 大きさ |
|---|---|---|
| `maru-occupancy.json` | 閉じの対、畳んだ8列とその角度、占有履歴の 8×4、Task 004 の 8×4、一致（32/32、鏡像、回転4、shift 0） | 1.4 KB |
| `hira-occupancy.json` | 環、場所ごとの幅と面、本体の幅（1〜4）、場所ごとの4周期の留まり | 1.3 KB |
| `hira-centrelines-round.json` / `-ellipse.json` | 糸ごとの折れ線と各点の種別（0＝留まり／1＝渡り）、場所の座標と法線、k、pitch、潰した w と t、山の数 | 126 / 137 KB |
| `maru-centrelines-round.json` | 同上（7サイクル） | 327 KB |
| `readings.json` | p97 の3実験を面ごとに（丸・楕円）、表裏の対称、断面（幅・厚み・比、管なら外径）、丸源氏の8方向を着地角と中間角の両方で、行の高さと読み始め | 6.1 KB |
| `observed.json` | **測定値だけ**（3.3359、0.3665、0.45、1.8〜2.15、面の列数 8）と出どころ | 1.0 KB |

**差分テストの条件**（025-2 と 025-3 で使う）:

- **占有履歴の表が桁まで一致すること**（整数。丸めの余地なし）。
- **k と pitch が一致すること**（整数と整数倍）。
- **中心線が 1e-6 d 以内で一致すること。**
- **読んだ結果**: p97 の割合は**画素数まで一致**（同じ解像度なら一致するはず。
  ずれたら**解像度差か読み方の違いであって、形の違いではない**——**まずそれを疑うこと**）。
  Task 004 との一致は **32/32 そのもの**。
- **`observed.json` の値は、コードのリテラルと突き合わせる**（測定値が黙って動いていないこと）。

### 025-2 で最初に確かめること（未検証。ここで止めた）

`Kumihimo.xcodeproj` は **file-system synchronized group** を使っているので、
`KumihimoTests/Fixtures/*.json` は**自動でテストターゲットに入るはず**である。
**確かめていない**（product code を触らない段なのでビルドしていない）。
**025-2 の最初の1コミットで、fixture を1つ読むだけの試験を通すこと。**
入らなければ、`#filePath` からの相対で読む方法へ切り替える。**この判断を先送りしないこと。**

## 4. レシピの型の設計（**実装は 025-2**）

**レシピは3つでできている。** 4つ目が要るようになったら、それは設計が破綻した合図である。

    Recipe
      ├ notation   BraidDiskNotation ... bookC の記法（すでにある）
      ├ colouring  [位置: ThreadColorID]
      └ shape      測った形の値（下記）

### 出どころを型で持つ

`BraidCrossSection.Source` が `.standRim` / `.reference(String)` で出どころを分けているのと
**同じ形にする。**

    enum BraidValueSource
      case observed(String)   // 測った値。出どころの文字列（本・ページ・タスク）
      case derived(String)    // 導いた値。導出の名前

    struct BraidMeasurement       値 ＋ BraidValueSource（＋ 許容帯があれば下限と上限）

- **`.observed`**: 断面比 3.3359、1手のピッチ 0.3665、山の高さ 0.45、山形の密度 1.8〜2.15。
- **`.derived`**: 潰した断面 w = 面の幅 ÷ 面の糸数・t = d²/w、山の高さ d/2、山の幅 2√(d²−s²)、
  **`pitchPerStep = .derived("積み重ね模型", k)`**。
- **`k` は数えて出す。リテラルで 3 と書かない。** 数える場所は部品 C（占有履歴が場所ごとに
  積む層のうち、通過を含めて数える）。**「数えた k を返す」ことを試験で押さえる**——
  fixture の `layers_per_cycle_k` と一致すること。

### 受け入れ

**レシピを1つ足すのに、手順表・配色・測った値の3つだけで足りること。**
導出・図・レンダラのどれにも手を入れずに足せること。**試験で押さえる**——
「架空の紐を1つ、3つだけ与えて足し、模様図が出る」。

## 5. 025-2 と 025-3 の作業単位（1つ＝1コミット）

### 025-2 レシピの型と模様図（2D）

1. **fixture が読めることの確認**（試験1本だけ）。上の 3節の未検証事項を潰す。
2. `BraidValueSource` と `BraidMeasurement` を足す（`Domain/Braiding/`。名前を持たない）。
3. 占有履歴を `Domain/Braiding/` へ（`BraidOccupancy`：周期の境目ごとの場所→糸、
   閉じの対、畳んだ列）。**差分テスト: `*-occupancy.json`。**
4. 積みの長手と **k を数える**（`BraidStacking`）。**差分テスト: `layers_per_cycle_k` と pitch。**
5. `BraidMethodCatalog` に配色と `.observed` の形の値を足し、**レシピの型に束ねる。**
6. `BraidPatternFigure` の面の見えを、弦モデルから占有履歴へ移す。**差分テスト: p97 の3実験。**
7. **丸源氏の模様図を新しく作る**（閉じの対で畳んだ8列、**着地する場所の角度**）。
   **差分テスト: Task 004 と 32/32。**
8. 「3つだけでレシピが足せる」試験を書く。

### 025-3 立体（3D）と z バッファ

1. 断面と畳みから場所の座標・法線・面（部品 D）。**差分テスト: `places`。**
2. 構成の骨（留まりと渡り、`hand_over`、`side_step`）。**差分テスト: 中心線の `kinds`。**
3. 山（法線の向き、弧、最大で重ねる）。**差分テスト: 中心線の座標 1e-6 d。**
4. 楕円の導出（部品 G）。**差分テスト: `flattened` の w と t、楕円版の中心線。**
5. z バッファの描画（部品 H）。**差分テスト: 断面の数値。**
6. 読み方の5手順（部品 I）。**差分テスト: `readings.json` 全部。**
7. 3D 表示へつなぐ（表示の大きさと材質。**形の値は増やさない**）。

### 025-4 退役判定

1. 新旧を並べた図を作る（`measurement-procedures.md` 4節）。
2. 測る（同 1・2・3節）。**合えば退役、合わなければ凍結のまま報告して止まる。**

## 6. テストの回し方（**この段では走らせていない**）

`AGENTS.md`「テストの回し方」に従う。**025-2 で回すときの前提**:

- **既定はユニットのみ**: `-only-testing:KumihimoTests`。**UI テストは含めない**
  （Task 015 の既知のクラッシュ。通しで走らせるたびにどれか1件が落ちる）。
- **時間の上限を毎回明示する**: Bash の `timeout` にユニットのみ 300000 ms。
- **テスト単位の上限**: `-test-timeouts-enabled YES`、`-default-test-execution-time-allowance 60`、
  `-maximum-test-execution-time-allowance 180`。
- **クローンさせない**: `-parallel-testing-enabled NO`、`-destination` は **UDID 指定**、
  `xcrun simctl boot <UDID>` で先に起動しておく。
- **結果を残す**: `-resultBundlePath .build/test-results/025-2.xcresult -quiet`。
- **この機械では `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` が要る。**
- **既知の打ち切り**: `everyRegionCarriesTheRidgeIncludingBothEdges` が2分かかる
  （Task 018、未着手）。**打ち切りが起きたら、その旨と上限値を報告に書く。「テストは通った」と
  書かない。**
- **名前の番人**: `sh Scripts/check-braiding-is-general.sh`。**025-1 の時点で通っている。**

**025-1 では product code を変更していないので、テストは走らせていない。**
