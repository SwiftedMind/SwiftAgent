// By Dennis Müller

import FoundationModels
import OpenAISession
import SwiftUI

@main
struct ExampleApp: App {
  init() {
    // Enable logging for development
    SwiftAgentConfiguration.setLoggingEnabled(true)
    SwiftAgentConfiguration.setNetworkLoggingEnabled(false)
  }

  var body: some Scene {
    WindowGroup {
      AgentPlaygroundView()
    }
  }
}
