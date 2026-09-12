# Kumihimo ドキュメント

このディレクトリを、プロダクトと実装仕様の正本とする。

## 文書構成

- `product.md`: プロダクトの目的、対象ユーザー、MVPの範囲
- `architecture.md`: 技術方針、データと画面の責務、設計上の決定
- `measurement-procedures.md`: 実物の写真とレンダーを突き合わせる測り方の正本。**構成した紐の読み方（5節）もここにある**
- `specifications/`: ユーザーから見た機能仕様と受け入れ条件
- `tasks/`: Workerへ渡す、範囲を限定した実装指示

## 現在の仕様とタスク

**Task 020 が本体である。** 組み方ごとの専用コードを書く方向はここで終わりとし、台と手順列から
組み上がりを導く一般の道へ移る。007 系と 008〜014 はその下に入る。

**初期リリースはレシピ（手順表）のある伝統的な紐に限り、物理シミュレーションを載せない**
（作者の決定、2026-09-08。`architecture.md`「初期リリースはレシピのある紐に限る」）。
**編み出せる版になったら物理を再検討する。**

- **Task 025 初期リリースの描画（レシピのある紐だけを、それらしく）: 最高優先**: `tasks/025-initial-release-rendering.md`
  - レシピ＝**手順表 ＋ 配色 ＋ 測った形の値**（＋平らな紐は紐のまわりの並び順）。
    出どころは型で分ける——`.observed`（測った）／`.derived`（導いた）／`.declared`（目で合わせた）
  - **025-4 は折衷**（作者の判定、2026-09-09。**退役しない**）——**形は族の描き手、色は占有履歴**。
    面の見え（升の中の形）は旧生成器が勝った
  - 段: 025-1 棚卸し、025-2 レシピの型と模様図、025-3 立体と z バッファ、025-4 折衷、
    **025-5 レシピを1つ足す手順**: `tasks/025-5-adding-a-recipe.md`

- **Task 027 画面を 025 の経路に繋ぐ**（**完了**。立体の選択を族へ、保存の鍵をレシピ ID へ、
  模様図を画面に、Task 018 の打ち切りを解消）: `tasks/027-screens-on-recipes.md`
  - **手で確かめる項目**（Task 015 が自動検証を塞いでいるあいだ）: `tasks/027-4-manual-checks.md`

- **Task 028 一覧のサムネイル**（**028-1a 完了。028-1b 取り下げ・028-1c 不要**。カードは
  展開図だけの横長に戻した。場面の切り出し `BraidSurfaceScene` は残した）: `tasks/028-thumbnails-in-three-dimensions.md`
- **Task 029 平源氏のサムネイルを一周ぶんの展開図にする**（**完了**。表 6・縁 2・裏 6・縁 2 を
  枠の高さに載せた。セルの縦横比 2.199 は動いていない。**継ぎ目が右縁の真ん中に落ちる件は
  判定は「回す」。**029-2 未着手**）: `tasks/029-flat-thumbnail-round-the-braid.md`
- **Task 030 縁の傾きがリピートの端で消える**（**完了**。`boundary` の端の例外を外し、
  傾きも位相と同じく全ての継ぎ目に効くようにした。**穴は開かず**、mesh のハッシュ 3 件を
  理由つきで入れ替えた）: `tasks/030-lean-at-the-tile-ends.md`

- **Task 026 初期リリースまでに残るものの棚卸し**（**読み取り専用・完了**。画面・実機・棚上げの
  Task・レシピの追加候補を「必須／あると良い／後の版」に分けた案）: `tasks/026-initial-release-inventory.md`

- **レシピを1つ足すとき**は `tasks/025-5-adding-a-recipe.md` を読むこと（手順表の写し方、配色、
  測った形の値の取り方、平らな紐の並び順、族の判定、平らな描き手の位相の制約）

- **Task 020 一般の組紐シミュレータ（台・手順列から組み上がりを導く）: 本体**: `tasks/020-general-braid-simulator.md`
  - **段階3 は Task 025 の折衷で初期リリース分を完了**（2026-09-09。形は族の描き手、色は占有履歴）。**積3 完了**
  - **構成した紐を描いて読んだ結果は両方の正本と一致した**（2026-09-08、末尾の里程標）が、
    **面の見えでは旧生成器を採った**（025-4 の判定）
  - 段階4・段階5 は**初期リリースの外**
  - 正本の読み方（bookC の1手は1本）は `architecture.md`「正本の読み方（作者の指示）」

- Task 024 山の構成（糸の半径から）（**区切った**。立つものは 025 へ転用、残りは保留。末尾「024 を区切る」）: `tasks/024-crest-by-half-diameter.md`
  - 到達点: **平源氏 bookA p97 の3実験が両面で通り（楕円 100/100/0）、丸源氏 Task 004 と 32/32**
  - **越える糸を +d/2、くぐる糸を −d/2。solver を使わない**（`architecture.md`「山は糸の半径から出る」）

- Task 023 張った糸を構成的に組む（**保留**。solver の研究。末尾「引き継ぎ」）: `tasks/023-taut-thread-construction.md`

- Task 022 台の上で組む（準静的）（**閉じた**。準静的の模型は束を締めるものを持たず、糸どうしが触れない。締めるものを足すと 021c へ戻る）: `tasks/022-braid-on-the-stand.md`

- 起動画面仕様: `specifications/home-screen.md`
- 作品編集・詳細画面仕様: `specifications/project-editor.md`
- Task 001 起動画面: `tasks/001-home-screen.md`
- Task 002 作品編集画面の基盤: `tasks/002-project-editor-foundation.md`
- Task 003 組み方プリセットとシミュレーション: `tasks/003-braid-simulation-presets.md`
- Task 004 実物照合済みの丸源氏3D表面: `tasks/004-maru-genji-surface-3d.md`
- Task 005 丸源氏3Dの境界・繊維感と色整合: `tasks/005-maru-genji-surface-material.md`
- Task 006 端面のない長尺3D表示とiPad適応レイアウト: `tasks/006-infinite-braid-ipad-layout.md`
- Task 007 平源氏16本プリセット: `tasks/007-hira-genji-16.md`
- Task 008 八つ金剛組8玉の完成シミュレーション（**完了**。bookA p54–55 の絵と作者の判定から
  手順表を起こし、Z は S を盤の上で鏡に写して作った。**配色は判定済み**（2026-09-10。
  S は bookA p.54、Z は p.55 の a。どちらも 105 黄が縦・108 橙が横で、違いは螺旋の向きだけに
  なる）。**立体は Task 031 で出るようになった**）: `tasks/008-yatsu-kongo-8.md`
- **Task 031 筒8本の描き手**（**完了**。**升の形を転写ではなく規則から作る最初の描き手**。
  伸びは測り直して **S 0.403 d**（Z-a は 0.506 で一致せず、配色 b は読み替え不可）。
  測り方は `measurement-procedures.md` の 6。**升は「留まっているぶん」＝1列×1サイクルで
  真っ直ぐ**（作者の判定）。**斜めに見えるのは色**で、**導出 46.5° 対 写真 S +54.5°／
  Z-a −51.0°、差 8.0°／4.5°**。残りを埋めるには測った伸びを動かすしかないので動かしていない）:
  `tasks/031-round-tube-8-drawer.md`
- Task 032 八つ金剛の立体を写真へ寄せる（**完了**。描き手の鏡と、同じ原因の「手前が透ける」を直した。
  刷られた1手を1瞬間として読み、到着の位相を入れた。**丸源氏の描いた面も手順表の鏡であることが分かった
  （記録のみ。外の資料待ち）。平源氏の内向きの巻きは既知の問題（穴は出ない）**）:
  `tasks/032-yatsu-kongo-solid-to-the-photograph.md`
- Task 033 八つ金剛のサムネイルの縦線と、升の両端（**完了**。最初の行の升を帯の端で切っていたため全レーンの
  升の境目がリピートごとに揃い、サムネイルに縦線が出ていた。**切らずに前のリピートから描く**ようにした（Task 030 と
  同じ形の直し方）。**升の両端を丸くして粒に見えるようになった。**縦の谷は横の 0.282 の流用をやめ、
  自分の数（`.declared` 0.18）にして浅くした）:
  `tasks/033-yatsu-kongo-cell-ends-and-card-seam.md`
- Task 009 江戸八つ組8玉の完成シミュレーション（未着手）: `tasks/009-edo-yatsu-8.md`
- Task 010 八つ瀬組8玉の完成シミュレーション（未着手）: `tasks/010-yatsuse-8.md`
- Task 011 唐八つ組8玉の完成シミュレーション（未着手）: `tasks/011-kara-yatsu-8.md`
- Task 012 江戸源氏組12玉の完成シミュレーション（未着手）: `tasks/012-edo-genji-12.md`
- Task 013 方丈組12玉の完成シミュレーション（未着手）: `tasks/013-houjou-12.md`
- Task 014 方丈組（中細）12玉の完成シミュレーション（未着手）: `tasks/014-houjou-medium-fine-12.md`
- Task 005E 丸源氏16本の組紐らしさ向上（Task 005 エンハンス。Task 008 以降より優先）: `tasks/005e-maru-genji-braid-fidelity.md`
- Task 005F 表面パターンのアスペクト比修正（Task 008 以降より優先）: `tasks/005f-maru-genji-surface-aspect.md`
- Task 005G 撚りの縞を山形の方向ごとに正す（Task 008 以降より優先）: `tasks/005g-maru-genji-twist-direction.md`
- Task 005H 糸幅を正本とした周方向スケールの確定: `tasks/005h-braid-thread-scale.md`（前提が誤りのため差し戻し）
- Task 005I 丸源氏の山形の密度を実物へ合わせる（Task 007 エンハンス・Task 008 以降より優先）: `tasks/005i-maru-genji-chevron-density.md`
- Task 007E 平源氏16本の組紐らしさ向上（**完了**。畝 0.45・ピッチ 0.3665・傾き0 を資料から決めた）: `tasks/007e-hira-genji-braid-fidelity.md`
- Task 007F 平源氏の表面模様を織り構造として作り直す（**完了**。Task 007E へ引き継ぎ済み）: `tasks/007f-hira-genji-weave-model.md`
- Task 005J 丸源氏の遮蔽マップと畝の高さ（段階1・2 完了。遮蔽は両スロットへ。畝はシルエット法が丸い紐に使えず未確定）: `tasks/005j-maru-genji-ambient-occlusion.md`
- Task 015 UIテストで RealityKit が落ちる件（未着手。退行ではない）: `tasks/015-ui-test-realitykit-crash.md`
- Task 007G 平源氏の縁の位相（**完了**。到着の位相を手番から導いた）: `tasks/007g-hira-genji-edge-phase.md`
- Task 007H 平源氏のタイルの継ぎ目（**完了**。段をタイル端へ持ち出せるようにした）: `tasks/007h-hira-genji-tile-seam.md`
- Task 007I 平源氏の縁の糸が面の腹の下をくぐって見えるようにする（**Task 020 へ吸収**。中断のまま指示書を残す）: `tasks/007i-hira-genji-edge-lap.md`
- Task 007J 平源氏を「曲げたタイル」ではなく「糸」で作り直す（**Task 020 へ吸収**。段階A完了・段階B未完。糸の経路と糸のメッシュは Task 020 段階3 の部品として参照する）: `tasks/007j-hira-genji-as-strands.md`
- Task 016 組み点の物理で寸法を解けるかの調査（**完了**。段階2・2b の記録は枝 `claude/task-016-braid-physics-feasibility` の `d0e69c1` / `9b4d789`。**マージしない**。**段階4「製品へどう載せるか」は Task 020 段階4 が引き取る**）: `tasks/016-braid-physics-feasibility.md`
- Task 018 `everyRegionCarriesTheRidgeIncludingBothEdges` が2分かかる件（未着手。優先度低）: `tasks/018-slow-mesh-test.md`
- Task 021 反発による深さの導出（**保留。021a〜021e まで実行し、「置く高さの模型」は行き止まりと判明**。占有履歴で面の模様は出た（丸源氏 Task 004 と 32/32、平源氏 p97 3実験）。**続きは Task 022。末尾の「引き継ぎ」を読むこと**）: `tasks/021-depth-by-relaxation.md`

## 更新方針

- プロダクト上の判断は `product.md` に反映する。
- 複数機能へ影響する技術判断は `architecture.md` に反映する。
- 実物と突き合わせる測り方は `measurement-procedures.md` に反映する。`.build/` は git の管理外なので、判断に効く事実をそこへ残さない。
- 個別画面の振る舞いは対応する仕様書に反映する。
- 完了した実装チケットは削除せず、状態と実装結果を追記する。
- 会話内だけで重要な仕様を確定させず、該当文書へ反映してから実装する。
