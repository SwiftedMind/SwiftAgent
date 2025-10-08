// By Dennis Müller

import Foundation

enum Secret {
  private static let secretsDict: [String: Any]? = loadSecrets()

  enum OpenAI {
    static var apiKey: String {
      value(for: "OpenAI_API_Key_Debug")
    }
  }

  // MARK: - Helpers

  private static func loadSecrets() -> [String: Any]? {
    guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else {
      print("Secrets.plist not found.")
      return nil
    }

    do {
      let data = try Data(contentsOf: url)
      let plist = try PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil,
      )
      guard let dict = plist as? [String: Any] else {
        print("Secrets.plist format is invalid.")
        return nil
      }

      return dict
    } catch {
      print("Could not load Secrets.plist: \(error)")
      return nil
    }
  }

  private static func value<T>(for key: String, defaultValue: T = "") -> T {
    guard let value = secretsDict?[key] as? T else {
      print("Secret key '\(key)' not found or has wrong type in Secrets.plist.")
      // Use default value (often an empty string) to avoid crashes,
      // but log a warning. Depending on the key, a fatalError might be more appropriate.
      // For RevenueCat/TelemetryDeck, an empty string might cause the service to fail gracefully.
      // For AI Proxy, it depends on how the empty values are handled later.
      if T.self == String.self, let emptyString = "" as? T {
        return emptyString
      } else {
        // If we cannot provide a sensible default (e.g., for non-string types
        // or where an empty string is invalid), crashing might be safer.
        // Consider adjusting this based on specific key requirements.
        fatalError("Required secret key '\(key)' is missing or invalid. App cannot continue.")
      }
    }

    return value
  }
}
