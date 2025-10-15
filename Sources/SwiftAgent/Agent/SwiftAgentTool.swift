// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// A thin wrapper around Apple's `FoundationModels.Tool` protocol that constrains its arguments and output to
/// `Generable` types.
///
/// - Note: You do not conform to this protocol directly. When you define a language model session and pass a `@Tool`
/// property, the macro will synthesize a conformance to this protocol.
///
/// ## Example
///
/// ```swift
/// @LanguageModelProvider(.openAI)
/// final class Session {
///   @Tool var calculator = CalculatorTool()
/// }
///
/// struct CalculatorTool: Tool {
///   let name = "calculator"
///   let description = "Performs basic mathematical addition"
///
///   @Generable
///   struct Arguments {
///     let a: Int
///     let b: Int
///   }
///
///   @Generable
///   struct Output {
///     let result: Int
///   }
///
///   func call(arguments: Arguments) async throws -> Output {
///     .init(result: arguments.a + arguments.b)
///   }
/// }
/// ```
public protocol SwiftAgentTool: FoundationModels.Tool where Arguments: Generable, Output: Generable {}
