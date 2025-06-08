//
//  HTMLAttributedTextView.swift
//  CommonPresentation
//
//  Created by sudo.park on 5/30/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import SwiftUI
import UIKit


public struct HTMLAttributedTextView: UIViewRepresentable {
    
    @EnvironmentObject private var appearance: ViewAppearance
    let attributeText: NSAttributedString
    var onLinkTap: ((URL) -> Void)?
    
    public init(_ attributeText: NSAttributedString, _ onLinkTap: ((URL) -> Void)? = nil) {
        self.attributeText = attributeText
        self.onLinkTap = onLinkTap
    }
    
    public init(htmlText: String, _ onLinkTap: ((URL) -> Void)? = nil) {
        guard let data = htmlText.data(using: .utf8),
                let nsAttributeText = try? NSMutableAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ], documentAttributes: nil
                )
        else {
            self.attributeText = .init()
            return
        }
        self.attributeText = nsAttributeText
        self.onLinkTap = onLinkTap
    }
    
    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        return textView
    }
    
    public func updateUIView(_ uiView: UITextView, context: Context) {
        let fullRange = NSRange(location: 0, length: attributeText.length)
        let mutableText = NSMutableAttributedString(attributedString: self.attributeText)
        mutableText.addAttributes([
            .foregroundColor: appearance.colorSet.text1
        ], range: fullRange)
        uiView.attributedText = mutableText
    }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    public class Coordinator: NSObject, UITextViewDelegate {
        
        public var parent: HTMLAttributedTextView?
        
        init(parent: HTMLAttributedTextView? = nil) {
            self.parent = parent
        }
        
        public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            parent?.onLinkTap?(URL)
            return false
        }
    }
}
