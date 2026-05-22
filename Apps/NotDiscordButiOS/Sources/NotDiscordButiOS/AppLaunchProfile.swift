import Foundation

enum AppLaunchProfile: String, Sendable {
    case live
    case preview

    static func current(processInfo: ProcessInfo = .processInfo) -> AppLaunchProfile {
        if processInfo.arguments.contains("--preview-data") || processInfo.environment["NOTDISCORDBUT_PREVIEW"] == "1" {
            return .preview
        }
        return .live
    }

    var label: String {
        switch self {
        case .live:
            return "Live API"
        case .preview:
            return "Preview Workspace"
        }
    }
}
