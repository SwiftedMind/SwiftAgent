// By Dennis Müller

import Foundation
import OSLog

/// ``SwiftAgentConfiguration`` is an enumeration providing static methods for configuring
/// global behaviors of the SwiftAgent SDK, such as enabling or disabling logging features.
/// 
/// Use the static methods to control aspects like general SDK logging and network logging,
/// which may be useful for debugging or diagnostics. All methods are designed to be used
/// on the main actor to ensure thread safety for shared resources.
public enum SwiftAgentConfiguration {
  /// Enables or disables logging for the SDK.
  /// - Parameter enabled: Pass `true` to enable logging, `false` to disable.
  @MainActor public static func setLoggingEnabled(_ enabled: Bool) {
    if enabled {
      Logger.main = Logger(subsystem: "SwiftAgent", category: "SDK")
    } else {
      Logger.main = Logger(OSLog.disabled)
    }
  }

  /// Enables or disables network request/response logging.
  /// - Parameter enabled: Pass `true` to enable network logging, `false` to disable.
  @MainActor public static func setNetworkLoggingEnabled(_ enabled: Bool) {
    NetworkLog.isEnabled = enabled
  }
}
