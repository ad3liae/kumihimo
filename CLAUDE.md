# Kumihimo

@AGENTS.md

このファイルは Claude Code に `AGENTS.md` を読み込ませるためにある。**Claude Code は
`CLAUDE.md` を自動で読み、`AGENTS.md` は自動では読まない。** 規約の本体は `AGENTS.md` に
置き、ここには Claude Code 固有のことだけを書く。

## この repo での進め方

- `docs/` がプロダクトと実装仕様の正本である。`docs/README.md` から入ること。
- 測り方の正本は `docs/measurement-procedures.md`。**新しい測り方を作る前にここを読むこと。**
- 複数機能へ影響する技術判断は `docs/architecture.md` に記録する。
- タスクの指示書は `docs/tasks/`。**完了した指示書を消さず、状態と結果を追記する。**
- `.build/` は git の管理外である。**判断に効く事実をそこへ残さないこと。**
- `git add -A` を使わないこと。**足すファイルを明示すること。**
