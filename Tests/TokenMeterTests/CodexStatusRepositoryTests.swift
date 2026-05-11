import XCTest
@testable import TokenMeter

final class CodexStatusRepositoryTests: XCTestCase {
    func test_returnsUsageMetricWhenSessionRateLimitSnapshotIsAvailable() {
        let repository = CodexStatusRepository(
            sessionRateLimitParser: MockCodexSessionRateLimitParser(
                snapshot: CodexSessionRateLimitSnapshot(
                    primaryUsedPercent: 12,
                    primaryWindowMinutes: 300,
                    primaryResetsAt: Date(timeIntervalSinceNow: 90 * 60),
                    secondaryUsedPercent: 4,
                    secondaryWindowMinutes: 10080,
                    secondaryResetsAt: Date(timeIntervalSinceNow: 3 * 24 * 3600),
                    totalTokens: 150_284,
                    planType: "prolite",
                    observedAt: .now
                )
            ),
            authStateProbe: CodexAuthStateProbe(
                authURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent("missing-auth.json")
            ),
            now: { Date(timeIntervalSince1970: 1_776_800_000) }
        )

        let snapshot = repository.snapshot()

        guard case let .usageMetric(primaryPercentage, secondaryPercentage, subtitle) = snapshot else {
            return XCTFail("Expected usage metric snapshot, got \(snapshot)")
        }
        XCTAssertEqual(primaryPercentage, 12)
        XCTAssertEqual(secondaryPercentage, 4)
        XCTAssertNotNil(subtitle)
        XCTAssertTrue(subtitle?.contains("5h window") == true)
    }

    func test_keepsExpiredPrimaryRateLimitSnapshotWhenItIsLatestLocalMetric() {
        let repository = CodexStatusRepository(
            sessionRateLimitParser: MockCodexSessionRateLimitParser(
                snapshot: CodexSessionRateLimitSnapshot(
                    primaryUsedPercent: 87,
                    primaryWindowMinutes: 300,
                    primaryResetsAt: Date(timeIntervalSince1970: 1_776_799_000),
                    secondaryUsedPercent: 42,
                    secondaryWindowMinutes: 10080,
                    secondaryResetsAt: Date(timeIntervalSince1970: 1_776_900_000),
                    totalTokens: nil,
                    planType: "prolite",
                    observedAt: Date(timeIntervalSince1970: 1_776_798_000)
                )
            ),
            authStateProbe: CodexAuthStateProbe(
                authURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent("missing-auth.json")
            ),
            now: { Date(timeIntervalSince1970: 1_776_800_000) }
        )

        guard case let .usageMetric(primaryPercentage, secondaryPercentage, subtitle) = repository.snapshot() else {
            return XCTFail("Expected usage metric snapshot")
        }

        XCTAssertEqual(primaryPercentage, 87)
        XCTAssertEqual(secondaryPercentage, 42)
        XCTAssertFalse(subtitle?.contains("resets in") == true)
    }

    func test_omitsExpiredSecondaryRateLimitFromUsageSnapshot() {
        let repository = CodexStatusRepository(
            sessionRateLimitParser: MockCodexSessionRateLimitParser(
                snapshot: CodexSessionRateLimitSnapshot(
                    primaryUsedPercent: 21,
                    primaryWindowMinutes: 300,
                    primaryResetsAt: Date(timeIntervalSince1970: 1_776_900_000),
                    secondaryUsedPercent: 75,
                    secondaryWindowMinutes: 10080,
                    secondaryResetsAt: Date(timeIntervalSince1970: 1_776_799_000),
                    totalTokens: nil,
                    planType: "prolite",
                    observedAt: Date(timeIntervalSince1970: 1_776_798_000)
                )
            ),
            authStateProbe: CodexAuthStateProbe(
                authURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent("missing-auth.json")
            ),
            now: { Date(timeIntervalSince1970: 1_776_800_000) }
        )

        guard case let .usageMetric(primaryPercentage, secondaryPercentage, subtitle) = repository.snapshot() else {
            return XCTFail("Expected usage metric snapshot")
        }

        XCTAssertEqual(primaryPercentage, 21)
        XCTAssertNil(secondaryPercentage)
        XCTAssertFalse(subtitle?.contains("7d window") == true)
    }

    func test_returnsLoginRequiredWhenAuthIsMissing() {
        let missingAuthURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("auth.json")
        let repository = CodexStatusRepository(
            sessionRateLimitParser: MockCodexSessionRateLimitParser(snapshot: nil),
            authStateProbe: CodexAuthStateProbe(authURL: missingAuthURL)
        )

        XCTAssertEqual(repository.snapshot(), .loginRequired)
    }

    func test_returnsLoginRequiredWhenAuthIsMalformed() throws {
        let authURL = try makeAuthFixture(contents: "{")
        let repository = CodexStatusRepository(
            sessionRateLimitParser: MockCodexSessionRateLimitParser(snapshot: nil),
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
            sessionRateLimitParser: MockCodexSessionRateLimitParser(snapshot: nil),
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

private struct MockCodexSessionRateLimitParser: CodexSessionRateLimitParsing {
    let snapshot: CodexSessionRateLimitSnapshot?

    func latestSnapshot() -> CodexSessionRateLimitSnapshot? {
        snapshot
    }
}
