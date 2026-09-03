# Task 006: 端面のない長尺3D表示とiPad適応レイアウト

- 状態: Done
- 優先度: 高
- 作成日: 2026-09-03
- 前提: Task 005までmainへマージ済みであること
- 仕様: `docs/specifications/project-editor.md`
- 関連方針: `docs/architecture.md`

## 目的

丸源氏の3D完成プレビューから断面と有限長の印象をなくし、左右の画面外へ永続的に続く長尺の組紐として観察できるようにする。同時に、iPadをiPhone互換表示ではなくネイティブ対応端末へ加え、広い画面では配色設定と結果確認を同時に行える構成へ変更する。

本タスクで解決する問題は次の2つである。

1. 現在の3Dメッシュは両端に端面があり、長軸を傾けると切断された円筒の断面が見える。
2. アプリターゲットがiPhone専用であるため、iPadでは黒い余白を伴う互換表示になり、編集画面と3D画面が小さな領域へ閉じ込められる。

## 確定したプロダクト判断

- 組紐の端面は表示しない。
- プレビュー上の組紐は実寸や有限長を示さず、左右の画面外へ十分に続く長尺表現でよい。
- 実際に無限個の頂点を生成するのではなく、周期メッシュの反復とカメラ制約で無限に続くように見せる。
- 3D操作は組紐の長軸回転と拡大縮小へ絞る。端面が見える方向へ長軸を傾ける操作は廃止する。
- iPadをネイティブ対応端末へ加える。
- iPhoneの既存導線は維持し、利用可能な横幅が十分な場合だけ2列構成を採用する。
- iPadのSplit ViewやStage Managerで幅が狭い場合は、iPhone相当の1列構成へ戻す。

## 現状の実装と原因

### 端面

`MaruGenjiSurfaceMeshGenerator.generate` は、側面を生成した後に `appendEndCap` を2回呼び、`-length / 2` と `length / 2` に円盤状の端面を追加している。

`MaruGenjiViewerController` は縦ドラッグから `pitch` を更新し、最大約±0.85ラジアンまで長軸を傾ける。このため端面をカメラへ向けることができる。初期状態にも `pitch = -0.12` があり、組紐が奥へ細くなる遠近感と有限長の印象が生じている。

### 長さ

表面メッシュは `defaultLength = 3.4`、`defaultPatternRepeatCount = 4` の1本だけである。単純に長さと繰り返し数を大きくすると、Task 005で増えた細分割頂点を全長分複製し、メモリと生成時間が不必要に増える。

### iPad

アプリ、Unit Test、UI Testターゲットの `TARGETED_DEVICE_FAMILY` が `1` のため、iPadではiPhone互換モードになる。`ProjectEditorView` は常に1列の `ScrollView`、3Dは常に `.sheet` で表示されるため、ネイティブ化だけでは広い画面を十分に使えない。

## 必須実装1: 端面をメッシュから除去する

- `MaruGenjiSurfaceMeshGenerator` の完成表示から両端の `appendEndCap` 呼び出しを削除する。
- `appendEndCap` と `edgeColor` が完成表示以外からも未使用になる場合は削除する。
- 端面用に入れていた `surfaceVertexPatchIndices == -1`、端面専用UV、端面の色決定処理を残さない。
- 生成する三角形はすべて64パッチの側面へ帰属させる。
- 側面の先端を黒い円盤、透明板、背景色の板などで塞いで断面を隠す実装にしない。
- 端をフェードアウトして画面内で消す方法を主手段にしない。組紐そのものを画面外まで続ける。
- 周方向の継ぎ目、パッチ境界、繊維起伏、色グループのTask 005契約は維持する。

## 必須実装2: 周期メッシュを共有した長尺表現

### 方針

1つの短い表面タイルを生成し、その `MeshResource` とマテリアルを複数の `ModelEntity` で共有して長手方向へ並べる。実際の頂点配列を長大化する方法は採用しない。

```text
MaruGenjiSurfacePattern
  → 端面なしの周期タイル1個
  → MeshResourceを1回生成
  → X軸の負方向・正方向へ対称にインスタンス配置
  → 画面には端が存在しない長尺の組紐として表示
```

### 要件

- タイルはパターンが完全に周期一致する長さとする。
- 隣接タイルの接合位置で、色、パッチ境界、半径変位、法線、繊維位相が連続する。
- タイル境界へTask 005の端部用 `endFade` を適用しない。現在のメッシュ両端で起伏を0へ戻す処理は、反復境界で段差を作るため見直す。
- 隣接タイル間に隙間、重複面、Z-fighting、縦の継ぎ目線を作らない。
- 同一の `MeshResource` と同一のマテリアル配列を共有する。インスタンスごとにメッシュを再生成しない。
- インスタンスは原点を中心に奇数個配置し、左右へ同数伸ばす。
- ピンチの最小倍率、iPad横画面、iPadの可変ウインドウ幅を考慮し、表示範囲の左右に少なくとも1画面分の余裕を確保する。
- 必要数はビューポート幅、カメラ距離、画角、最小倍率、タイル長から決定できる純粋な計算へ分離する。
- ウインドウサイズが変わった場合は不足分のインスタンスを追加・削除してよいが、色やパターンが変わらない限り `MeshResource` を作り直さない。
- 安全上限を設け、異常なサイズ入力で無制限にEntityを生成しない。

推奨する責務の例:

```swift
struct MaruGenjiViewportCoverage: Equatable, Sendable {
    let tileCount: Int
    let coveredLength: Float
}

enum MaruGenjiViewportCoverageCalculator {
    static func calculate(
        viewportSize: SIMD2<Float>,
        cameraDistance: Float,
        verticalFieldOfView: Float,
        minimumScale: Float,
        tileLength: Float
    ) -> MaruGenjiViewportCoverage?
}
```

型名と入力は既存コードへ合わせて変更してよい。画面幅から必要タイル数を決めるロジックを `UIViewRepresentable` の場当たり的な定数列として隠さない。

## 必須実装3: 端面を見せないカメラと操作

- `MaruGenjiViewerController` から長軸を傾ける `pitch` 状態を削除する。
- 初期姿勢では組紐の長軸を画面の横方向へ平行にする。
- 横ドラッグは従来どおりX軸まわりの回転へ使う。
- 縦ドラッグでは長軸をカメラ方向へ傾けない。未割り当てのまま無視してよい。
- 「左へ回転」「右へ回転」は長軸回転、「正面に戻す」は回転角と倍率のリセットとして維持する。
- ピンチの最小倍率でも端が画面内へ入らないよう、長尺カバレッジ計算と連動させる。
- ダブルタップ後も端が見えない初期状態へ戻る。
- カメラの遠近感による不自然な先細りを避ける。透視カメラを維持する場合も、長軸上の各点が同じ奥行きになる初期姿勢を使う。
- 端面を見せない制約を破る自由軌道カメラ、長軸方向へのカメラ移動、極端なズームアウトは追加しない。
- `ProjectEditorStrings.maruGenjiGestureHelp` から上下傾斜の説明を削除する。
- VoiceOverのヒントも、長軸回転と拡大縮小だけを説明する。

## 必須実装4: iPadネイティブ対応

### ターゲット設定

- アプリターゲットのDebug／Releaseで `TARGETED_DEVICE_FAMILY` を `1,2` にする。
- Unit Test／UI TestターゲットもiPadシミュレータで実行できる設定にする。
- iPhoneは現在のPortrait対応を維持する。
- iPadはPortrait、Portrait Upside Down、Landscape Left、Landscape Rightをサポートする。
- iPadのマルチタスクやリサイズを無効化して大画面だけへ固定する設定は追加しない。
- Mac Catalystは本タスクの対象外とし、現在の設定を維持する。

### レイアウト判断

- `UIDevice.current.userInterfaceIdiom` だけで配置を分岐しない。
- `horizontalSizeClass`、実際のコンテナ幅、Dynamic Typeを使って判断する。
- 横2列の最小必要幅を明示し、おおむね900pt前後を初期目安として実機・シミュレータで調整する。
- アクセシビリティ文字サイズで2列が窮屈になる場合は、十分な画面幅があっても1列へ戻す。
- SwiftUIの `ViewThatFits`、条件付き `HStack`、または小さな専用 `Layout` を使用してよい。巨大な `ProjectEditorView` へ端末別分岐を集中させない。
- 回転やウインドウリサイズの途中で編集状態、選択色、選択プリセット、3D回転角を失わない。

AppleはiPadアプリに、画面回転、マルチタスク、リサイズへ滑らかに適応し、十分な表示領域では主要コンテンツを活用することを推奨している。本タスクでも端末型ではなく、現在与えられた表示領域を基準にする。

## 必須実装5: iPadの作品編集画面

### 広いレイアウト

十分な横幅では、最大幅を設けた2列構成とする。

```text
┌──────────────────────────────────────────────────────┐
│ 作品名                                      保存      │
├────────────────────────┬─────────────────────────────┤
│ 糸の本数               │ 組み方別の結果              │
│                        │ または選択中の3D詳細         │
│ 色の配置               │                             │
│ [組紐台]               │ [2Dサムネイル／大きな3D]    │
│                        │                             │
└────────────────────────┴─────────────────────────────┘
```

- 左列は糸本数と組紐台を含み、目安幅360〜460ptとする。
- 右列は残りの幅を使い、最低420pt程度を確保する。
- 全体が極端に横へ伸びないよう、読みやすい最大幅を設定して中央へ配置する。
- 列間へ十分な余白または `Divider` を設ける。
- 保存は従来どおりナビゲーションバー右上に残す。
- 色選択、保存名入力、削除確認など既存のモーダル挙動を壊さない。
- 3Dを開いている間も左列の配色設定を表示してよい。色を変更した場合、3Dは同じ `assignments` から安全に再構築する。

### 狭いレイアウト

- iPhoneと狭いiPadウインドウでは、糸本数、色配置、シミュレーション結果の1列スクロールを維持する。
- 2列から1列へ切り替わってもコンテンツを二重生成して異なるStoreを持たせない。
- 主要ボタンのタップ領域を最低44×44ptに維持する。

### ホーム画面

- iPadネイティブ表示で、ホームのListが画面全幅へ不自然に伸びる場合は、システム余白を尊重しつつ読みやすい最大幅へ収める。
- 新規作成、保存作品の選択、スワイプ削除、削除確認の導線はiPhoneと同じ意味を維持する。
- `NavigationSplitView` を使ったサイドバー化や複数ウインドウ対応は、本タスクでは必須にしない。

## 必須実装6: iPadの3D表示

### 広い編集画面から開く場合

- 小さなフォームシートを出さず、編集画面右列の結果領域を3D表示へ切り替える。
- 3Dキャンバスを右列の主要領域として可能な限り大きく表示する。
- 右列内に「結果へ戻る」または同等の明確な閉じる操作を置く。
- 回転ボタンと留保文をキャンバスの下または脇へ置き、キャンバスへ重ねて操作を妨げない。

### 1列レイアウトから開く場合

- iPhoneまたは狭いiPadでは、画面全体を使う3D詳細へ遷移または全画面表示する。
- iPadの中央に小さなフォームシートとして表示しない。
- 閉じる操作を常に表示し、システムの戻る操作も可能な構成を優先する。

### 3Dキャンバス

- 固定の `height: 420` をiPadの広い表示へそのまま適用しない。
- 利用可能領域から高さを決め、広いiPadでは少なくとも画面の主要部分を3Dキャンバスへ割り当てる。
- Safe Area、ステータスバー、ナビゲーションバー、ホームインジケータを侵食しない。
- Portrait、Landscape、Split Viewでカメラの被写体サイズが極端に変わらないよう、アスペクト比変更時に投影と長尺カバレッジを更新する。
- 回転ボタンはキーボードフォーカス、ポインタ、VoiceOverでも操作できる標準Buttonを維持する。

## 必須Unit Test

### 端面なしメッシュ

- 生成頂点がすべて64パッチのいずれかへ帰属し、端面専用頂点が存在しない。
- X軸にほぼ垂直な円盤三角形を生成しない。
- 色グループと境界色グループの三角形がすべて側面へ属する。
- 既存の有限値、単位法線、非縮退、インデックス範囲、周方向継ぎ目テストを維持する。

### 長手方向の反復

- タイル先頭と末尾の対応する位置、半径、法線、色、境界状態、繊維位相が一致する。
- 連続する2タイルを並べた接合面に隙間や重複三角形がない。
- 同じパターンから同じタイルメッシュとマテリアル順を生成する。
- カバレッジ計算は常に正の奇数タイル数を返す。
- iPhone Portrait、iPad Portrait、iPad Landscape、狭いSplit View相当の代表サイズで、最小倍率時も必要長を満たす。
- 0、負数、NaN、無限値のビューポートや画角入力で安全に失敗する。
- 極端な入力でも定めた最大タイル数を超えない。

### 操作

- 横回転でX軸回転だけが変わり、長軸の傾斜状態を持たない。
- リセットで回転角と倍率が初期値へ戻る。
- 拡大縮小範囲が既存の安全範囲を維持する。

### レイアウト判断

- 代表的な横幅とDynamic Typeから、2列／1列の選択が決定的に行われる。
- アクセシビリティ文字サイズでは、幅が不足する場合に1列へ戻る。
- 配置切り替えで同じ `ProjectEditorStore` と同じDraftを使用する。

## 必須UI Testと目視確認

### iPhone回帰

- iPhoneのPortraitでホーム、新規作成、保存作品、色変更、プリセット選択が従来どおり動く。
- 3Dを開き、長軸回転、ピンチ、ダブルタップ、左右回転、リセット、閉じる操作が使える。
- 3Dを最小倍率にしても端面が見えない。

### iPadネイティブ表示

- iPad 10th generation相当で、アプリが黒い余白と右下の互換表示拡大ボタンを伴わず、ネイティブの全画面またはウインドウとして表示される。
- PortraitとLandscapeの両方で起動・回転できる。
- Landscapeの十分な幅で編集画面が2列になり、左に組紐台、右に結果が表示される。
- 右のサムネイルから3Dを開くと、右列の主要領域に大きく表示され、小さなフォームシートにならない。
- iPad Portraitまたは狭いSplit Viewで1列へ戻り、3Dは画面全体を使って表示される。
- ウインドウ幅を変更しても選択色、プリセット、未保存の編集内容が失われない。

### 3D外観

- リセット位置で組紐が左右両端から画面外へ続いて見える。
- 連続して左右へ回転しても断面、内部、端、タイル継ぎ目が見えない。
- 最小倍率、最大倍率、iPad Landscapeの最広表示でも端が見えない。
- Fixture 1〜3でパターンがタイル境界を越えて連続する。
- Task 005の境界暗部、繊維感、2D／3Dの色整合が維持される。
- ライト／ダークモード、標準文字サイズ、アクセシビリティ文字サイズを確認する。

正面、回転後、最小倍率、iPad Portrait、iPad Landscape、狭いウインドウのスクリーンショットをテスト成果物として残す。

## 主な変更候補

- `Kumihimo.xcodeproj/project.pbxproj`
- `Kumihimo/App/AppRootView.swift`
- `Kumihimo/Features/Home/HomeView.swift`
- `Kumihimo/Features/ProjectEditor/ProjectEditorView.swift`
- `Kumihimo/Features/ProjectEditor/SimulationResultsBoundaryView.swift`
- `Kumihimo/Features/BraidSimulation/MaruGenjiSurfaceMeshGenerator.swift`
- `Kumihimo/Features/BraidSimulation/MaruGenjiRealityView.swift`
- `Kumihimo/Features/BraidSimulation/MaruGenji3DPreviewView.swift`
- `Kumihimo/Features/ProjectEditor/ProjectEditorStrings.swift`
- `KumihimoTests/MaruGenjiSurfaceMeshTests.swift`
- 長尺カバレッジと適応レイアウト判断の新規Unit Test
- `KumihimoUITests/HomeFlowUITests.swift`
- 関連するSwiftUI Preview、仕様文書

既存プロジェクトはfilesystem-synchronized groupを使っているため、新規Swiftファイル追加だけを理由に `project.pbxproj` のファイル一覧を手編集しない。ただし、本タスクではiPad対応のビルド設定変更が必要なので、その設定差分は明示的に行う。

## 対象外

- 実際の作品長、使用糸量、単位、長さ入力UI
- 組紐の切断面や房、金具、結び目の表示
- 長手方向へスクロールして別の位置を見る操作
- 自由軌道カメラ
- 厳密な糸の上下関係、張力、締め具合、断面形状の物理再現
- iPadの複数ウインドウ
- `NavigationSplitView` を使ったホームのサイドバー再設計
- Apple Pencil固有操作
- Mac Catalyst、macOS、visionOS対応

## 完了条件

- 3Dメッシュから両端面が除去されている。
- すべての許可された回転・倍率・対象画面幅で、組紐の端や内部が見えない。
- 組紐が左右の画面外へ連続し、有限長の円筒ではなく長尺の紐として見える。
- タイル接合部に隙間、段差、縦線、色抜け、繊維位相の飛びがない。
- 同じ周期MeshResourceを共有し、長さに比例して頂点配列を複製していない。
- iPadが互換モードではなくネイティブアプリとして起動する。
- iPad Landscapeの十分な幅で編集画面が2列になり、3Dを大きく表示できる。
- iPhoneおよび狭いiPadウインドウで1列構成と既存導線が維持される。
- iPadのPortrait、Landscape、Split View相当幅へ状態を失わず適応する。
- Task 004／005の配色パターン、境界、繊維感、色整合を壊していない。
- iOS 17 deployment targetのiPhone／iPad向けDebug・Releaseビルドが成功する。
- iPhone／iPadの関連Unit TestとUI Testが成功する。
- `git diff --check` が成功する。

## Workerの完了報告

`AGENTS.md` の完了報告に加えて、次を記載する。

- 端面を除去した箇所と、端が見えないことを保証する操作制約。
- 1タイルの長さ・模様周期・頂点数・三角形数。
- `MeshResource` の共有方法、配置した最大インスタンス数、カバレッジ計算方法。
- タイル境界で色、法線、起伏、繊維位相が連続することの検証結果。
- iPadネイティブ対応のターゲット・向き設定。
- 2列から1列へ切り替える条件と、Dynamic Typeでの扱い。
- iPhone Portrait、iPad Portrait、iPad Landscape、狭いウインドウでの目視結果。
- 正面、回転後、最小倍率で端面が見えないことの確認結果。
- ライト／ダークモード、標準／アクセシビリティ文字サイズの確認結果。
- 実行したDebug／Releaseビルド、Unit Test、UI Testと結果。
- 検証できなかった端末構成や未解決事項。

## 参考

- [Apple Human Interface Guidelines: Designing for iPadOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ipados)
- [Apple Human Interface Guidelines: Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Apple Human Interface Guidelines: Multitasking](https://developer.apple.com/design/human-interface-guidelines/multitasking)
- [SwiftUI: ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits)
