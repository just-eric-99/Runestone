//
//  TextEditor.swift
//  
//
//  Created by Adrian Schönig on 23/5/2022.
//

import SwiftUI
import UIKit

@_exported import Runestone

public var textView = TextView()

public struct RunestoneCaretPosition: Codable {
    var line: Int
    var column: Int
}

public struct TextEditor: UIViewRepresentable {
    
    @Environment(\.themeFontSize) var themeFontSize
    
    enum FindInteractionStyle {
        case disabled
        case find
        case replace
    }
    
    public let text: Binding<String>
    let actualTheme: OverridingTheme
    public var theme: Theme { actualTheme.base }
    public let language: TreeSitterLanguage?
    public let configuration: Configuration
    private var findInteraction: FindInteractionStyle = .disabled
    
    public init(text: Binding<String>, theme: Theme, language: TreeSitterLanguage? = nil, configuration: Configuration = .init()) {
        self.text = text
        self.actualTheme = OverridingTheme(base: theme)
        self.language = language
        self.configuration = configuration
    }
    
    public func makeCoordinator() -> TextEditorCoordinator {
        .init()
    }
    
    public func makeUIView(context: Context) -> UIView {
        textView = TextView()
        textView.apply(configuration)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.characterPairs = BasicCharacterPairs.basicPairs
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        if #available(iOS 16, *) {
            textView.isFindInteractionEnabled = true
        } else {
            // Fallback on earlier versions
        }
        textView.alwaysBounceVertical = true
        textView.contentInsetAdjustmentBehavior = .always
        textView.textContainerInset.left += 8
        textView.smartInsertDeleteType = .no
        textView.textContainerInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        textView.lineSelectionDisplayType = .line
        textView.lineHeightMultiplier = 1.3
        textView.kern = 0.3
        textView.pageGuideColumn = 80
        textView.isAutomaticScrollEnabled = true
        textView.isScrollEnabled = true
        textView.scrollIndicatorInsets = UIEdgeInsets()
        
        textView.editorDelegate = context.coordinator
        context.coordinator.configure(text: text, theme: actualTheme, language: language) { state in
            textView.setState(state)
        }
        
        // We assume your theme matches the device's mode
        textView.backgroundColor = .systemBackground
        
        textView.insertionPointColor = theme.textColor
        textView.selectionBarColor = theme.textColor
        textView.selectionHighlightColor = theme.textColor.withAlphaComponent(0.2)
        
        return textView
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        guard let textView = uiView as? TextView else { return assertionFailure() }
        
//        if let textLocation = textView.textLocation(at: textView.selectedRange.location) {
////            print("Line = \(textLocation.lineNumber + 1), column = \(textLocation.column + 1)")
//            caretPosition = RunestoneCaretPosition(line: textLocation.lineNumber, column: textLocation.column)
//        }
        
        
        // Update from context, such as...
        switch context.environment.disableAutocorrection {
        case .none:        textView.autocorrectionType = .default
        case .some(false): textView.autocorrectionType = .yes
        case .some(true):  textView.autocorrectionType = .no
        }
        
        if let fontSize = themeFontSize, fontSize != actualTheme.font.pointSize {
            actualTheme.font = UIFont(descriptor: theme.font.fontDescriptor, size: fontSize)
            textView.theme = actualTheme
        }
    }
}

extension TextEditor {
    public init(text: String, theme: Theme, language: TreeSitterLanguage? = nil, configuration: Configuration = .init()) {
        var config = configuration
        config.isEditable = false
        self.init(text: .constant(text), theme: theme, language: language, configuration: config)
    }
}

public class TextEditorCoordinator: ObservableObject {
    var text: Binding<String>?
    
    func configure(text: Binding<String>, theme: Theme, language: TreeSitterLanguage?, completion: @escaping (TextViewState) -> Void) {
        self.text = text
        
        DispatchQueue.global(qos: .background).async {
            let state: TextViewState
            if let language = language {
                state = TextViewState(text: text.wrappedValue, theme: theme, language: language)
            } else {
                state = TextViewState(text: text.wrappedValue, theme: theme)
            }
            DispatchQueue.main.async {
                completion(state)
            }
        }
    }
}

extension TextEditorCoordinator: Runestone.TextViewDelegate {
    public func textViewDidChange(_ textView: TextView) {
        text?.wrappedValue = textView.text
    }
}

// MARK: .themeFontSize

public struct ThemeFontSizeKey: EnvironmentKey {
    public static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    public var themeFontSize: Double? {
        get { self[ThemeFontSizeKey.self] }
        set { self[ThemeFontSizeKey.self] = newValue }
    }
}

extension View {
    
    /// Overrides the font size of the `RunestoneUI.TextEditor`'s theme
    /// - Parameter size: Text size in points
    public func themeFontSize(_ size: Double) -> some View {
        environment(\.themeFontSize, size)
    }
}

struct BasicCharacterPairs: CharacterPair {
    var leading: String
    
    var trailing: String
    
    static var basicPairs: [CharacterPair] = [
        BasicCharacterPairs(leading: "(", trailing: ")"),
        BasicCharacterPairs(leading: "{", trailing: "}"),
        BasicCharacterPairs(leading: "[", trailing: "]"),
        BasicCharacterPairs(leading: "\"", trailing: "\""),
        BasicCharacterPairs(leading: "\'", trailing: "\'"),
        BasicCharacterPairs(leading: "`", trailing: "`")
    ]
}
