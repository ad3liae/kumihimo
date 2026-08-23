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
    static let simulationPendingTitle = "組み方はまだ選べません"
    static let simulationPendingMessage = "組み方と完成イメージは、次の開発工程で追加します。配色はこのまま保存できます。"
    static let simulationCalculating = "完成イメージを計算中"
    static let simulationFailedTitle = "完成イメージを生成できませんでした"
    static let simulationFailedMessage = "配色はこのまま保存できます。"
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
