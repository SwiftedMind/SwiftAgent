// By Dennis Müller

import Foundation
import struct FoundationModels.GeneratedContent
import OpenAISession
import SwiftUI

struct WeatherToolRunView: View {
  var weatherRun: ToolRun<WeatherTool>

  var body: some View {
    GroupBox("Weather") {
      if let arguments = weatherRun.currentArguments {
        VStack(spacing: 12) {
          VStack(spacing: 6) {
            GroupBox("City") {
              Text(displayText(for: arguments.location, placeholder: "Location"))
                .font(.callout)
                .contentTransition(.interpolate)
                .blur(radius: arguments.location == nil ? 10 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(weatherRun.hasOutput ? 0.5 : 1)
            if let requestedDate = arguments.requestedDate {
              argumentPill(title: "Date", value: requestedDate, placeholder: "Date")
                .opacity(weatherRun.hasOutput ? 0.5 : 1)
            }
            if let timeOfDay = arguments.timeOfDay {
              argumentPill(title: "Time", value: timeOfDay, placeholder: "Time")
                .opacity(weatherRun.hasOutput ? 0.5 : 1)
            }
          }

          if let output = weatherRun.output {
            GroupBox("Result") {
              VStack(spacing: 8) {
                Text(output.condition)
                  .font(.callout)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .multilineTextAlignment(.leading)
                measurementView(label: "Temperature", value: "\(output.temperature)°C")
                measurementView(label: "Humidity", value: "\(output.humidity)%")
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .transition(.opacity.combined(with: .scale))
            }
          }
        }
        .frame(maxWidth: .infinity)
        .geometryGroup()
        .clipped()
        .animation(.default, value: weatherRun.output?.condition ?? "")
      } else if let error = weatherRun.error {
        Text("Weather Tool Error: \(error.localizedDescription)")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  private func argumentPill(title: LocalizedStringKey, value: String?, placeholder: String) -> some View {
    GroupBox(title) {
      Text(displayText(for: value, placeholder: placeholder))
        .font(.callout)
        .contentTransition(.interpolate)
        .blur(radius: value == nil ? 10 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func measurementView(label: LocalizedStringKey, value: String) -> some View {
    Text("\(Text(label).bold()): \(value)")
      .font(.callout)
      .monospacedDigit()
      .contentTransition(.numericText())
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func displayText(for value: String?, placeholder: String) -> String {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return placeholder
    }

    return value
  }
}

#Preview("Weather Tool Run") {
  @Previewable @State var selectedScenario: WeatherToolRunPreviewScenario = .emptyArguments

  VStack {
    Spacer()
    WeatherToolRunView(weatherRun: selectedScenario.toolRun)
      .frame(maxWidth: .infinity)
      .animation(.default, value: selectedScenario.toolRun)
    Spacer()
    Picker("Scenario", selection: $selectedScenario) {
      ForEach(WeatherToolRunPreviewScenario.allCases) { scenario in
        Text(scenario.label)
          .tag(scenario)
      }
    }
    .pickerStyle(.segmented)
  }
  .padding()
  .animation(.default, value: selectedScenario)
  .preferredColorScheme(.dark)
}

private enum WeatherToolRunPreviewScenario: String, CaseIterable, Identifiable {
  case emptyArguments
  case locationOnly
  case awaitingTime
  case completed
  case error

  var id: String { rawValue }

  var label: LocalizedStringKey {
    switch self {
    case .emptyArguments: "Empty"
    case .locationOnly: "1"
    case .awaitingTime: "2"
    case .completed: "Done"
    case .error: "Error"
    }
  }

  var toolRun: ToolRun<WeatherTool> {
    switch self {
    case .emptyArguments:
      try! ToolRun<WeatherTool>.partial(
        id: "weather-000",
        json: #"{}"#,
      )
    case .locationOnly:
      try! ToolRun<WeatherTool>.partial(
        id: "weather-001",
        json: #"{ "location": "San Fran" }"#,
      )
    case .awaitingTime:
      try! ToolRun<WeatherTool>.partial(
        id: "weather-002",
        json: #"{ "location": "San Francisco", "requestedDate": "2024-04-01" }"#,
      )
    case .completed:
      try! ToolRun<WeatherTool>.completed(
        id: "weather-003",
        json: #"{ "location": "San Francisco", "requestedDate": "2024-04-01", "timeOfDay": "Afternoon" }"#,
        output: WeatherTool.Output(
          location: "San Francisco",
          temperature: 20,
          condition: "Sunny - Afternoon forecast for 2024-04-01",
          humidity: 55,
        ),
      )
    case .error:
      try! ToolRun<WeatherTool>.error(
        id: "weather-004",
        error: .resolutionFailed(description: "Unable to locate weather station"),
      )
    }
  }
}
