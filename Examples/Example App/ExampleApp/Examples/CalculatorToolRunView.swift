// By Dennis Müller

import Foundation
import struct FoundationModels.GeneratedContent
import SimulatedSession
import SwiftUI

struct CalculatorToolRunView: View {
  var calculatorRun: ToolRun<CalculatorTool>

  var body: some View {
    if let arguments = calculatorRun.normalizedArguments {
      VStack(spacing: 5) {
        HStack(spacing: 10) {
          operandView(for: arguments.firstNumber)
          operatorView(for: arguments.operation)
          operandView(for: arguments.secondNumber)
        }
        .scaleEffect(calculatorRun.hasOutput ? 0.8 : 1)
        .opacity(calculatorRun.hasOutput ? 0.5 : 1)
        .geometryGroup()
        if let output = calculatorRun.output {
          Capsule()
            .frame(width: 150, height: 2)
            .transition(.opacity.combined(with: .scale))
          operandView(for: output.result)
            .transition(.opacity.combined(with: .scale))
        }
      }
      .geometryGroup()
    } else if let error = calculatorRun.error {
      Text("Calculator Error: \(error.localizedDescription)")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  @ViewBuilder
  private func operandView(for value: Double?) -> some View {
    Text(value?.formatted() ?? "0")
      .font(.largeTitle)
      .bold()
      .monospaced()
      .contentTransition(.numericText())
      .blur(radius: value == nil ? 10 : 0)
  }

  @ViewBuilder
  private func operatorView(for value: String?) -> some View {
    Text(value ?? "?")
      .font(.largeTitle)
      .bold()
      .monospaced()
      .foregroundStyle(.secondary)
      .blur(radius: value == nil ? 10 : 0)
  }
}

#Preview("Calculator Tool Run") {
  @Previewable @State var selectedScenario: CalculatorToolRunPreviewScenario = .emptyArguments

  VStack {
    Spacer()
    CalculatorToolRunView(calculatorRun: selectedScenario.toolRun)
      .frame(maxWidth: .infinity)
      .animation(.default, value: selectedScenario.toolRun)
    Spacer()
    Picker("Scenario", selection: $selectedScenario) {
      ForEach(CalculatorToolRunPreviewScenario.allCases) { scenario in
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

private enum CalculatorToolRunPreviewScenario: String, CaseIterable, Identifiable {
  case emptyArguments
  case firstNumberOnly
  case awaitingSecondNumber
  case completed
  case error

  var id: String { rawValue }

  var label: LocalizedStringKey {
    switch self {
    case .emptyArguments: "Empty"
    case .firstNumberOnly: "1"
    case .awaitingSecondNumber: "2"
    case .completed: "3"
    case .error: "Error"
    }
  }

  var toolRun: ToolRun<CalculatorTool> {
    switch self {
    case .emptyArguments:
      try! ToolRun<CalculatorTool>.partial(
        id: "0",
        json: #"{}"#,
      )
    case .firstNumberOnly:
      try! ToolRun<CalculatorTool>.partial(
        id: "0",
        json: #"{ "firstNumber": 234.0 }"#,
      )
    case .awaitingSecondNumber:
      try! ToolRun<CalculatorTool>.partial(
        id: "0",
        json: #"{ "firstNumber": 234.0, "operation": "+" }"#,
      )
    case .completed:
      try! ToolRun<CalculatorTool>.completed(
        id: "0",
        json: #"{ "firstNumber": 234.0, "operation": "+", "secondNumber": 6.0 }"#,
        output: CalculatorTool.Output(result: 240),
      )
    case .error:
      try! ToolRun<CalculatorTool>.error(
        id: "0",
        error: .resolutionFailed(description: "Something went wrong"),
      )
    }
  }
}
