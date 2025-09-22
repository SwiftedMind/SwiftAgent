# Updates to AttributedString Support in Foundation

## Overview

AttributedString is a powerful Swift type in the Foundation framework that allows developers to create and manipulate text with styling attributes. Recent updates have enhanced its capabilities, making it more flexible and powerful for text handling in Apple platforms. This guide covers the key features and updates to AttributedString in Foundation, focusing on its modern API design, improved text manipulation capabilities, and integration with the text system across Apple platforms.

## Core AttributedString Concepts

### Creating AttributedStrings

```swift
// Basic initialization
let attributedText = AttributedString("Hello, world!")

// From a substring
let range = attributedText.range(of: "world")!
let substring = attributedText[range]
let newString = AttributedString(substring)

// With attributes applied
var attributed = AttributedString("Bold text")
attributed.font = .boldSystemFont(ofSize: 16)
```

### Working with Attributes

```swift
// Setting attributes
var text = AttributedString("Styled text")
text.foregroundColor = .red
text.backgroundColor = .yellow
text.font = .systemFont(ofSize: 14)

// Applying attributes to ranges
let range = text.range(of: "Styled")!
text[range].underlineStyle = .single
text[range].underlineColor = .blue
```

## Text Alignment and Formatting

AttributedString provides built-in support for text alignment and paragraph styling:

```swift
// Setting text alignment
var paragraph = AttributedString("Centered paragraph of text")
let style = NSMutableParagraphStyle()
style.alignment = .center
paragraph.paragraphStyle = style

// Using the TextAlignment enum
paragraph.alignment = .center // Using AttributedString.TextAlignment.center
```

### TextAlignment Options

AttributedString includes a TextAlignment enumeration with these cases:

```swift
enum TextAlignment {
    case left      // Left-aligned text
    case right     // Right-aligned text
    case center    // Center-aligned text
    // Additional platform-specific options may be available
}
```

## Writing Direction Support

Control text direction with the WritingDirection enum:

```swift
// Setting writing direction
var text = AttributedString("Hello عربي")
text.writingDirection = .rightToLeft // For RTL languages

// Available options
enum WritingDirection {
    case leftToRight  // Standard LTR text (English, etc.)
    case rightToLeft  // RTL text (Arabic, Hebrew, etc.)
}
```

## Line Height Control

Fine-tune line spacing with the LineHeight structure:

```swift
// Setting line height
var multiline = AttributedString("This is a paragraph\nwith multiple lines\nof text.")
multiline.lineHeight = AttributedString.LineHeight.exact(points: 32)
multiline.lineHeight = AttributedString.LineHeight.multiple(factor: 2.5)
multiline.lineHeight = AttributedString.LineHeight.loose
```

## Text Selection and Editing

AttributedString provides powerful APIs for text selection and editing:

```swift
// Replace selection with plain text
var text = AttributedString("Here is my dog")
var selection = AttributedTextSelection(range: text.range(of: "dog")!)
text.replaceSelection(&selection, withCharacters: "cat")

// Replace selection with attributed content
let replacement = AttributedString("horse")
text.replaceSelection(&selection, with: replacement)
```

## UTF-8 View

Access the raw UTF-8 representation of the string content:

```swift
let text = AttributedString("Hello")
let utf8 = text.utf8
for codeUnit in utf8 {
    print(codeUnit)
}
```

## DiscontiguousAttributedSubstring

Work with non-contiguous selections of text:

```swift
// Creating a discontiguous substring
let text = AttributedString("Select multiple parts of this text")
let range1 = text.range(of: "Select")!
let range2 = text.range(of: "text")!
let rangeSet = RangeSet([range1, range2])
var substring = text[rangeSet]
substring.backgroundColor = .yellow

// Converting back to AttributedString
let combined = AttributedString(substring)
```

## Integration with SwiftUI

AttributedString works seamlessly with SwiftUI's text components:

```swift
import SwiftUI

struct AttributedTextView: View {
    var body: some View {
        Text(AttributedString("Styled text in SwiftUI"))
            .foregroundColor(.blue)
    }
}
```

You can use AttributedString with SwiftUI's TextEditor:

```swift
import SwiftUI

struct CommentEditor: View {
    @Binding var commentText: AttributedString

    var body: some View {
        TextEditor(text: $commentText)
    }
}
```

AttributedString can also be used with AttributedTextSelection to represent a selection of attributed text.

```swift
struct SuggestionTextEditor: View {
    @State var text: AttributedString = ""
    @State var selection = AttributedTextSelection()


    var body: some View {
        VStack {
            TextEditor(text: $text, selection: $selection)
            // A helper view that offers live suggestions based on selection.
            SuggestionsView(substrings: getSubstrings(
                text: text, indices: selection.indices(in: text))
        }
    }


    private func getSubstrings(
        text: String, indices: AttributedTextSelection.Indices
    ) -> [Substring] {
        // Resolve substrings representing the current selection...
    }
}


struct SuggestionsView: View { ... }
```

You can also use the textSelectionAffinity(_:) modifier to specify a selection affinity on the given hierarchy:

```swift
struct SuggestionTextEditor: View {
    @State var text: AttributedString = ""
    @State var selection = AttributedTextSelection()


    var body: some View {
        VStack {
            TextEditor(text: $text, selection: $selection)
            // A helper view that offers live suggestions based on selection.
            SuggestionsView(substrings: getSubstrings(
                text: text, indices: selection.indices(in: text))
        }
        .textSelectionAffinity(.upstream)
    }


    private func getSubstrings(
        text: String, indices: AttributedTextSelection.Indices
    ) -> [Substring] {
        // Resolve substrings representing the current selection...
    }
}


struct SuggestionsView: View { ... }
```


## References

- [Apple Developer Documentation: AttributedString](https://developer.apple.com/documentation/Foundation/AttributedString)
- [Apple Developer Documentation: AttributedString.TextAlignment](https://developer.apple.com/documentation/Foundation/AttributedString/TextAlignment)
- [Apple Developer Documentation: AttributedString.LineHeight](https://developer.apple.com/documentation/Foundation/AttributedString/LineHeight)
- [Apple Developer Documentation: DiscontiguousAttributedSubstring](https://developer.apple.com/documentation/Foundation/DiscontiguousAttributedSubstring)
