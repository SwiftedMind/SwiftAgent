// By Dennis Müller

import FoundationModels
import OpenAISession
import SwiftUI

/*

 TODOS:
 - Example: A text label (with the input, fixed, not a text field) and a button "Generate" -> Then UI streams in the response
 - Update #tool to allow customization of the enum name!
 - Think about transcript resolution and if you could simplify the other cases as well
 - Go through the OpenAIAdapter streaming logic and see if you can simplify it or at least make it more readable and check for correctness
 - In AgentSnapshot, add a method "collect()" that turns the snapshot into a response, like in FoundationModels
 - In AgentSnapshot, add logic to populate the output content (final response from the transcript) after the stream is finished
 - Go through the entire "streaming flow" to check if it's fine and nicely useable.

 */

@main
struct ExampleApp: App {
	init() {
		// Enable logging for development
		SwiftAgentConfiguration.setLoggingEnabled(true)
		SwiftAgentConfiguration.setNetworkLoggingEnabled(true)
	}

	var body: some Scene {
		WindowGroup {
			ExampleListView()
		}
	}
}
