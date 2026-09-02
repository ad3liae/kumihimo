# Task 004: 実物照合済み配色展開図による丸源氏3D表面表示

- 状態: Ready
- 優先度: 高
- 前提: `docs/tasks/003-review-fixes.md` の4件が完了していること
- 仕様: `docs/specifications/project-editor.md`
- 関連方針: `docs/architecture.md`

## 目的

16本の糸の移動経路を個別のチューブとして表示している現在の3D試作を、実物3例との照合で配色傾向を確認できた「配色展開図」を円筒状の組紐表面へ写す表示へ置き換える。

本タスクの最優先事項は、入力した位置別の色が完成した丸源氏の表面模様として理解できることである。糸の移動手順を見せることではない。

## 現在の問題

現在の `MaruGenjiRealityView` は、`MaruGenjiPathGenerator` が生成した16本の経路を `MaruGenjiTubeMeshGenerator` で細いチューブにし、完成形として同時表示している。

この経路は資料の4操作を追跡する技術検証には使えるが、次の理由で完成した組紐の外観と大きく異なる。

- 16本が独立した丸い線として見え、締められた1本の組紐表面にならない。
- 実物で見える菱形・山形の色面ではなく、制作途中の移動軌跡が主役になっている。
- 糸の張力や締め具合を持たない経路補間を、完成断面として見せている。
- 2Dの配色展開図と3D表示が別の表現規則を使っている。

## 実物照合で得られた根拠

次の3組は、それぞれ「組み始めの16本の配置」と「その配置で組んだ完成品」の組である。第三者が制作した写真なので、画像そのものをアプリまたはリポジトリへ収録しない。実装判断と目視比較の参考だけに使う。

### 組1: 各方向の中央2本を同色にした配置

- 初期配置: `/Users/adeliae/Downloads/picture_pc_181f749b6a826dbf22fa3171aee2f861.jpeg`
- 完成品: `/Users/adeliae/Downloads/picture_pc_ccd87c22f1ab5e5f73f0c2a9d1fe8cce.webp`
- 位置1〜16の二色配置: `[A, B, B, A]` を4回繰り返す
- Aの位置: `[1, 4, 5, 8, 9, 12, 13, 16]`
- Bの位置: `[2, 3, 6, 7, 10, 11, 14, 15]`
- 完成品の特徴: 細かく連続する二色の山形

### 組2: 上下と左右を色分けした配置

- 初期配置: `/Users/adeliae/Downloads/picture_pc_7a7b866fa438d7c3a5d68deb6df1fcee.webp`
- 完成品: `/Users/adeliae/Downloads/picture_pc_34365725d8b2d8206f661d26bd048d4f.webp`
- Aの位置: `[1, 2, 7, 8, 9, 10, 15, 16]`
- Bの位置: `[3, 4, 5, 6, 11, 12, 13, 14]`
- 完成品の特徴: 長手方向に分かれる二色の面

### 組3: 4本単位の色境界をずらした配置

- 初期配置: `/Users/adeliae/Downloads/picture_pc_7cf83102ce613756664163dd545ecf8c.jpeg`
- 完成品: `/Users/adeliae/Downloads/picture_pc_a9a756fbd62aaadcdd61d745e9b3b5c2.webp`
- Aの位置: `[1, 2, 3, 4, 9, 10, 11, 12]`
- Bの位置: `[5, 6, 7, 8, 13, 14, 15, 16]`
- 完成品の特徴: 隣り合う面で位相のずれた大きな山形

写真には位置番号がないため、写真上部をシミュレータ上部とし、時計回りに番号を割り当てている。台全体の回転は同じ模様として扱う。鏡映が同じであるとは仮定しない。

## 検証用ローカルページ

元の配色ページを外部依存なしで再構築したローカル検証版が、作業環境の次の場所にある。

- 実装: `.build/local-pages/marugenji/`
- 位置から菱形への対応: `.build/local-pages/marugenji/app.js` の `STRANDS`
- 組1の確認画像: `.build/local-pages/marugenji/verification/pair-1.png`
- 組2の確認画像: `.build/local-pages/marugenji/verification/pair-2.png`
- 組3の確認画像: `.build/local-pages/marugenji/verification/pair-3.png`

`.build/` はGit管理対象外であり、アプリのビルド入力にしてはならない。実装時は、配色展開図の位置対応をUI非依存のSwift型へ移し、必要な期待値をUnit Testへ固定する。

## アーキテクチャ判断

既存の順序付き移動イベントは、組み方の手順を表すDomain結果として残す。削除または意味変更しない。

完成プレビューでは、16本の自由空間内の経路をそのまま描画しない。次の2つを分離する。

```text
手順検証:
  MaruGenjiCycle + MaruGenjiMoveEvent + MaruGenjiPathKeyframe

完成外観:
  位置別の色 + 丸源氏の表面パッチ対応
    → 正規化された配色展開図
    → 単一の組紐表面メッシュ
```

`docs/architecture.md` にある「糸ごとの3D経路を完成3Dとして表示する」記述は、本タスクで得られた実物照合結果と矛盾する。本タスクの実装時に、手順の経路と完成表面を上記のように区別する文面へ更新する。

## 必須実装1: UI非依存の表面パターン

位置1〜16と色IDから、配色展開図の表面パッチを決定する純粋なDomain計算を追加する。

推奨する責務は次のとおり。型名は既存コードとの整合に応じて変更してよい。

```swift
struct MaruGenjiSurfacePatch: Equatable, Sendable {
    let threadPosition: Int
    let colorID: ThreadColorID
    let corners: [SIMD2<Float>] // 正規化した周方向u・長手方向v
}

struct MaruGenjiSurfacePattern: Equatable, Sendable {
    let patches: [MaruGenjiSurfacePatch]
}

enum MaruGenjiSurfacePatternGenerator {
    static func generate(assignments: [ThreadAssignment]) -> MaruGenjiSurfacePattern?
}
```

### パターンの基準

- `.build/local-pages/marugenji/app.js` の `STRANDS` は、16位置それぞれに4枚、合計64枚の四辺形を割り当てている。
- JSの画面座標をそのままRealityKitへ渡さず、周方向 `u` と長手方向 `v` の正規化座標へ変換する。
- 展開図の横方向1周分を3D断面の360度へ対応させる。
- 展開図の縦方向を3Dの長軸へ対応させる。
- 長手方向へ模様を繰り返せる構造にする。繰り返し数は表示品質とメッシュ量の小さな定数でよい。
- 周方向の0と1の境界でパッチが途切れたり隙間が生じたりしないよう、必要なら境界をまたぐパッチを分割する。
- 同じ入力から必ず同じ順序・同じ座標の結果を返す。
- `assignments` が16件で、位置集合が重複なく正確に `1...16` であることを辞書化前に検証する。
- 色は配列添字ではなく `ThreadColorID` で保持する。

正規化後の対応表は本番コードまたは専用のDomainデータへ明示的に置く。描画View内の条件分岐や、テストだけに存在するデータへ隠さない。

## 必須実装2: 単一の組紐表面メッシュ

配色展開図を、長軸が現在と同じX軸方向になる円筒状または角を丸めた円筒状の表面へ変換する。

### 形状

- 全体を1本の締まった組紐として見せる。
- 16本の離れたチューブを完成形として同時表示しない。
- 各パッチの正規化周座標 `u` を `2πu` の角度へ変換する。
- 正規化長手座標 `v` をプレビューの長さへ変換する。
- 隣接パッチ間に穴を作らない。
- 断面は最初は円または角の丸い多角形でよい。実物の厳密な断面を推測しない。
- パッチ境界が読み取れる程度の小さな起伏または陰影は許可するが、未確認の上下関係を「正解」として固定しない。
- 写実的な繊維、毛羽、光沢の作り込みは行わない。
- 外部依存を追加しない。

### メッシュデータ

RealityKitに依存しないメッシュ生成器を用意し、少なくとも次をテスト可能にする。

```swift
struct MaruGenjiSurfaceMeshData: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let colorGroups: [ThreadColorID: [UInt32]]
}
```

実際の型は、色ごとのサブメッシュや複数の `MeshDescriptor` を生成しやすい形へ調整してよい。パッチごとに大量の `ModelEntity` を作るより、同じ色IDの三角形をまとめる方法を優先する。

- 位置、法線、インデックスへNaNまたは無限値を生成しない。
- 法線は概ね単位長とする。
- インデックスは頂点範囲内とする。
- 面積0の三角形を生成しない。
- 周方向の継ぎ目は閉じる。
- 色境界をまたいで誤った色補間をしない。色境界では必要に応じて頂点を分ける。

## 必須実装3: RealityKit表示の差し替え

`MaruGenjiRealityView.Coordinator.buildScene` を、表面パターンと表面メッシュを使うよう変更する。

- `MaruGenjiPathGenerator.generate` の16経路と `MaruGenjiTubeMeshGenerator` の16チューブを完成表示へ使わない。
- 色IDごとに `ThreadColorCatalog` から `SimpleMaterial` を作る。
- 全色のメッシュ生成が成功した場合だけ表示成功とする。
- 不正入力またはメッシュ生成失敗時は、既存の `controller.reportFailure()` を使う。
- カメラ、非AR表示、1本指回転、ピンチ、ダブルタップ、左右回転ボタン、リセット操作は維持する。
- ライト／ダークモードの背景で、白・生成り・黒を含む色境界が判別できる照明にする。
- 既存の `MaruGenjiViewerController` の操作軸を変える場合は、横ドラッグが組紐の長軸回転になる契約を維持する。

`MaruGenjiPathGenerator` と `MaruGenjiTubeMeshGenerator` は、順序付き移動の技術検証として残してよい。新しい完成表示から参照されなくなったことだけを理由に、関連テストを削除しない。

## 必須実装4: 2Dと3Dの正本を共通化する

`MaruGenjiThumbnailView` も `MaruGenjiSurfacePatternGenerator` の結果を使う。

- 2Dサムネイルと3D表面で、同じ位置が同じ色パッチへ対応すること。
- 2Dだけ旧経路投影、3Dだけ新表面という二重実装にしない。
- サムネイルは展開図そのもの、または組紐を正面から見た簡略投影のどちらでもよい。
- 装飾画像を計算結果の代用にしない。

## 必須実装5: 表示上の留保と文書更新

実物3例との照合により、位置別配色から表面模様への傾向は確認できた。ただし、厳密な糸の上下関係、断面、締め具合は未確認である。

`ProjectEditorStrings.maruGenjiPrototypeNotice` は、少なくとも次の意味を伝える文面へ更新する。

> 実物3例で配色傾向を照合した試作です。糸の上下関係と締め具合は未検証です。

実装に合わせて次を最小限更新する。

- `docs/architecture.md`: 手順経路と完成表面を分離する。
- `docs/specifications/project-editor.md`: 3例の配色傾向を照合済みとし、未検証事項を残す。
- `docs/tasks/003-braid-simulation-presets.md`: 本タスクへの参照を追記し、履歴を消さない。

## 検証用の3配色

Unit TestとSwiftUI Previewで、`ThreadColorCatalog` の `blue` と `pink` を使って次の3入力を固定する。写真の色を新しいカタログ色として追加しない。

### Fixture 1: 細かな山形

```text
positions 1...16:
blue, pink, pink, blue,
blue, pink, pink, blue,
blue, pink, pink, blue,
blue, pink, pink, blue
```

期待する性質:

- 4つの周方向区画すべてに同位相の二色の山形が現れる。
- 単色の長手面にならない。

### Fixture 2: 長手方向の色分け

```text
positions 1...16:
blue, blue,
pink, pink, pink, pink,
blue, blue, blue, blue,
pink, pink, pink, pink,
blue, blue
```

期待する性質:

- 4つの周方向区画がそれぞれ長手方向に単色となる。
- 隣接区画はblueとpinkで交互になる。
- 3Dを回転すると、完成写真のように青い面とピンクの面を別々に観察できる。

### Fixture 3: 位相のずれた山形

```text
positions 1...16:
blue, blue, blue, blue,
pink, pink, pink, pink,
blue, blue, blue, blue,
pink, pink, pink, pink
```

期待する性質:

- 単色の長手面にならない。
- 隣接区画の山形は同じ長手位置で異なる位相になる。
- Fixture 1と同じパターン署名にならない。

## 必須Unit Test

### 表面パターン

- 正常な16位置から64枚の基準パッチを生成できる。
- 各基準パッチが正確に1つの糸位置と色IDを持つ。
- 位置1〜16が基準パッチ内にそれぞれ4回現れる。
- 同じ入力からパッチの順序、座標、色IDが決定的に一致する。
- 重複位置、欠落位置、範囲外位置、15件、17件で安全に失敗する。
- 周方向の回転に相当する位置の循環シフトで、模様が消えたり色数が変わったりしない。
- Fixture 1〜3の性質を、ViewやRealityKitに依存せず検証する。
- Fixture 1〜3が互いに異なるパターン署名を持つ。

期待値は本番の生成器を呼んで組み立てず、正規化したパッチ対応のリテラルまたは固定済み署名としてテストへ置く。

### 表面メッシュ

- すべての頂点、法線が有限値である。
- 法線が概ね単位長である。
- すべての三角形インデックスが範囲内である。
- 面積0の三角形がない。
- 周方向の継ぎ目に対応する頂点位置が一致する。
- すべての表面パッチがいずれか1つの色グループへ入り、欠落・重複しない。
- 入力に存在する各色IDが対応する三角形を持つ。
- 同じ入力から同じ頂点数、三角形数、色グループを生成する。

### 既存機能の回帰

- Task 003の順序付き4操作、周期末配置、経路キーフレームのテストを維持する。
- 色変更後に2Dサムネイルと3D詳細が同じ新パターンへ更新される。
- 不正入力で3D生成がクラッシュせず失敗表示になる。
- プリセットの選択・解除、保存・再読込の既存テストを維持する。

## 目視検証

iPhoneシミュレータでFixture 1〜3をそれぞれ表示し、スクリーンショットを残して次を確認する。

- Fixture 1は細かな二色の山形に見える。
- Fixture 2は長手方向に分かれた青面とピンク面に見える。
- Fixture 3はFixture 1と異なる、位相のずれた大きな山形に見える。
- 16本の離れたチューブや、籠状の空洞が見えない。
- 正面、左回転、右回転の各角度でメッシュに穴、ちらつき、色抜けがない。
- ライト／ダークモードで色境界が判別できる。
- 標準文字サイズとアクセシビリティ文字サイズで、操作ボタンと留保文が隠れない。

写真は1方向からの外観しかないため、ピクセル単位の画像一致を完了条件にしない。配色の面構成と山形の位相を比較する。

## 主な変更候補

- `Kumihimo/Domain/MaruGenjiSurfacePattern.swift`（新規候補）
- `Kumihimo/Features/BraidSimulation/MaruGenjiSurfaceMeshGenerator.swift`（新規候補）
- `Kumihimo/Features/BraidSimulation/MaruGenjiRealityView.swift`
- `Kumihimo/Features/BraidSimulation/MaruGenjiThumbnailView.swift`
- `Kumihimo/Features/ProjectEditor/ProjectEditorStrings.swift`
- `KumihimoTests/MaruGenjiSurfacePatternTests.swift`（新規候補）
- `KumihimoTests/MaruGenjiSurfaceMeshTests.swift`（新規候補）
- `KumihimoTests/MaruGenjiSimulationTests.swift`（既存回帰の維持）
- 関連するSwiftUI Preview、UI Test、仕様文書

プロジェクトはfilesystem-synchronized groupを使っているため、新規Swiftファイル追加だけを理由に `project.pbxproj` を手編集しない。

## 対象外・引き続き未確定

- 各交差点でどの糸が上になるかの厳密な物理再現
- 絹糸の毛羽、撚り、光沢の写実表現
- 締める力、張力、糸径による形状変化
- 実物と同じ断面形状の確定
- 編み手順アニメーション
- 既存の4操作Domainモデルの廃止または全面再設計
- 丸源氏以外の組み方への汎用メッシュ基盤
- 外部3Dパッケージまたは画像生成サービスの導入

## 完了条件

- 3D詳細が16本の離れたチューブではなく、1本の締まった組紐表面として表示される。
- 2Dサムネイルと3D表面が同じ `MaruGenjiSurfacePattern` を正本にする。
- Fixture 1〜3の表面模様が、それぞれの完成写真の配色傾向と一致する。
- Fixture 1〜3が互いに異なる模様として表示される。
- 順序付き移動イベントと既存の保存・選択機能を壊していない。
- 不正入力またはメッシュ失敗でクラッシュしない。
- UI上に照合済みの範囲と未検証事項を明示する。
- iOS 17 deployment targetのDebug／Releaseビルドが成功する。
- 関連Unit TestとUI Testが成功する。
- `git diff --check` が成功する。
- 実物写真とローカル検証ページをコミットしていない。

## Workerの完了報告

`AGENTS.md` の完了報告に加えて、次を記載する。

- 配色展開図の64パッチをどのDomain型へ移したか。
- 2Dと3Dが同じパターンを使うことを、どのテストで保証したか。
- 表面メッシュの断面、分割数、模様の繰り返し数をどう選んだか。
- Fixture 1〜3を正面・左右回転で確認した結果。
- ライト／ダークモード、標準／アクセシビリティ文字サイズの確認結果。
- 実行したDebug／Releaseビルド、Unit Test、UI Testと結果。
- 糸の上下関係、張力、断面形状など引き続き未確定の事項。
