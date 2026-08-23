import Foundation

enum ProjectEditorStrings {
    static let newProjectTitle = "新しい組紐"
    static let save = "保存"
    static let overwrite = "上書き保存"
    static let saveAs = "名前をつけて保存…"
    static let saveNewTitle = "作品を保存"
    static let saveAsTitle = "名前をつけて保存"
    static let projectName = "作品名"
    static let cancel = "キャンセル"
    static let threadCountSection = "糸の本数"
    static let threadCount = "本数"
    static let colorPlacementSection = "色の配置"
    static let boardAccessibilityLabel = "組紐台の糸配置"
    static let chooseColorTitle = "糸の色"
    static let simulationSection = "組み方別のシミュレーション結果"
    static let simulationCalculating = "完成イメージを計算中"
    static let simulationFailedTitle = "完成イメージを生成できませんでした"
    static let simulationFailedMessage = "配色はこのまま保存できます。"
    static let noCompatiblePresetTitle = "この本数の組み方はまだありません"
    static let noCompatiblePresetMessage = "16本を選ぶと、丸源氏の試作シミュレーションを表示できます。配色はこのまま保存できます。"
    static let undecidedBraid = "組み方をまだ決めない"
    static let selectionSelected = "選択中"
    static let selectionNotSelected = "未選択"
    static let showIn3D = "3Dで見る"
    static let maruGenjiPreviewTitle = "丸源氏・3D試作"
    static let maruGenjiPrototypeNotice = "資料の手順をもとにした暫定シミュレーションです。"
    static let maruGenjiGestureHelp = "1本指で回転・ピンチで拡大縮小・ダブルタップで正面に戻ります"
    static let maruGenji3DAccessibilityLabel = "丸源氏の立体完成イメージ"
    static let maruGenji3DAccessibilityHint = "下のボタンで左右に回転できます"
    static let rotateLeft = "左へ回転"
    static let rotateRight = "右へ回転"
    static let resetView = "正面に戻す"
    static let reduceThreadCountTitle = "糸の本数を減らしますか？"
    static let reduceThreadCountMessage = "減らした位置の色は失われます。"
    static let reduce = "減らす"
    static let saveErrorTitle = "保存できませんでした"
    static let saveErrorMessage = "編集内容は残っています。もう一度お試しください。"
    static let retry = "再試行"
    static let dismiss = "閉じる"
    static let loadErrorTitle = "作品を読み込めませんでした"
    static let loadErrorMessage = "作品が削除されたか、保存データを読み込めませんでした。"
    static let loading = "読み込み中"

    static func threadCountValue(_ count: Int) -> String { "\(count)本" }
    static func copyName(from name: String) -> String { "\(name)のコピー" }
    static func threadAccessibilityLabel(position: Int, colorName: String) -> String {
        "糸\(position)、\(colorName)"
    }
    static func threadColorTitle(position: Int) -> String { "糸\(position)の色" }
    static let threadAccessibilityHint = "ダブルタップで色を変更"
}
