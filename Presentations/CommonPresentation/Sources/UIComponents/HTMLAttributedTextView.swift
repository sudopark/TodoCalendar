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
    let onLinkTap: ((URL) -> Void)?
    
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
            self.onLinkTap = onLinkTap
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
        
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return textView
    }
    
    public func updateUIView(_ uiView: UITextView, context: Context) {
        guard uiView.attributedText.string != self.attributeText.string
        else { return }
        let fullRange = NSRange(location: 0, length: attributeText.length)
        let mutableText = NSMutableAttributedString(attributedString: self.attributeText)
        mutableText.addAttributes([
            .foregroundColor: appearance.colorSet.text1
        ], range: fullRange)
        uiView.attributedText = mutableText
    }
    
    public func sizeThatFits(
        _ proposal: ProposedViewSize, uiView: UITextView, context: Context
    ) -> CGSize? {
        
        guard let width = proposal.width, width > 0, !width.isInfinite
        else {
            return nil
        }
        
        let proposedSize = CGSize(width: width, height: .infinity)
        let fittingSize = uiView.systemLayoutSizeFitting(
            proposedSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        return .init(width: proposedSize.width, height: fittingSize.height)
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
