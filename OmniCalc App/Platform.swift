import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Cross-platform helpers so the same code runs on iPhone, iPad, Mac and Apple Vision.
extension Color {
    static var cardBackground: Color { Color.primary.opacity(0.07) }
    static var chipBackground: Color { Color.primary.opacity(0.10) }
    static var keyUtilBackground: Color { Color.primary.opacity(0.18) }
}

extension View {
    func numericKeyboard() -> some View {
        #if os(macOS)
        return self
        #else
        return self.keyboardType(.numbersAndPunctuation)
        #endif
    }

    func inlineTitle() -> some View {
        #if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }
}

func copyToClipboard(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #else
    UIPasteboard.general.string = text
    #endif
}
