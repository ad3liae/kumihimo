# Kumihimo

日本の伝統工芸「組紐」の配色と完成イメージを、制作前に確認するためのiOSアプリです。

現在は初期設計段階です。プロダクトと実装の正本は [`docs/README.md`](docs/README.md) を参照してください。

## 初期リリースの範囲

**初期リリースは、レシピ（手順表）のある伝統的な紐に限ります。** 見た目がそれらしく見えれば
よく、**物理シミュレーションは行いません。** 紐の形の値は資料の実測値をそのまま持ち込みます。

**自分で組み方を編み出せる版になったら、物理を再検討します。** 決定の本文は
[`docs/architecture.md`](docs/architecture.md) の「初期リリースはレシピのある紐に限る（作者の決定）」、
作業の指示書は [`docs/tasks/025-initial-release-rendering.md`](docs/tasks/025-initial-release-rendering.md) です。

**紐の形は紐の族ごとの描き手**（丸い筒16本、平ら16本）**が描き、面の模様の色は手順表から
導いた占有履歴が決めます。** 紐を1つ足す手順は
[`docs/tasks/025-5-adding-a-recipe.md`](docs/tasks/025-5-adding-a-recipe.md) にあります
（手順表・配色・測った形の値の3つ、平らな紐はさらに紐のまわりの並び順）。

## 開発を始める

Codex Workerは、最初に [`AGENTS.md`](AGENTS.md) を読み、対象の仕様書と実装チケットに従って作業します。

最初の実装対象は [`docs/tasks/001-home-screen.md`](docs/tasks/001-home-screen.md) です。
