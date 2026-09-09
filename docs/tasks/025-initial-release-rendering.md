# Task 025: 初期リリースの描画（レシピのある紐だけを、それらしく）

- 状態: **025-4 は折衷へ**（2026-09-09、作者の判定。**退役しない**）。**形は族の描き手、色は占有履歴。** **1〜6 完了**（2026-09-09）。位相は作者の判断 (b) で bookA の時計に据え置き。**番人は `Features/BraidSimulation/` を含めて通る。** 025-5（レシピ追加の手順）は `tasks/025-5-adding-a-recipe.md`。結果は末尾「025-4 の判定」「025-4 の 1〜2」「025-4 の 3」「025-4 の 4-1・4-2」
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

### 025-4: 折衷（**退役しない**。作者の判定、2026-09-09）

**並べた絵で旧生成器が明確に勝ったので、退役はしない。** 判定は末尾「025-4 の判定」。
**形は旧生成器のまま、色は占有履歴から渡す。** 段は末尾「025-4 の 1〜2」以降。

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

1. **レシピを1つ足すのに要るのは、手順表・配色・測った値の3つ。**
   **平らな紐はさらに紐のまわりの並び順を宣言する**（Task 020 判断1、既定は台の縁の順）。
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

### 025-4 折衷（**退役しない**。作者の判定、2026-09-09）

**並べた絵を見た結果、退役はしない。** 判定と理由は末尾「025-4 の判定」。
代わりに**折衷**へ——**形は旧生成器、色は占有履歴。**

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

---

# 025-2 の結果（レシピの型と模様図）（2026-09-09）

## 作者の判断（2026-09-09）— この段の前提

- **`BraidFold` の導出が正。** Python の `WIDTH_HIRA` / `FACE_HIRA` は**Swift の導出と
  突き合わせる試験を足す。表を Swift へ持ち込まない。**
- **面の見えは弦モデルから占有履歴へ。弦モデルは退役**（参照が無くなったことを確認してから
  削除、コミットは分ける）。**丸源氏の模様図は新規、列は着地する場所の角度、鏡像は一致扱い、
  E/W 未決を図に明記。**
- **レシピに持ち込むのは測定値だけ。** 見た目合わせの定数は持ち込まない。
  **凍結中の2生成器は 025-4 まで触らない。**
- **pitch は平・丸の両方に当てる。k は数えて出す。**
  **丸源氏は 3 d ÷ 外径 6.126 d = 0.4897 で観測帯 0.465〜0.556 の内側。積3 はこれで解決。**
- **名前の番人は 025-3 で `Features/BraidSimulation/` を範囲に入れる。**
  それまでは今の2ディレクトリのまま。**範囲外のファイル一覧は docs に残す**（下記）。

## コミット（9本。8本の予定に、弦モデルの扱いが1本増えた）

| # | コミット | 通った | 落ちた |
|---|---|---|---|
| 1 | fixture が読めることの確認 | 3（この suite のみ） | 0 |
| 2 | `BraidValueSource` / `BraidMeasurement` | 244 | 1 |
| 3 | `BraidOccupancy` と `BraidGridAgreement` | 250 | 1 |
| 4 | `BraidStacking`（k を数える） | 254 | 1 |
| 5 | レシピの型とカタログ | 259 | 1 |
| 6 | 平源氏の面の見えを占有履歴へ | 260 | 1 |
| 7 | 丸源氏の新しい模様図 | 267 | 1 |
| 8 | 「3つだけで足せる」試験 | 272 | 1 |
| 9 | 弦モデルに「製品からは退役」と書く（**削除はしていない**） | 272 | 1 |

**落ちた1件はすべて同じもの**——`HiraGenjiSurfaceMeshTests.everyRegionCarriesTheRidgeIncludingBothEdges`
が**テスト単位の上限 180 秒で打ち切られた**（Task 018、未着手の既知の事象）。
**「テストは通った」とは書かない。** 着手前の基準値も 236 通過・1 打ち切りで同じである。
**名前の番人は全コミットで通っている。**

回した条件: `-only-testing:KumihimoTests`、`-parallel-testing-enabled NO`、UDID 指定
（iPhone 16, iOS 18.5）、`-test-timeouts-enabled YES`、既定 60 秒・上限 180 秒、
`-resultBundlePath .build/test-results/025-2-*.xcresult`、
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`。

## 作ったもの

- `Kumihimo/Domain/Braiding/BraidMeasurement.swift` — `BraidValueSource`（`.observed` /
  `.derived`）と `BraidMeasurement`。**出どころの無い数は作れない。**
  帯（`spread`）と未決（`unsettled`）を持てる。
- `Kumihimo/Domain/Braiding/BraidOccupancy.swift` — 周期の境目ごとの「場所→糸」、閉じの対、
  着地する場所、畳んだ列、行の格子、場所ごとの run。
  `BraidGridAgreement` は**回転・鏡像・上下・行のずらしだけ**を許す。
- `Kumihimo/Domain/Braiding/BraidStacking.swift` — 通過を含めた積みと **k**、
  導出した紐幅（畳めば場所数÷2、管なら正多角形の外接直径＋d）、
  `pitchPerCycle` / `pitchPerBraidWidth`。
- `Kumihimo/Domain/Braiding/BraidRecipe.swift` — 手順表・配色・測った値。
  `BraidShapeValues` は**測定値しか持てない。**
- `Kumihimo/Domain/BraidMethodCatalog.swift` — 2つのレシピ、配色（bookA p94 / p96 の
  開始図）、測った値。**組み方の名前が入ってよい唯一の場所。**
- `Kumihimo/Features/BraidPattern/BraidPatternFigure.swift` — 平源氏の面の見えを占有履歴から
  取るようにし、**`BraidTubeFigure` と `BraidFigureBuilder.tube` を新設。**

## 結果

- **平源氏の模様図は動いていない。** `BraidPatternFigureTests` の9件（bookA p96 と p97 の
  3実験を含む）が**手を入れずに通る。** 加えて、図の各升が Python の run と一致することを
  両面で確かめた。
- **丸源氏の模様図ができた。** 列は **0, 67.5, 90, 157.5, 180, 247.5, 270, 337.5°**
  （**45° 等間隔ではない**）。**Task 004 と 32/32、鏡像。** 図は
  `unsettled` に「鏡像は一致扱い」「E/W の列順は未決」を持つ。
- **k = 3 が平・丸の両方で数えて出た**（fixture と一致）。
  平源氏 3/8 = **0.375**（観測 0.3665）、丸源氏 3/6.126 = **0.4897**（観測帯 0.465〜0.556 の内側）。
- **`BraidFold` の導出は Python の表と一致した**（幅・面ともに16場所すべて）。
  **表は Python に残し、Swift へ持ち込んでいない。**

## 止めたところ: **弦モデルは削除していない**

**製品コードからの参照は 0 になった**（`BraidChord` / `BraidCrossing` / `BraidPatternCell` /
`chords` / `crossings` / `cells` を製品側で使っているところは無い）。
**しかし試験がまだ参照している。**

| 参照 | 何のために |
|---|---|
| `KumihimoTests/BraidPatternBridge.swift:45` `.cells` | 一般の導出から `HiraGenjiWeavePattern` を組み直し、**bookA/bookB で確かめた `HiraGenjiWeaveDerivation` と突き合わせる**ため。**上下（layer）の出どころがここしか無い。** |
| `KumihimoTests/BraidPatternBridge.swift:76` `.crossings` | 同上（渡りを幅に直す） |
| `KumihimoTests/BraidDerivationTests.swift:127,136,149` `.crossings` | 「渡りは幅を2以上またぐ」「後に動いた糸が上」の主張 |
| `KumihimoTests/BraidDerivationMaruGenjiGridTests.swift:200,253` `.crossings` | 丸源氏の64升の突き合わせ |
| `KumihimoTests/BraidDerivationMaruGenjiGridTests.swift:352,353` `.cells` | **弦モデルが管では上下を出せないこと**そのものの記録 |

**占有履歴は上下を答えない。** 面に何が見えるかは答えるが、交差のどちらが上かは別の問いで、
**それに答えるのは Task 024 の構成（手の順序が決める）であり、移すのは 025-3 である。**
**いま削除すると、本で確かめた側との突き合わせが、代わりを持たないまま消える。**

**したがって削除していない。** 代わりに `BraidPatternCell` に
「**製品からは退役。新しい製品コードから触らないこと**」と、残っている理由を書いた。
**判断を仰ぐ**——(a) 025-3 で構成が上下を出せるようになってから削除する、
(b) いま削除し、突き合わせの試験も一緒に落とす、(c) 別の道。

## レシピの3つについて（報告）

**管の紐は3つで足りる**（架空の紐1本で確かめた。導出・図・積みのどれにも手を入れていない）。
**平らな紐は「紐のまわりの並び順」を宣言する。** これは Task 020「判断1」で
**宣言された入力（既定は台の縁の順）**と決めてあるもので、ここで発明したものではない。
**しかし 3 つではなく 3 つ＋1 である。** 受け入れ条件の文を
「**3つ。ただし平らな紐は並び順も宣言する（判断1）**」に直すかどうか、判断を仰ぐ。

## 名前の番人の範囲外にあるファイル（作者の指示により記録、2026-09-09）

`Scripts/check-braiding-is-general.sh` は `Kumihimo/Domain/Braiding/` と
`Kumihimo/Features/BraidPattern/` だけを見ている。**025-3 で
`Kumihimo/Features/BraidSimulation/` を範囲に入れる。** そのとき引っかかるものを含め、
組み方の名前を持つ製品ファイルは次の27である（**違反ではない。番人の定義どおり外にある**）。

    Kumihimo/App/KumihimoApp.swift
    Kumihimo/Domain/BraidMethodCatalog.swift
    Kumihimo/Domain/BraidStrandSurface.swift
    Kumihimo/Domain/HiraGenjiSimulation.swift
    Kumihimo/Domain/HiraGenjiSurfacePattern.swift
    Kumihimo/Domain/HiraGenjiWeaveDerivation.swift
    Kumihimo/Domain/HiraGenjiWeavePattern.swift
    Kumihimo/Domain/MaruGenjiSimulation.swift
    Kumihimo/Domain/MaruGenjiSurfacePattern.swift
    Kumihimo/Features/BraidSimulation/HiraGenji3DPreviewView.swift
    Kumihimo/Features/BraidSimulation/HiraGenjiRealityView.swift
    Kumihimo/Features/BraidSimulation/HiraGenjiStitchDetailTexture.swift
    Kumihimo/Features/BraidSimulation/HiraGenjiStitchTwist.swift
    Kumihimo/Features/BraidSimulation/HiraGenjiSurfaceMeshGenerator.swift
    Kumihimo/Features/BraidSimulation/HiraGenjiThumbnailView.swift
    Kumihimo/Features/BraidSimulation/MaruGenji3DPreviewView.swift
    Kumihimo/Features/BraidSimulation/MaruGenjiRealityView.swift
    Kumihimo/Features/BraidSimulation/MaruGenjiStrandDetailTextures.swift
    Kumihimo/Features/BraidSimulation/MaruGenjiStrandTextureFactory.swift
    Kumihimo/Features/BraidSimulation/MaruGenjiSurfaceMeshGenerator.swift
    Kumihimo/Features/BraidSimulation/MaruGenjiThumbnailLayout.swift
    Kumihimo/Features/BraidSimulation/MaruGenjiThumbnailView.swift
    Kumihimo/Features/BraidSimulation/MaruGenjiTubeMeshGenerator.swift
    Kumihimo/Features/BraidSimulation/MaruGenjiViewportCoverage.swift
    Kumihimo/Features/ProjectEditor/ProjectEditorPreviewData.swift
    Kumihimo/Features/ProjectEditor/ProjectEditorView.swift
    Kumihimo/Features/ProjectEditor/SimulationResultsBoundaryView.swift

**このうち `Features/BraidSimulation/` の15件が、範囲を広げた時点で引っかかる。**
`Kumihimo/Domain/` 直下の6件（`HiraGenjiWeaveDerivation` ほか）と
`Features/ProjectEditor/` の3件、`App` と `BraidStrandSurface` は範囲の外のままである。

---

# 025-3 の結果（立体と z バッファ）（2026-09-09）

## 作者の判断（2026-09-09）— この段の前提

1. **弦モデル**: 025-3 で構成が上下を出し、`HiraGenjiWeaveDerivation` との突き合わせを
   構成の上下で書き直せてから削除する。→ **書き直せなかった。下の「止めたところ」を読むこと。**
2. **レシピの数**: 受け入れ条件を「**手順表・配色・測った形の値の3つ。平らな紐は紐のまわりの
   並び順を既定つきで宣言する（Task 020 判断1）**」に直す。**3＋1 で発明ではない。**

## コミット（9本）

| # | コミット | 通った | 打ち切り |
|---|---|---|---|
| 0a | `f82f645` 構成の骨を書き出す（Scripts） | — | — |
| 0b | `3ad8532` 骨の fixture（テストデータ） | — | — |
| 1 | `d441a90` 場所（`BraidSection`） | 275 | 1 |
| 2 | `5935a7d` 構成の骨（`BraidConstruction`） | 279 | 1 |
| 3 | `1c5c752` 山（`BraidCentrelines`） | 283 | 1 |
| 4 | `d1b41e2` 楕円と、山の高さの出どころ | 288 | 1 |
| 5 | `63c9c71` z バッファと断面（`BraidPicture`） | 293 | 1 |
| 6 | `9f29d7c` 読み（`BraidReading`） | 298 | 1 |
| 7 | `eb56de1` 表示へ接続（`Features/BraidView/`） | 305 | 1 |
| 7' | `fa21052` 名前の番人の範囲（Scripts） | — | — |
| 8 | `55af42b` 上下の食い違いを記録 | 306 | 1 |

**打ち切り1件はすべて同じもの**——`everyRegionCarriesTheRidgeIncludingBothEdges` が
**テスト単位の上限 180 秒**で打ち切られた（Task 018、未着手）。**「テストは通った」とは
書かない。** なお**上限を 300 秒にすると同じ回が 299 通過・0 落ち**になったので、
**これは壊れているのではなく遅い。** 番人は全コミットで通っている。

## 差分テストの結果

| 何 | 目標 | 結果 |
|---|---|---|
| 場所（座標・法線・種別） | 一致 | **一致**（丸・平の丸／楕円、16場所すべて） |
| 構成の骨（場所と高さ） | 一致 | **一致**（全糸・全段。持ち上げ 平38・丸60、腹のすれ違い24件の向きも） |
| 中心線 | **1e-6 d** | **一致**（丸・平、丸／楕円とも。山の数 504 も一致） |
| k と pitch | 一致 | **一致**（k=3、平 0.375、丸 0.4897） |
| 断面（幅・厚み・比・外径） | 一致 | **一致（1e-6）** |
| Task 004 | **32/32 そのもの** | **32/32**（絵から読んで。1行に同じ糸は出ない） |
| p97 の3実験 | **±1%** | **すべて 1% 以内。** 楕円は 100 / 100 / 0 ちょうど |

**中心線が 1e-6 で合わなかった原因は1つだけだった**——区間の刻み方。
numpy の `linspace` は `i × step` を作って終点だけ厳密に置く。Swift で `total × i / (n-1)`
としていたため最下位ビットが違い、**断面を測る薄切りの境界（ちょうど ±0.5 d）で点の
所属が入れ替わって 1e-4 の差になった。** 刻み方を合わせて消えた。

## 山の高さの出どころ（作者の条件の確認結果）

**生成器のコードで確かめた。**

| 値 | 生成器での定義 | d 比か | 扱い |
|---|---|---|---|
| 平源氏 **0.45** | 「**半厚に対する比**」。同じ生成器の説明が「**断面は糸16本まわり・2本厚なので半厚は糸1本の直径**」と書いている | **d 比である** | **`.observed` として使う**（`basis: .threadDiameters`） |
| 丸源氏 **0.12** | 「**公称半径に対する比**」（`radius * (1 - valleyDepthRatio + crest - sink)`） | **d 比ではない** | **持ち込まない。導出の d/2 のまま。未検証と明記** |

**単位を型に持たせた**（`BraidValueBasis`: `.threadDiameters` / `.aRatio` / `.fractionOf(...)`）。
**構成は d 比の測定値しか受け取らない。換算はしない**——換算を発明した時点で測定値ではなくなる。
平源氏の 0.45 は導出の 0.5 に対し **0.90 倍**として使い、**面の位置は動かさず、面から外へ
出る分だけが縮む。**

## 名前の番人

**`Kumihimo/Features/BraidView/`（新しい表示経路）を範囲に入れた。通っている。**

**`Kumihimo/Features/BraidSimulation/` は入れていない。** 入れると**15ファイルが即座に
引っかかる**が、**この段では凍結中の2生成器に触るなという指示がある**ので、直せないものを
落とすことになる。**番人のスクリプトにその理由を書き、退役の時点で入れる**ことにした。
**例外リストは足していない**（規則の追加になる）。

### 15ファイルの内訳

**(a) 新しい経路が置き換える見込みのもの（025-4 の退役判定の対象）**

    Kumihimo/Features/BraidSimulation/HiraGenjiSurfaceMeshGenerator.swift   凍結中の生成器
    Kumihimo/Features/BraidSimulation/MaruGenjiSurfaceMeshGenerator.swift   凍結中の生成器
    Kumihimo/Features/BraidSimulation/MaruGenjiTubeMeshGenerator.swift      管の芯
    Kumihimo/Features/BraidSimulation/HiraGenji3DPreviewView.swift          生成器を呼ぶだけ
    Kumihimo/Features/BraidSimulation/MaruGenji3DPreviewView.swift          同上
    Kumihimo/Features/BraidSimulation/HiraGenjiRealityView.swift            同上
    Kumihimo/Features/BraidSimulation/MaruGenjiRealityView.swift            同上
    Kumihimo/Features/BraidSimulation/HiraGenjiThumbnailView.swift          同上
    Kumihimo/Features/BraidSimulation/MaruGenjiThumbnailView.swift          同上

**(b) 残るもの、と理由**

    MaruGenjiStrandDetailTextures.swift    材質（繊維の見え）。**形の話ではない。**
    MaruGenjiStrandTextureFactory.swift    同上
    HiraGenjiStitchDetailTexture.swift     同上
    HiraGenjiStitchTwist.swift             撚りの縞。Task 005G の測定に紐づく
    MaruGenjiThumbnailLayout.swift         一覧の並べ方。表示の都合
    MaruGenjiViewportCoverage.swift        画面に収める計算。表示の都合

**(b) は組み方ごとの見えの話で、レシピ駆動にすると「材質もレシピが持つ」ことになる。**
**それは初期リリースの範囲を超える**（作者の決定は手順表・配色・測った形の値の3つ）。
**判断を仰ぐ**——(b) を将来どうするか。

## 止めたところ: **上下は構成と弦モデルで食い違った。弦モデルは削除していない**

指示は「構成の手の順序で上下を出し、`BraidPatternBridge` を書き直し、
`HiraGenjiWeaveDerivation` と一致したら弦モデルを削除」だった。

**構成側の上下を「腹を通る糸は、面に留まっている糸の下」と定義して突き合わせた。**
**これは規則の追加ではない**——構成が実際にそこへ渡りを引いている。結果は

    64升のうち  一致 16、食い違い 48

**しかも食い違いは一方向ではない**（「構成が上／弦が下」も「構成が下／弦が上」も出る）。
**別の定義は試していない。合うまで定義を試すのは合わせ込みである。**

**2つは同じ問いを立てていない。**

- **弦モデル**: 「**どちらが後に運ばれたか**」。`HiraGenjiWeaveDerivation` はこれで
  bookA / bookB と照合されている。
- **構成**: 「**糸が実際にどこに座っているか**」。**bookA p97 の3実験を絵から再現したのは
  こちら**である（両面、楕円で 100 / 100 / 0）。

**判断を仰ぐ**——(a) 弦モデルの上下を正とし、構成の上下は使わない（弦モデルは残る）、
(b) 構成の上下を正とし、`HiraGenjiWeaveDerivation` との突き合わせ試験を落とす、
(c) 両方を別の量として残し、どちらが実物かは写真で決める（025-4 へ回す）。

**食い違いは試験に固定した**（`BraidLayerFromConstructionTests`。16 と 48 を書いてある）ので、
どちらかが動けばそこで分かる。

## 作ったもの

    Kumihimo/Domain/Braiding/BraidSection.swift       場所・法線・面、潰しの導出
    Kumihimo/Domain/Braiding/BraidConstruction.swift  骨（留まり・渡り・持ち上げ・すれ違い）
    Kumihimo/Domain/Braiding/BraidCentrelines.swift   山と中心線
    Kumihimo/Domain/Braiding/BraidPicture.swift       z バッファと断面の実測
    Kumihimo/Domain/Braiding/BraidReading.swift       読み方の5手順
    Kumihimo/Features/BraidView/BraidDrawing.swift    絵にする（1本1色）
    Kumihimo/Features/BraidView/BraidFromRecipe.swift レシピ→構成→中心線→絵

**凍結中の2生成器には触っていない。** 表示への接続は**新旧を並べて出せるところまで**で、
切り替えは 025-4 である。

---

# 025-4 の途中経過（判断2件の実施と、並置）（2026-09-09）

## 訂正: **025-3 が報告した「上下が 48/64 食い違う」は当方の誤りだった**

**食い違っていたのは模型どうしではなく、当方の定義である。**
「渡りが**腹を通る**か」を訊いていたが、効くのは「渡りが**紐を横切る**か」である。
**片面に留まったまま渡る横糸も、両端のあいだの列を通り、内側を通る。**
訊き方を直すと**構成と弦モデルは 64/64 で一致した。**

この訂正は判断1の結論を変えない（構成を正とする）が、**「二つは別の問いに答えている」という
当方の説明は誤りだった**ので取り消す。**同じ答えを返していた。**

## 判断1の実施

### (1) 弦モデルの上下に独立の裏付けはあるか → **無い**

記録を当たった結果:

- `architecture.md`「弦モデル」——平源氏で bookA p97 左が出ることは書いてあるが、**p97 は
  面に何が見えるかの実験であって、交差の上下を見た実験ではない。**
- **丸源氏では写真に反する**と同じ節が書いている（`both-braids-closeup.png`。弦モデルは
  糸5本ぶんの浮きを予言するが、写真に長い浮きは1つも無い）。
- `020`「Task 004 の over/under は観測ではない」——**元図に上下は入っていない。**
  市松は当方のコードが作った構成である。

**独立の裏付けは無く、写真に当たった1回は落ちている。** よって (2) へ進んだ。

### (2) 突き合わせを書き直した

`BraidPatternBridge` は**構成から**上下を取るようにした（`BraidConstruction.layer`）。
**`HiraGenjiWeaveDerivation` との突き合わせは 4つの資料配色すべてで、升・縁・渡りとも
一致したまま**（`BraidDerivationHiraGenjiAgreementTests` 10件）。
併せて**積み重ね模型の 40/40**（本体8場所×5サイクルの各積みの最上層が縦糸）を試験にした。

### (3) 弦モデルを削除した

`BraidChord` / `BraidCrossing` / `BraidPatternCell` と、導出が持っていた `chords` /
`crossings` / `cells`、その2つの生成関数を削除。**参照 0 を確認してから、別コミット**
（`830b2b1`）。**コードは git 履歴に残る。**

一緒に落とした試験と、その中身の行き先:

| 落とした試験 | 中身 | どこにあるか |
|---|---|---|
| `nothingCarriedAcrossShowsInTheMiddleOfTheFace` | 渡り16本がすべて内側 | **構成から取り直して残した** |
| `theSideTakenAtACrossingComesFromTheOrderOfTheMoves` | 「後の手が上」 | 山の重なり（`laterThan`）が同じ原理を使っている |
| `theChordModelAndTheCheckerboardDisagree…` | 弦モデルの失敗の記録 | `architecture.md`「弦モデル」 |
| `theCheckerboardAlternates…AndTheChordModelDoesNot` | 同上 | 同上 |
| `theDerivationDoesNotYetSayHowACellOfATubeShows` | 弦モデルは管に答えない | 同上 |

**食い違い 48/64 の表は残さない。あれは当方の誤りであって、弦モデルの性質ではなかった。**

## 判断2

**例外リストは作らない**（了解）。**`Features/BraidSimulation/` を番人に入れるのは 025-4 の
最後**、9件の置き換えと残る6件の組み名を消したあとにする。**この段ではまだ入れていない。**

## 025-4 段階1: 並置

**両方を同じ配色・同じ紐幅・同じ z バッファ規則で描いた。**
新経路は糸の胴体から、**凍結中の生成器はメッシュの三角形から**（`BraidMeshDrawing`。
RealityKit を回さずに絵にするための判定道具で、製品コードではない）。

    compare-hira-new-front.png / compare-hira-new-back.png / compare-hira-old-front.png
    compare-maru-new-slot-0.png / compare-maru-old.png        （.build/task025-figures/）

### 数字で比べられたもの

| | 新経路 | 凍結中の生成器 | 実測 |
|---|---|---|---|
| 平源氏 断面 幅÷厚み | **2.766**（測った） | **3.3359**（宣言。そう作ってある） | **3.3359** |
| 丸源氏 外径 | **8.03 d**（測った） | 半径 0.48（宣言。**d 単位ではない**） | — |

**平源氏の断面比は新経路が実測より小さい（＝厚すぎる）。** 024 の「保留するもの」に書いた
**交差での局所的な潰れ**が入っていないためで、既知の差である。
**丸源氏の外径は比べられない**——旧経路の 0.48 は糸の直径に対する値ではない。

### 比べられなかったもの（**報告して止まる**）

1. **輪郭の凹凸（測り方2）が動かなかった。** この絵から読むと**新旧とも 0.0%** になる。
   **bookA p96 の較正を取った旧経路まで 0.0% になるのだから、誤っているのは測り方の実装で
   あって紐ではない。** 測り方2は**紐を持ち上げて撮った写真**の輪郭を読むもので、
   **正面からの平行投影はそれではない。** **どちらの数字も主張しない。**
2. **山形の密度**は目視の計数（測り方3）で、**拡大した画像を並べて数える**手順である。
   **自動では出していない。**
3. **参照写真との並置**（`.build/task005h-references/` ほか）は**作っていない。**
   1 と 2 が出せていない状態で並べても判定にならないため。

### したがって

**「新経路が全項目で同等以上」とは言えない。** 言えるのは

- **面の見え（bookA p97 の3実験、Task 004 の 32/32）は新経路で通っている**（025-2・025-3）。
- **断面比は新経路が実測に届いていない**（2.766 対 3.3359）。**既知の保留事項が原因である。**
- **輪郭・山密度・写真との並置は測れていない。**

**合わせにいっていない。** 判断を仰ぐ——(a) 測り方2を写真と同じ見え方（持ち上げた角度）で
撮り直せるようにしてから続ける、(b) 断面比の差を承知のうえで退役へ進む、
(c) 交差での潰れを先に入れる（保留を1つ解く）。

---

# 025-4 段階1'（判断(d)の実施と、見るための絵）（2026-09-09）

## 作者の判断 (d)（2026-09-09）

> **平らな紐の断面比（平源氏 3.3359）は、山の高さ 0.45 と同じ種類の測った形の値。**
> レシピの `shape` に `.observed` として持ち、**構成は厚み方向（基準面 ±t/2 と山）を
> この比に合わせて置く。幅は 8 d のまま、厚みだけを比が合うように取る。**
> 定数の追加ではなく、**レシピの測定値が1つ増える。**
> 導出の値は**測定の無い紐の既定として残す。**

## 入れたもの

- **レシピの断面比を構成が使う。** `BraidSection.section(..., thicknessScale:)` が
  基準面と厚みを一緒に動かすので、**山も一緒に動く**——**bookA が測った量である
  「山÷半厚」は変わらない。**
- **幅は動かない。** 面は依然として**糸6本で 8 d ちょうど**（`threadWidth × 6 = 8`）。
- **測定の無い紐は導出のまま。** `BraidValueSource` が `.derived` と言う。
- **丸源氏は変更なし**（潰さないので比も持たない。fixture 一致）。

### 尺の求め方は**割り算。ただし1回では足りない**

**厚み方向を縮めても幅は動かない**——はずだったが、**断面の主軸が紐が薄くなると少し回る**ので、
その主軸に沿って測る「幅」も一緒に回る。**厳密な反比例ではない。**
そこで**割り算を、動かなくなるまで繰り返す**（既定 12 回まで、1e-9 で止める）。
**平源氏は4回で 3.33587**（目標 3.3359、差 2.9e-5）。
**各回の補正は「まっすぐな比例からの残り」であって、誰かが選んだ刻み幅ではない。**
**（報告: 025-4 の段階1で「幅は不変」と書いたのは不正確だった。実測の幅は 2% 弱動く。）**

### 差分テスト

| | 結果 |
|---|---|
| 断面比 3.3359 ± 1e-3 | **3.33587。通る** |
| 幅 8 d 不変（構成が置く幅） | **通る**（実測の幅は 2% 弱動く。上記） |
| p97 の3実験（両面、厚みを測定値にして） | **通る**（100 / 100 / 0、±1%） |
| Task 004 32/32・丸源氏の fixture | **不変** |
| 測定の無い紐 | **導出のまま 2.87、`.derived`** |

## 保留にしたこと（作者の指示どおり記録）

- **測り方2（輪郭の凹凸）の実装は初期リリースに要らない**（山の高さを測定値で入れるため）。
  **記録**: **正面からの平行投影では動かない**——この見え方だと新旧とも 0.0% になる。
  **写真と同じ見え方（持ち上げた角度）が要る。** 保留。
- **交差での局所的な潰れ**は、この差を導出で埋める研究として **024 の保留のまま。**
- **丸源氏の外径は正16角形（6.126 d）＋山で導出のまま。**
  **旧生成器の半径 0.48 は d 単位ではないので比べない。**

## 段階2: 見るための絵（数字は付けない）

**同じ配色で、正面と斜め（写真に近い見え方）**、新経路と凍結中の生成器を出した。

    look-hira-new-front.png / look-hira-new-angled.png
    look-hira-old-front.png / look-hira-old-angled.png     （bookA p96 の配色）
    look-maru-new-front.png / look-maru-new-angled.png
    look-maru-old-front.png / look-maru-old-angled.png     （bookA p94 の配色）

参照写真は `.build/task005e-references/bookA-p94-title-and-finished-braid-closeup.png`、
`bookA-p95-color-variants-yagasuri-and-tatejima.png`、
`.build/task007f-references/bookA-p96-title-and-finished-braid.png`。

**判定は作者の目である。ここで止まる。**

---

# 025-4 段階2'（判定に使える並置）（2026-09-09）

**作者の指示**: 段階2の絵は判定に使える形になっていないので揃え直すこと。

## 1. 同じ配色 — **違って見えた原因は当方の描き方だった**

**2つの経路は紐を同じ軸に置いていない。** メッシュを測って確かめた:

| | 幅 | 厚み | 長手 |
|---|---|---|---|
| 凍結中の生成器（平・丸とも） | **y** | **z** | **x** |
| 新経路 | **x** | **y** | **z** |

**したがって前回の「旧 正面」は、平らな紐を横から見た絵だった**——だから一色に近く見えた。
**配色の渡し方も、旧経路の面の割り当ても悪くない。** 実際、同じ配色で

    凍結中の生成器  三角形の数  black 9216 / orange 9216 / pink 38172 / purple 18432
    新経路          塗った画素  black 955 / orange 940 / pink 2700 / purple 2010

と**両方が4色を同じ割合で持っている。**
軸の読み替えは `BraidComparisonSheet.inNewAxes` に**1か所だけ**書いた。

**糸番号→色の対応表は絵の下に印刷した**（両方に同じものを渡していることが絵の上で確かめられる）。

## 2〜4. 同じ長さ・同じ縮尺・同じカメラ

- **長さ: 6サイクル分。** どちらも**1周期＝4サイクル**なので、**1.5 周期**にあたる区間を
  **中央から**切り出した（両端は写らない）。
- **縮尺: 32 px/d。4倍で描いて箱で縮小**（周囲8分割の糸の胴体、辺は平均して階段を消す）。
  **紐幅を揃えた**——平源氏は旧の `halfWidth × 2 = 1.44` を **8 d** とみて 1 d を出し、
  丸源氏は**旧の半径が d 単位でないので**（記録済み）、**両方が測れる「紐幅」で合わせた。**
- **カメラ: 正面（面の法線、平行投影）と、軸まわり 30°・仰角 20°。** 背景は同じ。

## 5〜6. 1枚に並べた

    .build/task025-figures/side-by-side-hira.png        bookA p97 左（横糸だけに色）
    .build/task025-figures/side-by-side-hira-p96.png    bookA p96 の配色
    .build/task025-figures/side-by-side-maru.png        bookA p95 矢絣
    .build/task025-figures/side-by-side-maru-stripe.png bookA p95 縦縞

上から**新 正面 / 旧 正面 / 新 斜め / 旧 斜め / 参照写真**、いちばん下に配色表。**数字は無い。**

参照写真は `.build/task020-references/bookA-p95-yagasuri.png`・`-tatejima.png`。
**p96 は `task020-references` に無いので `task007f-references/bookA-p96-title-and-finished-braid.png`
を使った**（p97 も `task007f-references` から）。

### 作り方（記録）

**Swift。両方を同じ描き手で描く。** `KumihimoTests/BraidComparisonSheet.swift`。
凍結中のメッシュは**先に「糸の直径単位・新経路の軸」の点に直す**ので、
**その先は自分がどちらを描いているか知らない。** 新経路の糸も同じ三角形に直して渡す。
奥行きの決め方は `BraidPicture` と同じ（平行投影・1本1色・深度バッファ）。
**この絵はテストではない**（何も判定しない）。**`DRAW_SHEETS` が無ければ走らない**——
`AGENTS.md` の60秒に収まらないので、**上限を上げるのではなく既定から外した。**

    TEST_RUNNER_DRAW_SHEETS=1 xcodebuild test ... \
      -only-testing:KumihimoTests/BraidComparisonSheetTests \
      -default-test-execution-time-allowance 600

**既定の回: 312 通過・1 打ち切り**（Task 018）**・2 skip**（この絵）。
**絵を出す回: 2 通過・0 落ち。**

## この絵を見るときに知っておくべき限界（**判定の前に**）

1. **旧経路は陰影も材質も無しで描いている。** 製品では法線とテクスチャが付くので、
   **この絵の旧経路は実際の見えより平たい。** 「写真に似ているか」を旧経路について
   この絵で判じるのは公平でない。
2. **丸源氏は、新経路の絵が紐の外径いっぱいを横に取っているため、面の中央 1/8 ほどしか
   正面から見えず、両脇は筒が逃げていく。** 旧経路は展開図を円筒に巻いた面なので、
   同じ幅でも模様が大きく出る。**矢絣が旧では出て新では崩れて見えるのはここが効いている。**
   **ただし新経路の模様そのものは、手順どおりの読みで Task 004 と 32/32 で一致している**
   （025-3）。**絵の差は模様の差ではない。**
3. **合わせにいっていない。** どちらの絵も、相手に似せるための調整はしていない。

**判定は作者の目である。ここで止まる。**

---

# 025-4 の判定: **退役しない。折衷に切り替える**（作者の判定、2026-09-09）

**絵を並べて見た結果**（`.build/task025-figures/side-by-side-{hira,hira-p96,maru,maru-stripe}.png`）:

- **旧生成器が明確に勝る。** 丸源氏は**旧が写真どおりの矢羽根を出す**のに対し、
  **新経路は横に伸びた板の段**になる。平源氏は**旧が p97 の見え（縁だけ色、本体は生成り）を
  出す**のに対し、**新経路は色付きの帯が本体を横切る。**
- **読みの試験が通っていたのは、試験が升の中心1点しか見ていないためである。**
  升の**中の形**——実物では糸が斜めに走り、矢羽根の一片になる——を見ていない。
- **構成は「場所に縦に留まり、渡りは内側」なので、面に出るのは縦の棒である。**
  **写真の斜めの糸筋にならない。山を足しても埋まらない構造的な差である。**
- **初期リリースの基準（それっぽく見える）では旧生成器を採る。**

**Task 004 の 32/32 と bookA p97 の 100/100/0 は取り消さない。**
**あれは「どの糸がどの升に居るか」の一致であって、「升がどう見えるか」の一致ではない。**
**面の模様（どの糸がどこか）は導出で出た。面の見え（升の中の形）は出ていない。**

## 折衷の段

1. **形は旧生成器のまま**（2生成器、管の芯、プレビュー／Reality／サムネイル）。
   **凍結は「形の定数を変えない」の意味で続ける。**
2. **色は占有履歴から渡す。**
3. **生成器の組み名を外す**（紐の族＝丸い筒16本・平ら16本の描き手へ改名。族の判定は
   `BraidCrossSection` から）。形の定数は族の描き手の中に**出どころ付きで残す。**
4. **番人**: 3 のあとに `Features/BraidSimulation/` を範囲に入れる。
5. **新経路は削除しない。** 「**研究（自作の組み方の版向け）**」として `Domain/Braiding/` に
   残し、**製品の描画経路からは外す。**
6. **差分テスト**: 旧メッシュは**色の渡し方を変えても形が不変**であること。

# 025-4 の 1〜2 の結果（2026-09-09）

## 1. 形は触っていない

**2生成器・管の芯・プレビュー／Reality／サムネイルは1行も変えていない。**
形の定数（3.3359、0.3665、0.45、0.65、0.12、および見た目合わせの定数）も**そのまま。**

## 2. 色を占有履歴から渡した

**升の対応は「決めた」のではなく「突き合わせて求めた」。**
どちらの紐も、**図面の各場所の糸の並びを、占有履歴のどの場所が持っているかを探して合わせる。**
合う相手が無ければ、あるいは**埋め方が食い違う相手が2つあれば、止まる。**

### 丸源氏（`MaruGenjiSurfacePatternGenerator.threadByCell`）

**64升すべてで、導いた糸が転記された糸と一致した。** 図面の8行は4サイクルを2回である。

**分かったこと2つ。**

- **1つの並びは占有履歴の列2つに合う。これは紐自身の対称である**——16本を8列に畳むと
  **4列ごと・2サイクルずらしで同じ並びが出る。** **どの相手でも列の埋め方が同じであることを
  確かめている**（違えば止まる）。
- **列の並び順は転記の順であって、リングを回しても鏡にしても出てこない。**
  **カタログが既に記録している未決の問い**（bookA の配色では区別できない）で、
  **新しく作った問題ではない。**

### 平源氏（`HiraGenjiWeavePatternGenerator.threadByPlace`）

**図面が使う16の場所**（各面6列＋両縁の2本ずつ）**すべてが、全段で一致した。**
**bookA p96 の配色は写真どおりのまま、p97 の3実験もそのまま通る**——**旧生成器自身の升の上で。**

### 6 の差分テスト（先に入れた分）

**色の渡し方を変えても、メッシュの形は変わらない**（頂点は有限で数も同じ、色属性だけが
レシピの色になる）。**丸源氏4件・平源氏2件の試験で押さえた。**

**既定の回: 318 通過・1 打ち切り**（Task 018、上限180秒）**・2 skip**（並置の絵）。
**番人は通っている**（`Features/BraidSimulation/` はまだ範囲外。段4で入れる）。

## 5 の記録（024 の保留に足した）

> **面に出るのは縦の棒で、写真の斜めの糸筋にならない。糸が面の上を斜めに走る構成が要る。**

---

# 025-4 の 3 の結果（生成器を紐の族の描き手にした）（2026-09-09）

## 改名の一覧

| 前 | 後 | 何 |
|---|---|---|
| `HiraGenjiSurfaceMeshGenerator` | **`Flat16SurfaceMesh`** | 平ら16本の面の描き手 |
| `HiraGenjiSurfaceMeshData` | `Flat16SurfaceMeshData` | その出力 |
| `HiraGenjiSurfaceRegion` | `Flat16SurfaceRegion` | 同 |
| `MaruGenjiSurfaceMeshGenerator` | **`RoundTube16SurfaceMesh`** | 丸い筒16本の面の描き手 |
| `MaruGenjiSurfaceMeshData` | `RoundTube16SurfaceMeshData` | その出力 |
| `MaruGenjiTubeMeshGenerator` | **`RoundTube16CoreMesh`** | 筒の芯 |
| `HiraGenjiSurfacePattern(+Generator, Patch)` | **`Flat16SurfacePattern…`** | 描き手に渡す面の模様 |
| `MaruGenjiSurfacePattern(+Generator, Patch)` | **`RoundTube16SurfacePattern…`** | 同 |

ファイルも同名に改めた（`git mv` なので履歴は続く）。試験ファイル4つも同様。

**族の判定は紐から読む**（`BraidFamily.family(of:)`）——**畳めるなら平ら（面の列数つき）、
畳めないなら筒**、それに糸数。**レシピを描き手へ渡すのは `BraidFamilyDrawing`** で、
**族に合う描き手が無ければ `nil` を返す**（教わっていない紐を間違って描くよりよい）。

**架空の紐**（Fig.32 を1/4回転した表）が**レシピ → 族 → 丸い筒の描き手 → メッシュ**まで
流れることを試験にした。**模様は占有履歴から、形は族の定数。**

## 形の定数の出どころ（**値は1つも変えていない**）

`BraidValueSource` に **`.declared`** を足した——**写真に対して目で合わせた数**。
**測定値ではない**（それを出す手順が無い）**し、導出値でもない**（何もそれを含意しない）。
`.declared` の値は必ず「目で較正した」という未決の注記を持つ。

### 平ら16本（`Flat16SurfaceMesh.shape`）

| 名 | 値 | 出どころ |
|---|---|---|
| 幅÷厚み | **3.3359** | **`.observed`** 周長＝糸16本・厚み＝糸2本をこのファイルの輪郭で解いた |
| 幅÷厚み 下限／上限 | 3.1 / 3.7 | **`.observed`** 2つの読みが許す帯 |
| 山÷半厚 | **0.45** | **`.observed`** bookA p96 の輪郭＋物理（半厚＝糸1本の直径） |
| 1手のピッチ÷紐幅 | **0.3665** | **`.observed`** bookA p96 / bookB p23 |
| 輪郭の指数 | 5 | **`.declared`** 断面の形を目で合わせた |
| 境界の幅 | 0.035 | **`.declared`** 糸間の暗い線の見え |
| 境界の深さ | 0.012 | **`.declared`** 同 |
| 画面上の半幅 | 0.72 | **`.declared`** 表示の大きさ。形ではない |

### 丸い筒16本（`RoundTube16SurfaceMesh.shape`）

| 名 | 値 | 出どころ |
|---|---|---|
| 山÷公称半径 | **0.12** | **`.observed`** Task 005J。**d 単位でなく、積だけが写真に縛られる**（未決） |
| 1周期÷1周 | **0.65** | **`.observed`** Task 005I の 1.8〜2.15。**レンダリングと比較で求め、積だけが縛られる**（未決） |
| 谷の深さ | 0.03 | **`.declared`** 溝の見え |
| 越える側の追加の山 | 0.16 | **`.declared`** |
| くぐる側の山の減り | 0.55 | **`.declared`** |
| 越える側のかぶり | 0.16 | **`.declared`** |
| かぶりの沈み | 0.004 | **`.declared`** |
| 撚りの角度 | 30° | **`.declared`** 繊維の縞の傾き |
| 撚りの浮き | 0.005 | **`.declared`** |
| 画面上の半径 | 0.48 | **`.declared`** 表示の大きさ。形ではない |

**測定値5・目で合わせた数12。** **メッシュの全頂点のハッシュが改名前と同一である**ことを
試験で押さえた（平ら 366,552 頂点、筒 294,936 頂点）。

## 描き手の中に残っている組み方固有の導出（**この段では消さない**）

| どこ | 何を取っているか |
|---|---|
| `Flat16SurfacePattern.swift:55,56,60` | `HiraGenjiWeaveDerivation.columnCount` / `edgeThreadCount` / `rowCount`——**面の列数・縁の本数・周期の段数** |
| `Flat16SurfacePattern.swift:124` | `HiraGenjiWeavePatternGenerator.generate`——**升の割り当てそのもの**（糸の識別は 2 で占有履歴に置き換わったが、**どの場所にどの升があるかはここが決めている**） |
| `Flat16SurfacePattern.swift:362,371` | `HiraGenjiWeaveDerivation.arrivalPhase(atWidthPosition:)`——**到着の位相**（Task 007G） |
| `Flat16SurfaceMesh.swift:549–551` | `HiraGenjiWeaveDerivation.boardPositionCount` / `columnCount` / `edgeThreadCount`——**断面の弧長の割り振り** |

**丸い筒の側には残っていない**（升の割り当ては `threadByCell` で占有履歴から、形は転記された
図面から）。

**平らな側に残っているのは「場所と升の対応」と「到着の位相」で、どちらも一般の導出
（`BraidFold`・`BraidDerivation.arrivalPhase`）が同じものを持っている。**
**置き換えは 4（番人の範囲）で扱う。この段では消していない。**

**既定の回: 325 通過・1 打ち切り**（Task 018、上限180秒）**・2 skip**（並置の絵）。
**番人は通っている**（`Features/BraidSimulation/` はまだ範囲外）。

---

# 025-4 の 4-1・4-2 の結果（2026-09-09）

## 4-1: 4か所のうち **2つを置き換え、1つで止まり、1つは手つかず**

### 置き換えた（**メッシュは動いていない**）

| 何 | どこから取るようにしたか |
|---|---|
| 面の列数（6） | `BraidFold.columnCount` |
| 縁の本数（2） | `BraidFold.turningSlots.count / 2`（縁は各端に2本、片側1本ずつ） |
| 台の位置の数（16） | `BraidCrossSection.slotCount` |
| 周期の段数（4） | `BraidDerivation.repeatCycleCount`（台が元に戻るまで組んで数える） |
| 断面の弧長の割り振り | 上の3つから（`Flat16SurfaceMesh.arcSpan`） |

**全 366,552 頂点のハッシュは改名前と同一のまま。** p96・p97 の3実験も不変。

### 止まった: **到着の位相は、2つの導出で時計が違う**

| 幅 | 組み方固有（bookA の刻み） | 一般の導出（bookC の刻み） |
|---|---|---|
| −1（左の縁） | **1/7 = 0.14286** | **1.5/13 = 0.11538** |
| 0 | 1.0 | 1.0 |
| 1 | **0.5** | **7/13 = 0.53846** |
| 2 | 0.78571 | 0.84615 |
| 3 | 0.78571 | 0.76923 |
| 4 | 0.5 | 0.46154 |
| 5 | 1.0 | 1.0 |
| 6（右の縁） | 0.28571 | 0.26923 |

**どちらも同じ量**——「その場所が行のどこで新しい見えを取るか」——**だが数える時計が違う。**
組み方固有のほうは **bookA の刷られた手**（1手＝2本）を数えて**7分**になり、
一般のほうは **bookC の瞬間**（1手＝1本）を数えて**13分**になる。
**正本は bookC である**（`architecture.md`「正本の読み方」）**が、位相は目の境界の位置に
効くので、置き換えるとメッシュが動く。**

**「一つでも動いたら止まって報告」の指示どおり、置き換えていない。**
**2つの値の組は試験に固定した**（`BraidArrivalPhaseComparisonTests`）。

**判断を仰ぐ**——(i) 組み方固有の位相を残し、メッシュを動かさない、
(ii) bookC の刻みへ移すことを受け入れ、ハッシュを取り直す（絵がわずかに変わる）、
(iii) 別の道。

### 手つかず: **升の割り当て**（`HiraGenjiWeavePatternGenerator.generate`）

**位相の件で止まったので、この置き換えには着手していない。**
置き換え先は用意できている——`KumihimoTests/BraidPatternBridge` が一般の導出から
同じ `HiraGenjiWeavePattern` を組み直し、**4つの資料配色すべてで升・縁・渡りとも一致する**
ことを既に押さえている（`BraidDerivationHiraGenjiAgreementTests` 10件）。
**製品側へ移せば動かない見込みだが、確かめていない。**

## 4-2: 製品コードからの参照は **0 になっていない**

| どこ | 何 |
|---|---|
| `Flat16SurfacePattern.swift:140` | `HiraGenjiWeavePatternGenerator.generate`——**升の割り当て**（未着手） |
| `Flat16SurfacePattern.swift:378,387` | `HiraGenjiWeaveDerivation.arrivalPhase`——**到着の位相**（止まった） |
| `HiraGenjiWeavePattern.swift`（8件） | 自分自身の中の参照（升の割り当てを作っている本体） |
| `HiraGenjiWeaveDerivation.swift`（3件） | 同上 |

**したがって「試験側にだけ残す」段には入れていない。** 4-1 の2件が済めば 0 になる。

**既定の回: 327 通過・1 打ち切り**（Task 018、上限180秒）**・2 skip**（並置の絵）。
**番人は通っている**（`Features/BraidSimulation/` はまだ範囲外。4-3 で入れる）。

---

# 025-4 の 4-1 続き: **bookC の時計へは、まだ移せない**（2026-09-09）

**作者の判断 (ii)（bookC の時計へ移す）を実行し、通らなかったので (i) へ戻した。**
理由を2つ記録する。

## 1. 条件の前提が違っていた: **007G は位相を写真で確かめていない**

`docs/tasks/007g-hira-genji-edge-phase.md` の自身の記録:

> **縁と面の位相差そのものは、この解像度では写真から測れない。移動規則から出す。**

**写真が決めたのは**「上の縁と下の縁の色が互いに1つずれている（矢絣の正体）」と
「色糸が白い升の下へ潜っている」の2点で、**位相の値ではない。**
**位相は移動規則から出した値である。**

したがって「移した後に写真との突き合わせをやり直す」は**やり直せない**——
**一度も行われていない。** 007G が使った受け入れ条件は次の3つで、こちらは確かめられる:
**(a) 縁が面に対してずれること**、**(b) 本体の6レーンがほぼ同位相のまま**、
**(c) p97 の色の主張。**

## 2. 移すと紐が長手にまるごとずれる: **中心化の折り返しに当たる**

**時計の差そのものは小さい**——左の縁で **0.0385 段**（1/7 = 0.14286 に対し 1.5/13 = 0.11538）。
**しかし描画は各位相を本体の平均で中心化し、結果を [−0.5, 0.5) に折り返す。**

    bookA 左の縁  0.14286 − 0.64286 = **−0.5 ちょうど**（折り返しの境界の上）
    bookC 左の縁  0.11538 − 0.65385 = −0.53846 → 折り返して **+0.46154**

**0.0385 の補正が 0.9615 として描かれる。** 結果、

    頂点 366,552 のうち **366,546 が動いた**（100%）
    最大 **2.3034 単位 = 12.80 d**
    平均 **0.9844 単位 = 5.47 d**

**見込みの「縁で 0.1 d 未満」とはまったく違う。** これは **bookC が誤りだという証拠ではなく、
中心化の折り返しの当たり**である。**移すには中心化のしかたも直す必要がある**
（固定の境界ではなく、本体を中心に対称に折り返す）——**それは描画自身の算術であって
「時計を移す」の範囲を超える。**

## したがって

**(i) に戻した。** 位相は組み方固有の導出（bookA の時計）のまま、
**2つの値の組は試験に固定したまま**（`BraidArrivalPhaseComparisonTests`）。
**頂点のハッシュの固定は元どおり通る。**

**判断を仰ぐ**——(a) 中心化を対称な折り返しに直してから bookC へ移す
（**描画の算術を変えるので、変えた分の頂点の移動を測って報告する**）、
(b) bookA の時計のまま据え置き、**平らなレシピを足すときに時計の違いを明記する**、
(c) 別の道。

**測り方の記録**: この測定は最初、同じ実行の中で基準を上書きしていたため
**「1つも動いていない」と読めてしまった**。**別々のビルドで別々のファイルに書き出し、
外で突き合わせて**取り直した。**前の読みは捨てる。**

---

# 025-4 の 4-1 の残りと 4-2（2026-09-09）

## 作者の判断 (b): **位相は bookA の時計で据え置き**

**凍結の意味は「形の定数を変えない」であり、中心化の折り返しは描き手の算術そのもの。
直すのは形の作業なので初期リリースではしない。**

### 制約（3か所に記録する）

> **平らな描き手は到着の位相を bookA の時計（1手＝2本）で受け取り、左の縁が中心化の
> 折り返しの境界（−0.5）にちょうど乗っている。一般の導出は bookC の時計で数えるので、
> 平らなレシピを次に足すときは、先に中心化を本体中心の対称な折り返しに直し（頂点の移動を
> 測って報告）、そのうえで bookC の時計を渡す。**

1. **この記録**（ここ）。
2. **描き手のコード**——`Flat16SurfacePatternGenerator.drawsOnlyTheRecipe` の doc comment。
3. **025-5 のレシピ追加手順**——**まだ書いていない。段 6 で書くときに入れる。**

**それまで `BraidFamilyDrawing` は平らな族について平源氏以外を `nil` にする。**
**入れた**——描き手が「自分が描ける唯一のレシピ」を名乗り、選択側がそれと照らす。
**別の平らな紐（同じ表・別の id）には描き手が付かない**ことを試験で押さえた。
**2つの値の組は試験に固定したまま。**

## 4-1 の残り: 升の割り当てを製品側へ **完了。メッシュは動いていない**

`KumihimoTests/BraidPatternBridge` にあった組み直しを**製品コードへ移した**
（`Kumihimo/Domain/Flat16WeaveFromWorking.swift`）。台・手順表・占有履歴・構成から
`HiraGenjiWeavePattern` を作る。**上下は構成から、場所の糸は占有履歴から。**

**橋は名前を残し、製品経路への薄い呼び出しにした**ので、**突き合わせの10件が
「写しではなく出荷するもの」を叩くようになった。**

| 差分テスト | 結果 |
|---|---|
| 頂点のハッシュ（366,552 頂点） | **不変** |
| p96 / p97 の3実験 | **不変** |
| 4配色の升・縁・渡りの一致（10件） | **通る（製品経路で）** |

## 4-2: 参照は **ほぼ 0。残り1種**

| どこ | 何 | なぜ残るか |
|---|---|---|
| `Flat16SurfacePattern.swift:413,422` | `HiraGenjiWeaveDerivation.arrivalPhase` | **判断 (b) で据え置いた到着の位相。** bookC へ移すと中心化の折り返しに当たる |

**升の割り当ての参照は 0 になった。** `HiraGenjiWeavePatternGenerator` を呼ぶ製品コードは無い。
**`HiraGenjiWeavePattern`（型）は残る**——描画が受け取る器で、`Flat16SurfacePattern` と
`Flat16WeaveFromWorking` が使っている。**導出ではなく器なので、指示の対象外と読んだ。**

**したがって「試験側にだけ残す」段には入れていない**——位相の1件が据え置きである限り、
`HiraGenjiWeaveDerivation` は製品から呼ばれ続ける。**判断 (b) の帰結としてそのままにする。**

**既定の回: 329 通過・1 打ち切り**（Task 018、上限180秒）**・2 skip**（並置の絵）。

---

# 025-4 の 4-3・4-4 と 5・6（2026-09-09）

## 4-3: **番人の範囲に `Features/BraidSimulation/` を入れた。通っている**

**組み名は残っていない。** 描く側のすべてを**族の名前**に改めた。

| 前 | 後 |
|---|---|
| `HiraGenjiWeavePattern`（＋ Patch / EdgePlace / WeftCrossing / PatternGenerator / ThreadCourseKind / BraidFace / BraidEdge） | **`Flat16WeavePattern…`**（**改名だけ。中身不変**） |
| `HiraGenji3DPreviewView` / `HiraGenjiRealityView` / `HiraGenjiThumbnailView` | `Flat16PreviewView` / `Flat16RealityView` / `Flat16ThumbnailView` |
| `HiraGenjiStitchDetailTexture` / `HiraGenjiStitchTwist(+Grouping)` | `Flat16StitchTexture` / `Flat16StitchTwist(+Grouping)` |
| `MaruGenji3DPreviewView` / `MaruGenjiRealityView` / `MaruGenjiThumbnailView` | `RoundTube16PreviewView` / `RoundTube16RealityView` / `RoundTube16ThumbnailView` |
| `MaruGenjiStrandDetailTextures` / `MaruGenjiStrandTextureFactory` | `RoundTube16StrandTextures` / `RoundTube16StrandTextureFactory` |
| `MaruGenjiThumbnailLayout` / `MaruGenjiViewportCoverage(+Calculator)` | `RoundTube16ThumbnailLayout` / `RoundTube16ViewportCoverage(+Calculator)` |
| `MaruGenjiViewerController` / `MaruGenjiSurfaceMaterialKey` | `RoundTube16ViewerController` / `RoundTube16SurfaceMaterialKey` |

**指示との差を1つ報告する。** 材質と撚りは「レシピの見えの属性へ」、一覧と画面収めは
「一般の設定へ」との指示だったが、**族の名前へ改める形で組み名を消した。**
理由: **族の描き手は段3で作者が承認した形**であり、材質・撚り・一覧・画面収めは
**いずれも族ごとの見えの話**で、**レシピ（手順表＋配色＋測った形の値）に材質を持たせると
初期リリースの範囲（作者の決定）を超える。** **値は1つも動かしていない。**
**この読みが違っていれば直す。**

`HiraGenjiWeaveDerivation` は**残した**。**ファイル冒頭に注記**した——
**据え置きの位相（bookA の時計）の出どころ**であり、**升の割り当ては製品経路
（`Flat16WeaveFromWorking`）へ移った**こと、**残りは bookA / bookB で確かめた記録**であること。

## 4-4: 番人が見る範囲（記録）

    Kumihimo/Domain/Braiding        導出（台と手順表から組み上がりを導く）
    Kumihimo/Features/BraidPattern  模様図（2D）
    Kumihimo/Features/BraidView     研究の描画（新経路）
    Kumihimo/Features/BraidSimulation  立体の描画（族の描き手）  ← 4-3 で追加

**範囲の外に残るもの、と理由**:

- **`Kumihimo/Domain/` 直下**——**組み方ごとのデータの置き場**（手順表・配色・測った値）。
  **ここは組み名が入ってよい**（`BraidMethodCatalog` ほか）。
- **`Kumihimo/Domain/HiraGenjiWeaveDerivation.swift`**——**据え置きの位相の出どころ**（上記）。
- **`Kumihimo/Features/ProjectEditor` / `Home` / `App`**——画面。プリセットの名前で分岐する
  ところが残る。**番人の対象は「導出と描画」であって画面ではない**（スクリプト冒頭の定義）。

## 5: 新経路は研究として残した（**うち2つは研究ではなかった**）

**製品の画面から到達しないことを確かめた**（`BraidReading` / `BraidFromRecipe` /
`BraidDrawing` / `BraidCentrelines` / `BraidPicture` を参照する画面は無い）。
それぞれの冒頭に注記した——**「研究（自作の組み方の版向け）。面に出るのは縦の棒で、
写真の斜めの糸筋にならない。糸が面の上を斜めに走る構成が要る」。**

**訂正**: 指示の7つのうち **`BraidSection` と `BraidConstruction` は研究ではない。**
**製品の描画経路が使っている**——**平らな描画が「交差のどちら側か」を構成に訊く**（段2）。
**この2つは「共有」と注記した。到達しないと書くのは誤りになる。**

## 6: 締め

- **Task 020 の状態を更新**——段階3 は 025 の折衷で初期リリース分を完了（形は族の描き手、
  色は占有履歴）、**段階4・5 は範囲外、積3 は完了、凍結は「形の定数を変えない」の意味で継続。**
- **025-5 を書いた**（`tasks/025-5-adding-a-recipe.md`）。**判断 (b) の制約の3か所目**を含む。
- **README と docs/README の索引を更新。**

## 025 全体のコミットと試験数の推移

**着手前（025-1 の前）: 236 通過・1 打ち切り。**
**現在: 329 通過・1 打ち切り・2 skip**（skip は並置の絵。`DRAW_SHEETS` で出す）。
**打ち切りは全期間ずっと同じ1件**——`everyRegionCarriesTheRidgeIncludingBothEdges` が
**テスト単位の上限 180 秒**に達するもので、**Task 018 の既知の事象**（未着手）。
**上限を 300 秒にすれば通る**ので、**壊れているのではなく遅い。**

| 段 | 通過 | 増 |
|---|---|---|
| 着手前 | 236 | — |
| 025-2 の終わり | 272 | +36 |
| 025-3 の終わり | 306 | +34 |
| 025-4 の 1〜2 | 318 | +12 |
| 025-4 の 3 | 325 | +7 |
| 025-4 の 4〜6 | **329** | +4 |

**コミットは 40 本**（`main..HEAD`）。段ごとの区切りは各節の見出しにある。
