import CoreGraphics
import DiscordKit

struct MessageReplyTarget: Hashable, Sendable {
    var channelID: ChannelID
    var messageID: MessageID
    var guildID: GuildID?
    var authorDisplayName: String
    var previewText: String
}

struct MessageActionTarget: Hashable, Sendable {
    var channelID: ChannelID
    var messageID: MessageID
    var guildID: GuildID?
    var authorID: UserID
    var authorDisplayName: String
    var previewText: String

    var replyTarget: MessageReplyTarget {
        MessageReplyTarget(
            channelID: channelID,
            messageID: messageID,
            guildID: guildID,
            authorDisplayName: authorDisplayName,
            previewText: previewText
        )
    }

    var messageLink: String {
        if let guildID {
            return "https://discord.com/channels/\(guildID.rawValue)/\(channelID.rawValue)/\(messageID.rawValue)"
        }
        return "https://discord.com/channels/@me/\(channelID.rawValue)/\(messageID.rawValue)"
    }
}

enum MessageActionDockMetrics {
    static let activationWidth: CGFloat = 116
    static let activationHeight: CGFloat = 42

    static func activationRect(in messageSize: CGSize) -> CGRect {
        let width = min(activationWidth, messageSize.width)
        let height = min(activationHeight, messageSize.height)
        return CGRect(
            x: max(0, messageSize.width - width),
            y: 0,
            width: width,
            height: height
        )
    }

    static func shouldPresentDock(
        pointerLocation: CGPoint?,
        messageSize: CGSize,
        isDockHovered: Bool,
        isMenuPresented: Bool
    ) -> Bool {
        if isDockHovered || isMenuPresented {
            return true
        }

        guard let pointerLocation else {
            return false
        }

        return activationRect(in: messageSize).contains(pointerLocation)
    }
}

struct UnicodeReactionOption: Identifiable, Hashable, Sendable {
    var emoji: String
    var name: String
    var keywords: [String]

    var id: String {
        emoji
    }

    func matches(searchText: String) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }

        let needle = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if emoji.contains(needle) {
            return true
        }
        if name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle) {
            return true
        }
        return keywords.contains { keyword in
            keyword.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle)
        }
    }
}

enum ReactionPalette {
    static let unicodeOptions: [UnicodeReactionOption] = [
        .init(emoji: "😀", name: "grinning face", keywords: ["happy", "smile"]),
        .init(emoji: "😄", name: "smiling face", keywords: ["joy", "cheerful"]),
        .init(emoji: "😂", name: "face with tears of joy", keywords: ["laugh", "lol"]),
        .init(emoji: "🤣", name: "rolling on the floor laughing", keywords: ["rofl", "laugh"]),
        .init(emoji: "😊", name: "smiling face with smiling eyes", keywords: ["warm", "glad"]),
        .init(emoji: "😍", name: "smiling face with heart eyes", keywords: ["love", "heart"]),
        .init(emoji: "🥰", name: "smiling face with hearts", keywords: ["affection", "love"]),
        .init(emoji: "😘", name: "face blowing a kiss", keywords: ["kiss", "love"]),
        .init(emoji: "🤔", name: "thinking face", keywords: ["hmm", "question"]),
        .init(emoji: "🫡", name: "saluting face", keywords: ["respect", "salute"]),
        .init(emoji: "😎", name: "smiling face with sunglasses", keywords: ["cool", "nice"]),
        .init(emoji: "🥳", name: "partying face", keywords: ["party", "celebrate"]),
        .init(emoji: "😴", name: "sleeping face", keywords: ["tired", "sleep"]),
        .init(emoji: "😭", name: "loudly crying face", keywords: ["cry", "sad"]),
        .init(emoji: "😢", name: "crying face", keywords: ["sad", "tear"]),
        .init(emoji: "😱", name: "face screaming in fear", keywords: ["shock", "surprised"]),
        .init(emoji: "😬", name: "grimacing face", keywords: ["awkward", "eek"]),
        .init(emoji: "😅", name: "grinning face with sweat", keywords: ["relief", "whew"]),
        .init(emoji: "🙃", name: "upside down face", keywords: ["sarcasm", "silly"]),
        .init(emoji: "🫠", name: "melting face", keywords: ["overwhelmed", "melt"]),
        .init(emoji: "😤", name: "face with steam from nose", keywords: ["frustrated", "huff"]),
        .init(emoji: "🤯", name: "exploding head", keywords: ["mind blown", "wow"]),
        .init(emoji: "💀", name: "skull", keywords: ["dead", "lol"]),
        .init(emoji: "👀", name: "eyes", keywords: ["watching", "look"]),
        .init(emoji: "🙏", name: "folded hands", keywords: ["thanks", "please"]),
        .init(emoji: "🙌", name: "raising hands", keywords: ["celebrate", "praise"]),
        .init(emoji: "👏", name: "clapping hands", keywords: ["clap", "applause"]),
        .init(emoji: "👍", name: "thumbs up", keywords: ["yes", "approve"]),
        .init(emoji: "👎", name: "thumbs down", keywords: ["no", "disapprove"]),
        .init(emoji: "👋", name: "waving hand", keywords: ["hello", "bye"]),
        .init(emoji: "🤝", name: "handshake", keywords: ["deal", "agreement"]),
        .init(emoji: "💪", name: "flexed biceps", keywords: ["strong", "muscle"]),
        .init(emoji: "🫶", name: "heart hands", keywords: ["love", "care"]),
        .init(emoji: "❤️", name: "red heart", keywords: ["love", "heart"]),
        .init(emoji: "🧡", name: "orange heart", keywords: ["heart", "care"]),
        .init(emoji: "💛", name: "yellow heart", keywords: ["heart", "sunshine"]),
        .init(emoji: "💚", name: "green heart", keywords: ["heart", "nature"]),
        .init(emoji: "💙", name: "blue heart", keywords: ["heart", "calm"]),
        .init(emoji: "🩵", name: "light blue heart", keywords: ["heart", "sky"]),
        .init(emoji: "🖤", name: "black heart", keywords: ["heart", "dark"]),
        .init(emoji: "🤍", name: "white heart", keywords: ["heart", "clean"]),
        .init(emoji: "🤎", name: "brown heart", keywords: ["heart", "earth"]),
        .init(emoji: "💔", name: "broken heart", keywords: ["heartbreak", "sad"]),
        .init(emoji: "❣️", name: "heart exclamation", keywords: ["emphasis", "love"]),
        .init(emoji: "🔥", name: "fire", keywords: ["lit", "hot"]),
        .init(emoji: "✨", name: "sparkles", keywords: ["sparkle", "magic"]),
        .init(emoji: "⭐", name: "star", keywords: ["favorite", "shine"]),
        .init(emoji: "🌟", name: "glowing star", keywords: ["star", "special"]),
        .init(emoji: "⚡", name: "high voltage", keywords: ["fast", "energy"]),
        .init(emoji: "💥", name: "collision", keywords: ["boom", "impact"]),
        .init(emoji: "💯", name: "hundred points", keywords: ["100", "perfect"]),
        .init(emoji: "✅", name: "check mark button", keywords: ["done", "yes"]),
        .init(emoji: "❌", name: "cross mark", keywords: ["no", "wrong"]),
        .init(emoji: "⚠️", name: "warning", keywords: ["alert", "caution"]),
        .init(emoji: "🚀", name: "rocket", keywords: ["launch", "ship"]),
        .init(emoji: "🛠️", name: "hammer and wrench", keywords: ["build", "fix"]),
        .init(emoji: "📌", name: "pushpin", keywords: ["pin", "important"]),
        .init(emoji: "📣", name: "megaphone", keywords: ["announce", "broadcast"]),
        .init(emoji: "🎉", name: "party popper", keywords: ["celebrate", "party"]),
        .init(emoji: "🎊", name: "confetti ball", keywords: ["celebrate", "confetti"]),
        .init(emoji: "🏆", name: "trophy", keywords: ["win", "award"]),
        .init(emoji: "☕", name: "hot beverage", keywords: ["coffee", "tea"]),
        .init(emoji: "🍿", name: "popcorn", keywords: ["watching", "drama"]),
        .init(emoji: "🧠", name: "brain", keywords: ["smart", "think"]),
        .init(emoji: "🫣", name: "face with peeking eye", keywords: ["peek", "nervous"]),
        .init(emoji: "🫢", name: "face with open eyes and hand over mouth", keywords: ["gasp", "surprised"]),
        .init(emoji: "🤗", name: "hugging face", keywords: ["hug", "warm"]),
        .init(emoji: "🤨", name: "face with raised eyebrow", keywords: ["skeptical", "hmm"]),
        .init(emoji: "🙄", name: "face with rolling eyes", keywords: ["eyeroll", "annoyed"])
    ]
}
