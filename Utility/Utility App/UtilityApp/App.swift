// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import SwiftUI

@main
struct UtilityApp: App {
  init() {
    SwiftAgentConfiguration.setLoggingEnabled(false)
    SwiftAgentConfiguration.setNetworkLoggingEnabled(false)
  }

  var body: some Scene {
    WindowGroup {
      RecordingDashboardView()
    }
  }
}

struct RecordingDashboardView: View {
  @State private var activeScenarioIdentifier: RecordingScenario.ID?
  @State private var statusMessage: String?
  private var scenarios: [RecordingScenario] = RecordingScenario.sampleScenarios

  var body: some View {
    NavigationStack {
      List(scenarios) { scenario in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(scenario.title)
              .font(.headline)
            Spacer(minLength: 0)
            if activeScenarioIdentifier == scenario.id {
              ProgressView()
            }
          }

          Text(scenario.details)
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Button {
            runScenario(scenario)
          } label: {
            Text("Record Scenario")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .disabled(activeScenarioIdentifier != nil)
        }
        .padding(.vertical, 8)
      }
      .navigationTitle("Agent Recorder")
      .safeAreaBar(edge: .bottom) {
        Text(statusMessage ?? "Ready")
          .contentTransition(.interpolate)
          .padding()
      }
    }
  }

  private func runScenario(_ scenario: RecordingScenario) {
    Task { @MainActor in
      activeScenarioIdentifier = scenario.id
      statusMessage = "Recording…"

      do {
        let configuration = OpenAIConfiguration.recording(apiKey: Secret.OpenAI.apiKey)
        let adapter = OpenAIAdapter(
          tools: scenario.tools,
          instructions: scenario.instructions,
          configuration: configuration,
        )
        try await scenario.execute(adapter)
        statusMessage = "Finished \(scenario.title)"
      } catch {
        statusMessage = "Error: \(error.localizedDescription)"
      }

      activeScenarioIdentifier = nil
    }
  }
}

#Preview {
  RecordingDashboardView()
}
