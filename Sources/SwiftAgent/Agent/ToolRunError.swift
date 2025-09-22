// By Dennis Müller

import Foundation
import FoundationModels

/// An error that indicates a tool run failed and cannot be recovered automatically.
public struct ToolRunError: Error, LocalizedError {
	/// The tool that produced the error.
	public var tool: any FoundationModels.Tool

	/// The underlying error that was thrown during the tool run.
	public var underlyingError: any Error

	/// Creates an unrecoverable tool run error.
	///
	/// - Parameters:
	///   - tool: The tool that produced the error.
	///   - underlyingError: The underlying error thrown by the tool run.
	public init(tool: any Tool, underlyingError: any Error) {
		self.tool = tool
		self.underlyingError = underlyingError
	}

	/// A string representation of the error description.
	public var errorDescription: String? {
		let toolName = String(describing: type(of: tool))
		let underlyingDescription = (underlyingError as? LocalizedError)?.errorDescription ?? underlyingError
			.localizedDescription
		return "Tool '\(toolName)' failed: \(underlyingDescription)"
	}
}
