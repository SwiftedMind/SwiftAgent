// By Dennis Müller

import Foundation
import OSLog

package extension Logger {
  nonisolated(unsafe) static var main: Logger = .init(OSLog.disabled)
}
