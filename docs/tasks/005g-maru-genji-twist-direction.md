# Task 005G: 撚りの縞を山形の方向ごとに正す（丸源氏16本）

- 状態: Ready
- 優先度: 高（Task 008 以降より先に着手する）
- 作成日: 2026-09-04
- 前提: `docs/tasks/005f-maru-genji-surface-aspect.md` がマージされていること
- 元タスク: `docs/tasks/005e-maru-genji-braid-fidelity.md`
- 仕様: `docs/specifications/project-editor.md`
- 参考資料: `.build/task005e-references/`, `.build/task005f-screenshots/`（いずれもGit管理外）

## 目的

撚りの縞が、2つの山形方向で別々の角度に見える状態を解消する。実物の組紐は、すべての糸が同じ撚り角・同じ向きで撚られており、方向によって縞の傾きが変わることはない。

模様（どの位置の糸がどのパッチを占めるか）、断面の丸み、交差の上下関係、谷の陰影、アスペクト比は変更しない。変えるのは撚りの縞の当て方だけである。

## 確認された事実

### 現象

Task 005F 完了時点の実測で、撚りの縞角度は次のようになっている。

| | 方向A | 方向B |
| --- | --- | --- |
| Task 005E 時点 | 26.4度 | 34.6度 |
| Task 005F 時点 | 20.1度 | 53.8度 |

`twistAngleDegrees` の設定値は30度である。撚りの向き（ハンド）は全ストランドで一致しており、そこは正しい。

Task 005F でアスペクト比を1へ直した結果、2つの山形方向が世界座標で直交するようになり、方向ごとのずれが広がった。

### 原因

`MaruGenjiSurfaceMeshGenerator.twistCoefficients(for:radius:length:repeatCount:)` は、全ストランドで共有する単一の `TwistCoefficients(phasePerAlong:phasePerAcross:)` を返す。`phasePerAlong` は定数だが、`phasePerAcross` は本来ストランドごとに必要な値が異なるため、現在は全セグメントの平均を採っている。

縞の見た目はテクスチャ（`MaruGenjiStrandTextureFactory` が生成する法線・粗さ・AOの3枚）にストランド局所UVで焼き込まれているため、係数が1組しかないと、方向の異なるストランドには正しい角度で乗らない。数値探索の結果、単一係数では最良でも ±12度（17.9度／42.2度）までしか縮まらないことが確認されている。

## 完成状態

- すべてのストランドで、撚りの縞が糸の進行方向に対して同じ角度になる。目標は設定値 `twistAngleDegrees` に対して **±3度以内**。
- 撚りの向き（ハンド）は引き続き全ストランドで一致する。
- 縞がストランド内で連続し、不連続点や折れがない。
- 交差部や周方向の継ぎ目で縞が破綻しない。

## 実装方針

次のいずれか、または小さな組み合わせで実装する。採用した方式と、他を採らなかった理由を完了報告に記載すること。

1. **方向ごとのテクスチャ組**: 山形の方向でストランドを2群に分け、それぞれの係数で法線・粗さテクスチャを生成する。マテリアルは色数×2になる。実装は単純だが、マテリアル数とテクスチャ枚数が倍になる。
2. **セグメント単位のUV変換**: 共有テクスチャ1枚のまま、セグメントごとにUVを回転・せん断して縞の角度を合わせる。縞は周期的なのでセグメント境界での位相不連続は許容できるが、ストランド内では連続させること。マテリアルは増えない。
3. **位相をテクスチャ座標にする**: メッシュが既に頂点ごとに保持している `twistPhases` を使い、テクスチャのU座標を `along` ではなく位相そのものにする。法線マップの傾きは `phasePerAlong` と `phasePerAcross` の両方に依存するため、接空間での扱いを併せて検討する必要がある。

いずれの方式でも次を守る。

- 外部パッケージを追加しない。
- ストランド1本ごと、繊維1本ごとに `Entity` を作らない。
- Metal のカスタムマテリアルへ移行する場合は、導入理由、iOS 17 での制約、フォールバックを先に記録する。
- テクスチャは決定的に生成し、同じ入力から同じ結果になること。
- 起伏量は現行の `twistReliefRatio`（半径の0.5%）を上限として増やさない。主表現は法線と粗さの微小変化のままとする。

## 必須Unit Test

- 全64セグメントについて、縞の方向と糸の進行方向のなす角が `twistAngleDegrees` ± 3度に収まること。
- 全セグメントで符号（撚りの向き）が一致すること。既存の `twistKeepsOneHandAndOneAnglePerChevronDirection` は、この完成状態を検証する内容へ戻すか、置き換えること。書き換えの意図をテスト名とコメントに残すこと。
- 縞の位相がストランド内で連続であること。
- 同じ入力から同じテクスチャ・同じ係数が生成されること。
- 方式1を採る場合、マテリアル数が色数×2を超えないこと。
- Task 005E の断面・層の交互性・谷の陰影、Task 005F のアスペクト比と45度、Task 004 の模様署名の既存テストを維持すること。

## 目視検証

- 正面表示で、上側の山形と下側の山形の縞の傾きが同じに見えること。現状（`.build/task005f-screenshots/after-front-detail.png` 相当）と並べて比較する。
- 拡大時に縞が糸の進行方向へ斜めに走り、モアレ・点滅・鋸歯が出ないこと。
- 左右へ1/4回転しても縞が表面へ固定されて見えること。
- 谷の陰影、交差の上下、畝の丸みが劣化していないこと。
- ライト／ダークモード双方で確認すること。
- 白・生成り・黒でも縞が識別できること。

スクリーンショットを `.build/task005g-screenshots/` へ残し、完了報告に記載する。

## 対象外

- 撚り角の値そのものの実物照合（`twistAngleDegrees = 30` は暫定値のまま）
- 毛羽・光沢の異方性など、撚り以外の素材表現
- 平源氏および8本系・12本系プリセットへの適用
- 物理シミュレーション

## 完了条件

- 全ストランドで縞角が `twistAngleDegrees` ± 3度に収まる。
- 撚りの向きが全ストランドで一致している。
- 縞がストランド内で連続し、交差部・継ぎ目で破綻しない。
- Task 004／005E／005F の既存の見た目と模様署名を劣化させていない。
- マテリアル数・テクスチャ枚数・頂点数の増加を完了報告に記載している。
- iOS 17 deployment target の Debug／Release ビルドが成功する。
- 関連 Unit Test と UI Test が成功する。
- `git diff --check` が成功する。

## 主な変更候補

- `Kumihimo/Features/BraidSimulation/MaruGenjiSurfaceMeshGenerator.swift`
- `Kumihimo/Features/BraidSimulation/MaruGenjiStrandTextureFactory.swift`
- `Kumihimo/Features/BraidSimulation/MaruGenjiStrandDetailTextures.swift`
- `Kumihimo/Features/BraidSimulation/MaruGenjiRealityView.swift`
- `KumihimoTests/MaruGenjiSurfaceMeshTests.swift`

filesystem-synchronized group を使用しているため、新規Swiftファイル追加だけを理由に `project.pbxproj` を手編集しない。

## Workerの完了報告

`AGENTS.md` の完了報告に加えて、次を記載する。

- 採用した方式と、他の方式を採らなかった理由。
- 全64セグメントの縞角の最小・最大・平均。
- マテリアル数、テクスチャ枚数と解像度、頂点・三角形数の増減。
- `twistKeepsOneHandAndOneAnglePerChevronDirection` をどう扱ったか。
- 現状スクリーンショットとの目視比較の結果。
- 実行した Debug／Release ビルド、Unit Test、UI Test と結果。
