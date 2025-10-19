// By Dennis Müller

import Foundation
import SwiftAgent

public struct SimulationGenerationOptions: AdapterGenerationOptions {
  public typealias Model = SimulationModel
  public typealias GenerationOptionsError = SimulationGenerationOptionsError

  public enum SimulationGenerationOptionsError: Error, LocalizedError, Sendable {
    case noGenerationsAvailable

    public var errorDescription: String? {
      "No simulated generations are available for this simulation run."
    }
  }

  public var minimumStreamingSnapshotInterval: Duration?
  public var simulatedGenerations: [SimulatedGeneration]
  public var tokenUsageOverride: TokenUsage?

  public init(
    simulatedGenerations: [SimulatedGeneration] = [],
    minimumStreamingSnapshotInterval: Duration? = nil,
    tokenUsageOverride: TokenUsage? = nil,
  ) {
    self.simulatedGenerations = simulatedGenerations
    self.minimumStreamingSnapshotInterval = minimumStreamingSnapshotInterval
    self.tokenUsageOverride = tokenUsageOverride
  }

  public init() {
    self.init(simulatedGenerations: [])
  }

  public static func automatic(for model: SimulationModel) -> SimulationGenerationOptions {
    SimulationGenerationOptions()
  }

  public func validate(for model: SimulationModel) throws(SimulationGenerationOptionsError) {}
}
