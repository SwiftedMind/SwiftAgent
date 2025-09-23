// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OpenAI
import OSLog
import SwiftAgent

/// The model to use for generating a response.
public enum OpenAIModel: Equatable, Hashable, Sendable, AdapterModel {
	case gpt5
	case gpt5_mini
	case gpt5_nano
	case gpt4o
	case gpt4o_ini
	case o4_mini
	case other(String, isReasoning: Bool = false)

	public var rawValue: String {
		// The OpenAI SDK defines the models as extensions on String
		switch self {
		case .gpt5: String.gpt5
		case .gpt5_mini: String.gpt5_mini
		case .gpt5_nano: String.gpt5_nano
		case .gpt4o: String.gpt4_o
		case .gpt4o_ini: String.gpt4_o_mini
		case .o4_mini: String.o4_mini
		case let .other(name, _): name
		}
	}

	public static let `default`: OpenAIModel = .gpt5
}

public extension OpenAIModel {
	var isReasoning: Bool {
		switch self {
		case .gpt5,
		     .gpt5_mini,
		     .gpt5_nano,
				 .o4_mini:
			true
		case let .other(_, isReasoning):
			isReasoning
		default: false
		}
	}
}
