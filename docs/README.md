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

## 更新方針

- プロダクト上の判断は `product.md` に反映する。
- 複数機能へ影響する技術判断は `architecture.md` に反映する。
- 個別画面の振る舞いは対応する仕様書に反映する。
- 完了した実装チケットは削除せず、状態と実装結果を追記する。
- 会話内だけで重要な仕様を確定させず、該当文書へ反映してから実装する。
