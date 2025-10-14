// By Dennis Müller

import Foundation
import struct FoundationModels.GeneratedContent
import SimulatedSession
import SwiftUI

struct CalculatorToolRunView: View {
  var calculatorRun: ToolRun<CalculatorTool>

  var body: some View {
    if let arguments = calculatorRun.normalizedArguments {
      HStack(spacing: 12) {
        operandView(for: arguments.firstNumber)
        operatorView(for: arguments.operation)
        operandView(for: arguments.secondNumber)
      }
      .font(.largeTitle)
      .bold()
      .monospaced()
      .contentTransition(.numericText())
    } else if let error = calculatorRun.error {
      Text("Calculator Run Error: \(error.localizedDescription)")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  @ViewBuilder
  private func operandView(for value: Double?) -> some View {
    Text(value?.formatted() ?? "0")
      .frame(minWidth: 48)
      .blur(radius: value == nil ? 10 : 0)
  }

  @ViewBuilder
  private func operatorView(for value: String?) -> some View {
    Text(value ?? "?")
      .frame(minWidth: 48)
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
    case .emptyArguments:
      "Empty"
    case .firstNumberOnly:
      "First Number"
    case .awaitingSecondNumber:
      "Operation"
    case .completed:
      "Complete"
    case .error:
      "Error"
    }
  }

  var toolRun: ToolRun<CalculatorTool> {
    switch self {
    case .emptyArguments:
      partialRun(
        id: "0",
        argumentsJSON: #"{}"#
      )
    case .firstNumberOnly:
      partialRun(
        id: "0",
        argumentsJSON: #"{ "firstNumber": 234.0 }"#
      )
    case .awaitingSecondNumber:
      partialRun(
        id: "0",
        argumentsJSON: #"{ "firstNumber": 234.0, "operation": "+" }"#
      )
    case .completed:
      completedRun(
        id: "0",
        firstNumber: 234.0,
        operation: "+",
        secondNumber: 6.0
      )
    case .error:
      errorRun(id: "0")
    }
  }
}

private extension CalculatorToolRunPreviewScenario {
  func partialRun(id: String, argumentsJSON: String) -> ToolRun<CalculatorTool> {
    let rawArguments = generatedContent(fromJson: argumentsJSON)
    let partiallyGeneratedArguments = try! CalculatorTool.Arguments.PartiallyGenerated(rawArguments)

    return ToolRun<CalculatorTool>(
      id: id,
      arguments: .partial(partiallyGeneratedArguments),
      output: nil,
      problem: nil,
      rawArguments: rawArguments,
      rawOutput: nil
    )
  }

  func completedRun(
    id: String,
    firstNumber: Double,
    operation: String,
    secondNumber: Double
  ) -> ToolRun<CalculatorTool> {
    let arguments = CalculatorTool.Arguments(
      firstNumber: firstNumber,
      operation: operation,
      secondNumber: secondNumber
    )

    let rawArguments = generatedContent(
      fromJson: #"{ "firstNumber": \#(firstNumber), "operation": "\#(operation)", "secondNumber": \#(secondNumber) }"#
    )

    let result = evaluate(firstNumber: firstNumber, operation: operation, secondNumber: secondNumber)
    let output = CalculatorTool.Output(
      result: result,
      expression: "\(firstNumber) \(operation) \(secondNumber) = \(result)"
    )

    let rawOutput = generatedContent(
      fromJson: #"{ "result": \#(result), "expression": "\#(output.expression)" }"#
    )

    return ToolRun<CalculatorTool>(
      id: id,
      arguments: .final(arguments),
      output: output,
      problem: nil,
      rawArguments: rawArguments,
      rawOutput: rawOutput
    )
  }

  func errorRun(id: String) -> ToolRun<CalculatorTool> {
    ToolRun<CalculatorTool>(
      id: id,
      output: nil,
      problem: nil,
      error: TranscriptDecodingError.ToolRunResolution.resolutionFailed(
        description: "Preview failed to resolve tool run"
      ),
      rawArguments: GeneratedContent(kind: .null),
      rawOutput: nil
    )
  }

  func evaluate(firstNumber: Double, operation: String, secondNumber: Double) -> Double {
    switch operation {
    case "+":
      firstNumber + secondNumber
    case "-":
      firstNumber - secondNumber
    case "*":
      firstNumber * secondNumber
    case "/":
      secondNumber == 0 ? .infinity : firstNumber / secondNumber
    default:
      .nan
    }
  }

  func generatedContent(fromJson json: String) -> GeneratedContent {
    try! GeneratedContent(json: json)
  }
}
