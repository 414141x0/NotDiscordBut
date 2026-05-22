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
        .init(emoji: "🔥", name: "fire", keywords: ["lit", "hot"]),
        .init(emoji: "✨", name: "sparkles", keywords: ["sparkle", "magic"]),
        .init(emoji: "💯", name: "hundred points", keywords: ["100", "perfect"]),
        .init(emoji: "✅", name: "check mark button", keywords: ["done", "yes"]),
        .init(emoji: "❌", name: "cross mark", keywords: ["no", "wrong"]),
        .init(emoji: "🚀", name: "rocket", keywords: ["launch", "ship"]),
        .init(emoji: "🎉", name: "party popper", keywords: ["celebrate", "party"]),
        .init(emoji: "🏆", name: "trophy", keywords: ["win", "award"]),
        .init(emoji: "☕", name: "hot beverage", keywords: ["coffee", "tea"]),
        .init(emoji: "🧠", name: "brain", keywords: ["smart", "think"]),
        .init(emoji: "🙄", name: "face with rolling eyes", keywords: ["eyeroll", "annoyed"])
    ]
}
