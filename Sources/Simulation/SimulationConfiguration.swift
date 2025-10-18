// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OSLog
import SwiftAgent

public struct SimulationConfiguration: Sendable {
  public var generationDelay: Duration
  public var tokenUsage: TokenUsage?
  public var defaultGenerations: [SimulatedGeneration]

  public init(
    defaultGenerations: [SimulatedGeneration],
    generationDelay: Duration = .seconds(2),
    tokenUsage: TokenUsage? = nil,
  ) {
    self.defaultGenerations = defaultGenerations
    self.generationDelay = generationDelay
    self.tokenUsage = tokenUsage
  }
}

public enum SimulationConfigurationError: Error, LocalizedError, Sendable {
  case missingGenerations

  public var errorDescription: String? {
    "No simulated generations are available for this simulation run."
  }
}
