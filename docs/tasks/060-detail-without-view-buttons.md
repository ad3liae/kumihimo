# Task 060: 詳細の3Dから「左へ回転」「正面に戻す」「右へ回転」のボタンを外す

- 状態: **実装済み**（2026-09-25、Claude Code。枝 `claude/task-060-detail-without-view-buttons`。PR はマージ待ち）。結果は末尾。
  指示書は審査側（2026-09-25）
- 前提（先に読むこと）: `docs/specifications/project-editor.md`（「詳細」の節と受け入れ条件。**審査側がこの指示書と同時に
  書き直した**）、`AGENTS.md`
- 基準: 最新の main（Task 059 の PR #44、`805b660` 以降）
- **製品コード（画面）に触れる。** PR の前に全件を1回通すこと。Task 061 と同じ画面を触るので、**060 を先に済ませる**

## 0. 作者の決定（2026-09-25）

「詳細ビューで、回転ボタンとリセットボタンは不要だと思う。」

## 1. いまの作り（審査側が読んだ）

- 3Dの描き手 `RoundTube16PreviewView`（筒の族。丸源氏・八つ金剛・丸四つ・江戸八つが通る）と `Flat16PreviewView`（平源氏）が、
  キャンバスの下に `controlButton` を3つ並べている（`ProjectEditorStrings.rotateLeft`・`resetView`・`rotateRight`、
  `controller.rotate(horizontal: ±.pi / 8)`・`controller.reset()`）。
- 詳細（`BraidDetailSheet`）は `isEmbedded: true` でこれを埋め込む。`KumihimoApp.swift` のデバッグ起動は `isEmbedded: false` で
  同じ描き手を全画面に出す。
- 読み上げのヒント `maruGenji3DAccessibilityHint` は「下のボタンでも左右に回転できます」と言っている。
  手の説明 `maruGenjiGestureHelp` は「1本指で左右に回転・ピンチで拡大縮小・ダブルタップで正面に戻ります」。

## 2. すること

1. **ボタン3つを、両方の描き手から外す**（詳細でも、デバッグ起動の全画面でも）。`controlButton` が他で使われていなければ消す。
   文字列 `rotateLeft`・`rotateRight`・`resetView` は 3 で使うので残す。
2. **手の操作は変えない**: 1本指の横ドラッグで回転、ピンチで拡大縮小、ダブルタップで正面に戻す。
3. **VoiceOver の代わりの操作を足す。** ボタンは、ドラッグができない読み上げの利用者の代わりの操作でもあった（仕様の旧記述）。
   キャンバスに **カスタムアクション「左へ回転」「右へ回転」「正面に戻す」**（`accessibilityAction(named:)`）を付け、
   中身はボタンと同じ呼び出しにする。
4. **読み上げのヒントを直す**: 「下のボタンでも」をやめ、「横ドラッグで回転、ピンチで拡大縮小、ダブルタップで正面に戻ります。
   操作のメニューからも回転できます」の趣旨にする（平源氏のヒントも同じ扱い）。
5. **上の空きは3Dに渡す。** ボタンの段が消えた分、詳細の上の部分でキャンバスが縮まないようにする（上下の割合 0.5 は変えない）。

## 3. 試験・検証

- ボタンの識別子を見ている UI テスト・単体試験があれば、カスタムアクションを見る形に直す（無ければ足さない）。
- 形状ハッシュ・カードの画素は変わらない（3Dの中身は触らない）。
- iPhone 縦と iPad 横で詳細を開き、ボタンの段が無く3Dが広がったことを撮って報告する。VoiceOver のアクションは、
  アクセシビリティインスペクタでアクションが3つ出ることを確かめれば足りる。

## 4. 記録

- この指示書の末尾に結果。`docs/README.md` の Task 060 の行。

## 結果（2026-09-25、Claude Code）

### 1. したこと

- **ボタン3つを両方の描き手から外した**（`RoundTube16PreviewView`・`Flat16PreviewView`。詳細の埋め込みでも、デバッグ起動の全画面でも、
  `YatsuKongoComparisonPreview` の全画面でも）。`controlButton` は他で使われていなかったので両方とも消した。
  文字列 `rotateLeft`・`rotateRight`・`resetView` は残した。
- **手の操作は変えていない**（`RoundTube16RealityView`・`Flat16RealityView` の横ドラッグ・ピンチ・ダブルタップは触っていない）。
- **カスタムアクション**: 新しいファイル `Kumihimo/Features/BraidSimulation/BraidViewerAccessibilityActions.swift` の
  `View.braidViewerAccessibilityActions(_:)` 1か所に置き、両方の描き手のキャンバスに付けた。中身はボタンと同じ呼び出し
  （`controller.rotate(horizontal: ∓.pi / 8)`・`controller.reset()`）。
  - **`accessibilityAction(named:)` を逆の順に付けている。** SwiftUI は**あとに付けたアクションを先に**渡す
    （iOS 18.5 で木を読んで確かめた。指示の順に付けると VoiceOver には「正面に戻す」「右へ回転」「左へ回転」と並んだ。
    `accessibilityActions { }` にまとめて書いても同じく逆になった）。仕様の順「左へ回転」「右へ回転」「正面に戻す」で読ませるため、
    「正面に戻す」を最初に付けている。理由はコードの doc comment に書いた。
- **読み上げのヒント**:
  - 丸（筒の族）`maruGenji3DAccessibilityHint`: 「横ドラッグで回転、ピンチで拡大縮小、ダブルタップで正面に戻ります。操作のメニューからも回転できます」
  - 平源氏 `hiraGenji3DAccessibilityHint`: 「横ドラッグで表、裏、左右の縁を回転して観察できます。ピンチで拡大縮小、ダブルタップで正面に戻ります。
    操作のメニューからも回転できます」（前半はいまの文のまま、ダブルタップとメニューを足した）
  - 手の説明 `maruGenjiGestureHelp`（下の部分の注記）はボタンに触れていないので変えていない。
- **上の空きは3Dに渡した**: 埋め込みのときキャンバスは `canvasHeight: nil`（残りを全部取る）なので、ボタンの段が消えた分がそのまま
  キャンバスに入った。**上下の割合 `BraidDetailSheet.solidShare` = 0.5 は変えていない**（区切り線の位置は前後で同じ）。

### 2. 3Dの広がり（iPhone 縦・iPad 横で撮った）

前（main `805b660`）は別の作業ツリーで同じ使い捨ての UI テストを回して撮った。キャンバスの枠は XCUITest の `frame`（pt）。

| 機体 | 前のキャンバス | 後のキャンバス | ボタン |
| --- | --- | --- | --- |
| iPhone 16（iOS 18.5）縦、丸源氏・平源氏 | x 16, y 133, 361×249 | x 16, y 133, **361×323** | 前はあり → 後は無し |
| iPad Pro 11 (M4)（iOS 18.5）横、丸源氏・平源氏 | x 269, y 109, 672×246 | x 269, y 109, **672×320** | 前はあり → 後は無し |

- どちらも **74 pt 高くなった**（ボタンの段と間隔の分）。上端・幅・区切り線の位置・下の部分は前と同じ。
- **組紐の見かけの太さも約 1.30 倍になった**（323/249、320/246）。カメラは縦の画角と距離が決まっていて
  （`BraidSurfaceScene.cameraDistance`・`verticalFieldOfView`）、見える高さがキャンバスの高さに比例するため。**3Dの中身（メッシュ・色）は触っていない。**
- 撮った画像は `.build` には置かず、報告に添えた（前後の並べ図: iPhone 縦の丸源氏・平源氏、iPad 横の丸源氏・平源氏）。

### 3. VoiceOver のアクションの確かめ方

- **アクセシビリティインスペクタは使っていない**（この環境からは画面の操作ができない）。代わりに、**使い捨ての単体試験（コミットしていない）**で
  本物の `BraidDetailSheet`（丸源氏組・平源氏組）を `UIHostingController` に載せ、UIKit に渡るアクセシビリティの木（VoiceOver と
  インスペクタが読む木）を読んだ:
  - キャンバスの要素（`maru-genji-3d-surface`・`hira-genji-3d-surface`）に **カスタムアクションが3つ、「左へ回転」「右へ回転」「正面に戻す」の順**。
  - それぞれを実行すると `roll` が −π/8 → 0 → +π/8、「正面に戻す」で 0（倍率も 1）。
  - ヒントが上の新しい文。木のどこにも「左へ回転」「右へ回転」「正面に戻す」という名前の要素が無い。
- **この試験をコミットしなかった理由**: テストのプロセスでは、**アクセシビリティの自動化を入れないと SwiftUI が木を作らない**
  （ホスティングビューの要素が 0）。入れるには非公開の `_AXSSetAutomationEnabled`（`libAccessibility.dylib`）を呼ぶしかなく、
  しかもこれは**機体（シミュレータ）全体の設定**に見える（AGENTS.md「機体に置いた環境変数は、外すまで残る」と同じ種類の危うさ）。
  今回は呼ぶ前の値が既に 1（UI テストを回した機体なので）で、終わりに同じ値へ戻した。**常設するかは審査側の判断に任せる。**
- **XCUITest からはカスタムアクションを数えられない**（iOS 18 の公開 API に無い。Xcode 27 の `XCUIVoiceOverService` は iOS 27 以降で、
  この Mac に iOS 27 のランタイムが無い）。

### 4. 試験

- **UI テストを3件直した**（`KumihimoUITests/HomeFlowUITests.swift`。ボタンを名前で見ていた）:
  - `testSixteenThreadProjectOpensMaruGenji3DPreview`: ボタンが「ある」→**「無い」**を確かめる（`assertNoViewButtons`）。
  - `testVerifiedSurfaceFixturesRenderAtFrontLeftAndRightAngles`: ボタンを押していた所を、**キャンバスの横ドラッグ**（ボタンの π/8 に当たる約 49 pt、
    描き手の 0.008 rad/pt から）と**ダブルタップ**に置き換えた。正面・左・右の画像が互いに違う（回っている）ことを目で見た。
  - `testVerifiedSurfaceNoticeAndControlsRemainVisibleInDarkAccessibilityText` → **`testVerifiedSurfaceNoticeRemainsVisibleInDarkAccessibilityText`** に改名。
    ボタンが押せる → ボタンが無い、に替えた。はじめはキャンバスが `isHittable` であることも足したが、**XCUITest はこのキャンバスを
    hittable と見なさない**（描かれていて存在はする）ので外した。ダーク・最大の文字で、キャンバスの下にすぐ注記が続くのを画像で見た。
- **単体試験は足していない**（上の 3 の理由）。
- **全件（ユニット）1回**: iPhone 16（iOS 18.5、`9EF8CDC3…`）、`-only-testing:KumihimoTests`、上限 300000 ms・1件 60 秒。
  **518 件中 成功513・失敗0・スキップ5、テスト段階 157.1 秒**（試験ごとの時間の和 124.2 秒）。**打ち切りは無い。**
  形状ハッシュとカードの画素の試験（`BraidMeshHashTests` ほか）は通った。**3Dの中身は不変。**
- **UI テストは直した所と関わる所だけを単独で回した**（全件は回していない。Task 015）:
  - iPhone 16: `testSixteenThreadProjectOpensMaruGenji3DPreview`・`testSixteenThreadProjectSelectsAndOpensHiraGenji3DPreview`・
    `testVerifiedSurfaceFixturesRenderAtFrontLeftAndRightAngles` は通った。`testVerifiedSurfaceNoticeRemainsVisibleInDarkAccessibilityText` は
    **1回目に失敗**（上の `isHittable`。Task 015 の事象ではなく、こちらの書いた確かめの誤り）、直して単独で通った。
  - iPad Pro 11 (M4)（`A05EC194…`）: `testWideIPadEditorOpensDetailAsSheetThatSurvivesRotation` は通った。
  - **1回目の失敗のあと `xcodebuild` が戻らなかった**（`simctl diagnose` が約 9 分）。AGENTS.md のとおり `simctl diagnose` を `kill -INT` して結果が書かれた。
- `sh Scripts/check-braiding-is-general.sh` は通った（導出は触っていない）。

### 5. 確かめていないこと

- **実機の VoiceOver で読ませてはいない**（アクションの並びと中身は上の木で確かめた）。
- **iOS 17** の見え方と読み上げ（iOS 17 のランタイムが無い）。
- UI テストの全件。

