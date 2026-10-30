import Testing
@testable import SPasteCore

struct CommandTests {
    @Test func parsesSimpleNames() throws {
        #expect(try Command.parse("down") == .down)
        #expect(try Command.parse(" half-up ") == .halfUp)
        #expect(try Command.parse("wipe") == .wipe(confirmed: false))
        #expect(try Command.parse("wipe!") == .wipe(confirmed: true))
        #expect(throws: Command.ParseError.badArgument(command: "down", reason: "takes no argument")) {
            try Command.parse("down 3")
        }
        #expect(throws: Command.ParseError.unknown("fly")) {
            try Command.parse("fly")
        }
        #expect(throws: Command.ParseError.empty) {
            try Command.parse("  ")
        }
    }

    @Test func parsesTypes() throws {
        #expect(try Command.parse("type image") == .type([.image]))
        #expect(try Command.parse("type image files") == .type([.image, .file]))
        #expect(try Command.parse("type all") == .type([]))
        #expect(try Command.parse("type") == .type([]))
        #expect(throws: Command.ParseError.self) {
            try Command.parse("type video")
        }
    }

    @Test func parsesTimes() throws {
        #expect(try Command.parse("since 2h") == .since(.ago(minutes: 120)))
        #expect(try Command.parse("until yesterday") == .until(.yesterday))
        #expect(try Command.parse("since") == .since(nil))
        #expect(throws: Command.ParseError.self) {
            try Command.parse("since later")
        }
    }

    @Test func settingsAndExport() throws {
        #expect(try Command.parse("settings") == .settings)
        #expect(try Command.parse("export") == .export(""))
        #expect(try Command.parseCommandLine("export ~/a b.zip") == .export("~/a b.zip"))
    }

    @Test func commandLineAliases() throws {
        #expect(try Command.parseCommandLine("q") == .close)
        #expect(try Command.parseCommandLine("quit") == .close)
        #expect(try Command.parseCommandLine("since today") == .since(.today))
    }

    @Test func everyNameParses() {
        for name in Command.names {
            #expect((try? Command.parse(name)) != nil, "\(name)")
        }
    }
}
