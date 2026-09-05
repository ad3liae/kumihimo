# Kumihimo ドキュメント

このディレクトリを、プロダクトと実装仕様の正本とする。

## 文書構成

- `product.md`: プロダクトの目的、対象ユーザー、MVPの範囲
- `architecture.md`: 技術方針、データと画面の責務、設計上の決定
- `specifications/`: ユーザーから見た機能仕様と受け入れ条件
- `tasks/`: Workerへ渡す、範囲を限定した実装指示

## 現在の仕様とタスク

- 起動画面仕様: `specifications/home-screen.md`
- 作品編集・詳細画面仕様: `specifications/project-editor.md`
- Task 001 起動画面: `tasks/001-home-screen.md`
- Task 002 作品編集画面の基盤: `tasks/002-project-editor-foundation.md`
- Task 003 組み方プリセットとシミュレーション: `tasks/003-braid-simulation-presets.md`
- Task 004 実物照合済みの丸源氏3D表面: `tasks/004-maru-genji-surface-3d.md`
- Task 005 丸源氏3Dの境界・繊維感と色整合: `tasks/005-maru-genji-surface-material.md`
- Task 006 端面のない長尺3D表示とiPad適応レイアウト: `tasks/006-infinite-braid-ipad-layout.md`
- Task 007 平源氏16本プリセット: `tasks/007-hira-genji-16.md`
- Task 005E 丸源氏16本の組紐らしさ向上（Task 005 エンハンス。Task 008 以降より優先）: `tasks/005e-maru-genji-braid-fidelity.md`
- Task 005F 表面パターンのアスペクト比修正（Task 008 以降より優先）: `tasks/005f-maru-genji-surface-aspect.md`
- Task 005G 撚りの縞を山形の方向ごとに正す（Task 008 以降より優先）: `tasks/005g-maru-genji-twist-direction.md`
- Task 005H 糸幅を正本とした周方向スケールの確定: `tasks/005h-braid-thread-scale.md`（前提が誤りのため差し戻し）
- Task 005I 丸源氏の山形の密度を実物へ合わせる（Task 007 エンハンス・Task 008 以降より優先）: `tasks/005i-maru-genji-chevron-density.md`
- Task 007E 平源氏16本の組紐らしさ向上（**完了**。畝 0.45・ピッチ 0.3665・傾き0 を資料から決めた）: `tasks/007e-hira-genji-braid-fidelity.md`
- Task 007F 平源氏の表面模様を織り構造として作り直す（**完了**。Task 007E へ引き継ぎ済み）: `tasks/007f-hira-genji-weave-model.md`
- Task 005J 丸源氏の遮蔽マップと畝の高さ（未着手。平源氏で決めた測り方を丸源氏へ）: `tasks/005j-maru-genji-ambient-occlusion.md`
- Task 015 UIテストで RealityKit が落ちる件（未着手。退行ではない）: `tasks/015-ui-test-realitykit-crash.md`

## 更新方針

- プロダクト上の判断は `product.md` に反映する。
- 複数機能へ影響する技術判断は `architecture.md` に反映する。
- 個別画面の振る舞いは対応する仕様書に反映する。
- 完了した実装チケットは削除せず、状態と実装結果を追記する。
- 会話内だけで重要な仕様を確定させず、該当文書へ反映してから実装する。
