// By Dennis Müller

import Foundation
import FoundationModels

extension GeneratedContent {
  /// A stable JSON string representation whose dictionary keys are deterministically sorted.
  ///
  /// FoundationModels currently emits unsorted keys for `jsonString`, which produces semantically
  /// equivalent payloads that differ byte-for-byte. Those differences undermine response caching
  /// because requests miss whenever key order changes. This accessor reserializes the content with
  /// sorted keys so downstream systems receive a consistent payload while Apple works on an
  /// upstream fix.
  public var stableJsonString: String {
    guard let sortedJSONString = sortedJSONString(from: jsonString) else {
      return jsonString
    }

    return sortedJSONString
  }

  /// Attempts to reorder dictionary keys deterministically within the supplied JSON string.
  ///
  /// The method round-trips the JSON through `JSONSerialization` using the `sortedKeys` option so
  /// that dictionaries are emitted in alphabetical order. If decoding or encoding fails, the
  /// original JSON string is unsuitable for stable sorting and the caller should fall back to it.
  private func sortedJSONString(from jsonString: String) -> String? {
    guard let data = jsonString.data(using: .utf8) else {
      return nil
    }

    do {
      let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers, .fragmentsAllowed])
      guard JSONSerialization.isValidJSONObject(jsonObject) else {
        return nil
      }

      let sortedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])
      guard let sortedString = String(data: sortedData, encoding: .utf8) else {
        return nil
      }

      return sortedString
    } catch {
      return nil
    }
  }
}
