// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// A thin wrapper around Apple's `FoundationModels.Tool` protocol that provides essential functionality
/// for SwiftAgent's tool calling system.
///
/// `SwiftAgentTool` extends Apple's native tool protocol with type-safe argument and output handling,
/// custom resolution logic, and seamless integration with SwiftAgent's agent execution loop.
///
/// ## Overview
///
/// The SwiftAgent framework builds on Apple's FoundationModels design philosophy by providing a
/// clean, declarative API for AI tool development. `AgentTool` serves as the bridge between
/// Apple's tool protocol and SwiftAgent's enhanced capabilities.
///
/// ## Usage
///
/// ```swift
/// struct WeatherTool: SwiftAgentTool {
///
///   let name = "get_weather"
///   let description = "Get current weather for a location"
///
///   @Generable
///   struct Arguments {
///     let location: String
///   }
///
///   @Generable
///   struct Output {
///     let temperature: Double
///     let conditions: String
///   }
/// }
/// ```
public protocol SwiftAgentTool: FoundationModels.Tool, Encodable, Equatable where Arguments: Generable,
  Output: Generable {}
