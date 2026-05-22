import SwiftUI

enum FilterMode: String, CaseIterable, Hashable, Identifiable {
    case all
    case friends
    case servers
    case recent
    case mentioned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "All"
        case .friends:
            return "Friends"
        case .servers:
            return "Servers"
        case .recent:
            return "Recent"
        case .mentioned:
            return "Mentioned"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .friends:
            return "person.2"
        case .servers:
            return "building.2"
        case .recent:
            return "clock"
        case .mentioned:
            return "at"
        }
    }
}
