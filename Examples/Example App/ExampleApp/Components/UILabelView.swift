// By Dennis Müller

import SwiftUI
import UIKit

// From: https://gist.github.com/mrackwitz/91395527a37c4cea1757d76e8e99f826

struct UILabelView: UIViewRepresentable {
  var string: String
  var preferredMaxLayoutWidth: CGFloat = .greatestFiniteMagnitude

  func makeUIView(context: UIViewRepresentableContext<UILabelView>) -> UILabel {
    let label = UILabel(frame: .zero)
    label.numberOfLines = 0
    label.setContentHuggingPriority(.required, for: .vertical)
    label.setContentCompressionResistancePriority(.required, for: .vertical)
    label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    updateUIView(label, context: context)
    return label
  }

  func updateUIView(_ label: UILabel, context: UIViewRepresentableContext<UILabelView>) {
    label.text = string
    label.preferredMaxLayoutWidth = preferredMaxLayoutWidth
  }
}

struct HorizontalGeometryReader<Content: View>: View {
  var content: (CGFloat) -> Content
  @State private var width: CGFloat = 0

  init(@ViewBuilder content: @escaping (CGFloat) -> Content) {
    self.content = content
  }

  var body: some View {
    content(width)
      .frame(minWidth: 0, maxWidth: .infinity)
      .background(
        GeometryReader { geometry in
          Color.clear
            .preference(key: WidthPreferenceKey.self, value: geometry.size.width)
        },
      )
      .onPreferenceChange(WidthPreferenceKey.self) { width in
        self.width = width
      }
  }
}

private struct WidthPreferenceKey: PreferenceKey, Equatable {
  static var defaultValue: CGFloat = 0

  /// An empty reduce implementation takes the first value
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {}
}
