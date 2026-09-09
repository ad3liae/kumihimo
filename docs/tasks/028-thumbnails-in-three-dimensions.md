# Task 028: 一覧のサムネイルを「展開図 + 立体」にする

- 状態: **028-1a 完了**（2026-09-09）。028-1b・028-1c は未着手
- 優先度: **高。一覧を見ただけで色の繰り返しが分かるようにする**
- 前提: `docs/tasks/027-screens-on-recipes.md`（画面は族とレシピに乗った）、
  `docs/architecture.md`「初期リリースはレシピのある紐に限る（作者の決定）」

**一覧「組み方別のシミュレーション結果」のカードを、左 1/3 に展開図・右 2/3 に立体の
描き済み画像にする。** 画面の流れ（丸台で色を選ぶ → 一覧 → 詳細）は変えない。

## カードの構成（作者の指示、2026-09-09）

| 区画 | 中身 |
| --- | --- |
| 左 1/3 | **展開図。** `BraidPatternForRecipe` と同じ図（筒は `BraidTubePatternView`、平は `BraidPatternView` の表だけ）。長手方向は縦。角度の行と未決の注記はサムネイルでは出さない |
| 右 2/3 | **立体の画像。** プレビューと同じ場面を、固定カメラで一度だけ描いたもの。紐は左下から右上へ斜めに画面を横切り、3 リピート以上が見える |
| 下 | 組み方の名前と糸数（今のまま） |

**描き手が無い族は、左は出し、右は「この組み方の立体はまだ描けません」。**

## 028-1a: 場面の切り出し（完了）

**プレビューとサムネイルが同じ場面を描くには、場面が 1 か所になければならない。**
サムネイル用に mesh 生成や場面の組み立てを書き写さない、というのが指示の要点である。

**切り出す前**——`RoundTube16RealityView.Coordinator.buildScene` と
`Flat16RealityView.Coordinator.buildScene` が**同じ場面を二通りに書いていた**。
mesh の作り方（族ごとの drawer）だけが違い、**カメラ・光・並べ方は同じ値の別の写し**だった。

**切り出した後**——`Kumihimo/Features/BraidSimulation/BraidSurfaceScene.swift`。

- `model(for:assignments:)`——**族が drawer を選ぶ。** 組み方の名前は出てこない
- `install(in:family:assignments:)`——mesh を作り、カメラと三灯を置いて `ARView` に立てる
- `retile(_:viewportSize:tileCount:)`——画面を埋めるだけのリピートを端から端へ並べる
- `signature(_:)`——色が変わったかどうかを見る鍵

**カメラと光の値**（切り出しで動かしていない。出どころは Task 019・023 の調整）

| 値 | 数 |
| --- | --- |
| カメラ距離 | 4.4 |
| 縦画角 | π/3（60°） |
| key / fill / rim | 1,500 / 520 / 380 |

**移動でないもの 2 件**（隠さずここに書く）

1. **材質の作り方の引数。** 2 つの族は構造の同じ別々の `Maps` 型を持っている。共有する
   `material` は**3 枚のテクスチャを 1 枚ずつ受け取る**ようにした。一方の族がもう一方の型を
   借りずに済ませるため。**作られる材質は同じ。**
2. **失敗のログ。** 以前は 2 つの category に 4 通りの文言で出ていた。**いまは
   `BraidSurfaceScene` の 1 文で、族と理由を持つ。** 文言は診断であって振る舞いではない。

**確認**——**353 通過・0 落ち・2 skip**（切り出し前の main と同じ）。**打ち切り 0 件**
（上限 300 秒）。番人 `Scripts/check-braiding-is-general.sh` 通過。ビルドは警告なし。

## 028-1b: カード（未着手）

**左 1/3 展開図＋右 2/3 画像。** 画像は画面外の `ARView`（nonAR）を
`snapshot(saveToHDR:completion:)` で `UIImage` にする。**キーは（recipe ID, assignments）で
キャッシュし、色配置が変わったときだけ描き直す。** 描画中は右 2/3 を薄い枠にし、
**左の展開図は先に出す。** 一覧の状態遷移は今の `.calculating` → `.available` のまま。

**画面外 snapshot が使えなかった場合は止まって報告する。** 代替（行ごとに固定カメラの
`ARView` を置く）は判断を待つ。

## 028-1c: 片付け（未着手）

`Flat16ThumbnailView` / `RoundTube16ThumbnailView` / `UnrolledPatternThumbnailLayout` と
そのテストを消す。**028-1b が通るまでは触らない。**

## 触らないもの

描き手（`Flat16SurfaceMesh` / `RoundTube16SurfaceMesh` / `RoundTube16CoreMesh`）、
模様生成器、`BraidPatternForRecipe` の中身、**形の定数**、プレビューの見え方。
