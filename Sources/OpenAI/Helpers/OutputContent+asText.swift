// By Dennis Müller

import Foundation
import OpenAI

extension Components.Schemas.OutputContent {
	enum ExtractedTextSegment {
		case text(String)
		case refusal(String)
	}

	var extractedTextSegment: ExtractedTextSegment? {
		switch self {
		case let .OutputTextContent(outputTextContent):
			.text(outputTextContent.text)
		case let .RefusalContent(refusalContent):
			.refusal(refusalContent.refusal)
		}
	}
}
