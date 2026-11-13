import AppIntents
import Foundation

/// Siri / Shortcuts support: "Hey Siri, play <song> on Music". Uses App Intents (iOS 16+), which needs no
/// special entitlement, so it works in sideloaded builds with a free Apple ID.
enum AuroraSiri {
  static let key = "aurora.siri.query"
  static let note = Notification.Name("AuroraSiriQuery")

  /// One command for the Flutter side: {"cmd": play|pause|resume|next|previous|like|shuffle|liked|playlist, "q": text}.
  static func send(_ cmd: String, _ q: String = "") {
    let text = q.trimmingCharacters(in: .whitespacesAndNewlines)
    if cmd == "play" && text.isEmpty { return }
    guard let data = try? JSONSerialization.data(withJSONObject: ["cmd": cmd, "q": text]),
          let json = String(data: data, encoding: .utf8) else { return }
    UserDefaults.standard.set(json, forKey: key)
    UserDefaults.standard.synchronize()
    NotificationCenter.default.post(name: note, object: json)
  }

  /// What is playing, written by the app so Siri can read it out.
  static var nowPlaying: String { UserDefaults.standard.string(forKey: "aurora.siri.now") ?? "" }
}

@available(iOS 16.0, *)
struct SongEntity: AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Song")
  static var defaultQuery = SongEntityQuery()
  var id: String
  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: LocalizedStringResource(stringLiteral: id)) }
}

/// Free-form: whatever Siri heard becomes the search text.
@available(iOS 16.0, *)
struct SongEntityQuery: EntityStringQuery {
  func entities(for identifiers: [String]) async throws -> [SongEntity] { identifiers.map { SongEntity(id: $0) } }
  func entities(matching string: String) async throws -> [SongEntity] { [SongEntity(id: string)] }
  func suggestedEntities() async throws -> [SongEntity] { [] }
}

@available(iOS 16.0, *)
struct PlaySongIntent: AppIntent {
  static var title: LocalizedStringResource = "Play a song"
  static var description = IntentDescription("Searches for a song or artist and plays it.")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Song", requestValueDialog: "Which song?")
  var song: SongEntity

  static var parameterSummary: some ParameterSummary { Summary("Play \(\.$song)") }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("play", song.id)
    return .result(dialog: "Playing \(song.id)")
  }
}

/// "Play music on Music": Siri asks which song, then plays it.
@available(iOS 16.0, *)
struct PlayAskIntent: AppIntent {
  static var title: LocalizedStringResource = "Play music"
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Song or artist", requestValueDialog: "Which song or artist?")
  var query: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("play", query)
    return .result(dialog: "Playing \(query)")
  }
}

@available(iOS 16.0, *)
struct PauseMusicIntent: AppIntent {
  static var title: LocalizedStringResource = "Pause music"
  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("pause")
    return .result(dialog: "Paused")
  }
}

@available(iOS 16.0, *)
struct ResumeMusicIntent: AppIntent {
  static var title: LocalizedStringResource = "Resume music"
  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("resume")
    return .result(dialog: "Resuming")
  }
}

@available(iOS 16.0, *)
struct NextSongIntent: AppIntent {
  static var title: LocalizedStringResource = "Next song"
  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("next")
    return .result(dialog: "Next song")
  }
}

@available(iOS 16.0, *)
struct PreviousSongIntent: AppIntent {
  static var title: LocalizedStringResource = "Previous song"
  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("previous")
    return .result(dialog: "Previous song")
  }
}

@available(iOS 16.0, *)
struct LikeSongIntent: AppIntent {
  static var title: LocalizedStringResource = "Like this song"
  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("like")
    return .result(dialog: "Done")
  }
}

@available(iOS 16.0, *)
struct WhatsPlayingIntent: AppIntent {
  static var title: LocalizedStringResource = "What's playing"
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let now = AuroraSiri.nowPlaying
    return .result(dialog: IntentDialog(stringLiteral: now.isEmpty ? "Nothing is playing" : "Playing \(now)"))
  }
}

@available(iOS 16.0, *)
struct PlayLikedIntent: AppIntent {
  static var title: LocalizedStringResource = "Play my liked songs"
  static var openAppWhenRun: Bool = true
  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("liked")
    return .result(dialog: "Playing your liked songs")
  }
}

@available(iOS 16.0, *)
struct ShuffleLikedIntent: AppIntent {
  static var title: LocalizedStringResource = "Shuffle my liked songs"
  static var openAppWhenRun: Bool = true
  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("shuffle")
    return .result(dialog: "Shuffling your liked songs")
  }
}

@available(iOS 16.0, *)
struct PlaylistEntity: AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Playlist")
  static var defaultQuery = PlaylistEntityQuery()
  var id: String
  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: LocalizedStringResource(stringLiteral: id)) }
}

@available(iOS 16.0, *)
struct PlaylistEntityQuery: EntityStringQuery {
  func entities(for identifiers: [String]) async throws -> [PlaylistEntity] { identifiers.map { PlaylistEntity(id: $0) } }
  func entities(matching string: String) async throws -> [PlaylistEntity] { [PlaylistEntity(id: string)] }
  func suggestedEntities() async throws -> [PlaylistEntity] { [] }
}

@available(iOS 16.0, *)
struct PlayPlaylistIntent: AppIntent {
  static var title: LocalizedStringResource = "Play a playlist"
  static var openAppWhenRun: Bool = true
  @Parameter(title: "Playlist", requestValueDialog: "Which playlist?")
  var playlist: PlaylistEntity
  static var parameterSummary: some ParameterSummary { Summary("Play playlist \(\.$playlist)") }
  func perform() async throws -> some IntentResult & ProvidesDialog {
    AuroraSiri.send("playlist", playlist.id)
    return .result(dialog: "Playing \(playlist.id)")
  }
}

@available(iOS 16.0, *)
struct AuroraShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: PlaySongIntent(),
      phrases: [
        "Play \(\.$song) on \(.applicationName)",
        "Play \(\.$song) in \(.applicationName)",
        "\(.applicationName) play \(\.$song)",
      ],
      shortTitle: "Play a song",
      systemImageName: "play.circle.fill"
    )
    AppShortcut(
      intent: PlayAskIntent(),
      phrases: [
        "Play music on \(.applicationName)",
        "Play a song on \(.applicationName)",
        "Search \(.applicationName)",
        "Open \(.applicationName) and play",
      ],
      shortTitle: "Play music",
      systemImageName: "music.note"
    )
    AppShortcut(intent: PlayLikedIntent(), phrases: ["Play my liked songs on \(.applicationName)", "Shuffle my liked songs on \(.applicationName)", "Play my favourites on \(.applicationName)"], shortTitle: "Liked songs", systemImageName: "heart.fill")
    AppShortcut(intent: PlayPlaylistIntent(), phrases: ["Play playlist \(\.$playlist) on \(.applicationName)"], shortTitle: "Play a playlist", systemImageName: "music.note.list")
    AppShortcut(intent: PauseMusicIntent(), phrases: ["Pause \(.applicationName)", "Pause the music on \(.applicationName)"], shortTitle: "Pause", systemImageName: "pause.fill")
    AppShortcut(intent: ResumeMusicIntent(), phrases: ["Resume \(.applicationName)", "Resume music on \(.applicationName)"], shortTitle: "Resume", systemImageName: "play.fill")
    AppShortcut(intent: NextSongIntent(), phrases: ["Next song on \(.applicationName)", "Skip on \(.applicationName)"], shortTitle: "Next", systemImageName: "forward.fill")
    AppShortcut(intent: PreviousSongIntent(), phrases: ["Previous song on \(.applicationName)"], shortTitle: "Previous", systemImageName: "backward.fill")
    AppShortcut(intent: LikeSongIntent(), phrases: ["Like this song on \(.applicationName)"], shortTitle: "Like", systemImageName: "heart")
    AppShortcut(intent: WhatsPlayingIntent(), phrases: ["What's playing on \(.applicationName)"], shortTitle: "What's playing", systemImageName: "waveform")
  }
}
