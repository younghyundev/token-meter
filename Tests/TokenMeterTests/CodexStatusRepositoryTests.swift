import XCTest
@testable import TokenMeter

final class CodexStatusRepositoryTests: XCTestCase {
    func test_returnsLoginRequiredWhenAuthIsMissing() {
        let missingAuthURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        let repository = CodexStatusRepository(
            authStateProbe: CodexAuthStateProbe(authURL: missingAuthURL)
        )

        XCTAssertEqual(repository.snapshot(), .loginRequired)
    }

    func test_returnsLoginRequiredWhenAuthIsMalformed() throws {
        let authURL = try makeAuthFixture(contents: "{")
        let repository = CodexStatusRepository(
            authStateProbe: CodexAuthStateProbe(authURL: authURL)
        )

        XCTAssertEqual(repository.snapshot(), .loginRequired)
    }

    func test_returnsAvailabilityOnlyWhenAuthIsAvailable() throws {
        let authURL = try makeAuthFixture(
            contents: """
            {
              "tokens": {
                "opaque": "secret-value"
              }
            }
            """
        )
        let repository = CodexStatusRepository(
            authStateProbe: CodexAuthStateProbe(authURL: authURL)
        )

        XCTAssertEqual(
            repository.snapshot(),
            .availabilityOnly(
                title: "Codex available",
                subtitle: "Current Codex session is authenticated on this Mac."
            )
        )
    }

    private func makeAuthFixture(contents: String) throws -> URL {
        let authURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        try FileManager.default.createDirectory(
            at: authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: authURL, atomically: true, encoding: .utf8)
        return authURL
    }
}
