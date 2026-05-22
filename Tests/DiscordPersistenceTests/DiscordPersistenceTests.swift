import Foundation
import Testing
@testable import DiscordPersistence

@Test
func sqliteMetadataRoundTripPersistsSchemaVersion() async throws {
    let database = try SQLiteDatabase.temporary()
    try await database.applyMigrations()
    let version = try await database.schemaVersion()

    #expect(version >= 1)
}

