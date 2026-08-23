import Foundation

enum HomeStrings {
    static let title = "組紐"
    static let createTitle = "新しく編む"
    static let createSubtitle = "色や組み方を選んで作成"
    static let savedProjectsHeader = "保存した組紐"
    static let emptyTitle = "保存した組紐はまだありません"
    static let emptyMessage = "新しく編むを選んで、最初の組紐を作ってみましょう。"
    static let delete = "削除"
    static let cancel = "キャンセル"
    static let deleteErrorTitle = "削除できませんでした"
    static let loadErrorTitle = "保存した組紐を読み込めませんでした"
    static let loadErrorMessage = "時間をおいて、もう一度お試しください。"
    static let retry = "再試行"
    static let loading = "読み込み中"
    static let dismiss = "閉じる"

    static func threadCount(_ count: Int) -> String {
        "糸 \(count)本"
    }

    static func deleteConfirmationTitle(projectName: String) -> String {
        "“\(projectName)”を削除しますか？"
    }

    static func projectAccessibilityLabel(
        name: String,
        braidTypeName: String,
        threadCount: Int,
        updatedAt: String
    ) -> String {
        "\(name)、\(braidTypeName)、糸\(threadCount)本、最終更新 \(updatedAt)"
    }

    static let openProjectHint = "編集画面を開きます"
}
