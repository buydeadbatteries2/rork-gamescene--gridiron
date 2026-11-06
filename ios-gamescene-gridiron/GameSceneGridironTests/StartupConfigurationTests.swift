import Foundation
import Testing
@testable import GameSceneGridiron

/// Read the processed app bundle, not a fixture or the source plist. The same
/// assertions apply to a Release test host; DEBUG alone permits Google's test ID.
@MainActor
struct StartupConfigurationTests {
    @Test func bundledAdMobAppIdentifierIsExpandedAndValidForThisBuild() throws {
        #expect(Bundle.main.bundleIdentifier == "app.rork.gtppc6wle7e0ofcnebp83")
        let raw = try #require(Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String)
        #expect(!raw.isEmpty)
        #expect(!raw.contains("$("))
        #expect(!raw.contains("${"))
        #expect(!raw.contains("/"), "An ad-unit ID must never be used as the app ID")
        #expect(AdMobConfig.isAppIdentifier(raw))
        #expect(AdMobConfig.appIdentifier(
            isDevelopmentBuild: AdManager.isDevelopmentBuild,
            injectedAppID: raw
        ) == raw, "The SDK reads the actual plist, not an in-memory fallback")
        if !AdManager.isDevelopmentBuild {
            #expect(raw != AdMobConfig.googleTestAppID, "Release must contain a production app ID")
        }
    }

    @Test func bundledSKAdNetworkItemsAreDictionaries() throws {
        let entries = try #require(Bundle.main.object(forInfoDictionaryKey: "SKAdNetworkItems") as? [Any])
        #expect(!entries.isEmpty)
        let dictionaries = try #require(entries as? [[String: Any]],
            "Every SKAdNetworkItems entry must be a dictionary, never a string")
        var identifiers: [String] = []
        for entry in dictionaries {
            let identifier = try #require(entry["SKAdNetworkIdentifier"] as? String)
            #expect(identifier.range(of: #"^[a-z0-9]{10}\.skadnetwork$"#, options: .regularExpression) != nil)
            identifiers.append(identifier)
        }
        #expect(identifiers.contains("cstr6suwn9.skadnetwork"))
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test func bundledTrackingUsageDescriptionIsNonempty() throws {
        let description = try #require(Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") as? String)
        #expect(!description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(!description.contains("$("))
    }

    @Test func productionStartupRejectsMissingUnexpandedAndAdUnitIDs() {
        for raw in ["", " \n", "$(ADMOB_APP_ID_VALUE)", "$(ADMOB_IOS_APP_ID)",
                    "${ADMOB_IOS_APP_ID}", "ca-app-pub-3940256099942544/2435281174",
                    AdMobConfig.googleTestAppID] {
            let selected = AdMobConfig.appIdentifier(isDevelopmentBuild: false, injectedAppID: raw)
            #expect(selected == nil)
            #expect(!MobileAdsStartGate.shouldStart(hasStarted: false, appIdentifier: selected))
        }
    }
}
