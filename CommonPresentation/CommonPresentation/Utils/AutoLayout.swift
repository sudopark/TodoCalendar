//
//  AutoLayout.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/27.
//

import UIKit


@MainActor
public struct AutoLayout {
    
    private let wrappedView: UIView
    public init(view: UIView) {
        self.wrappedView = view
        self.wrappedView.translatesAutoresizingMaskIntoConstraints = false
    }
}


extension UIView {
    
    public var autoLayout: AutoLayout {
        return AutoLayout(view: self)
    }
}


@resultBuilder
public struct AutoLayoutBuilder {

    public static func buildBlock(_ components: (NSLayoutConstraint)...) -> [NSLayoutConstraint] {
        
        return components
    }
}


extension AutoLayout {
    
    public func make(@AutoLayoutBuilder _ builder: (UIView) -> [NSLayoutConstraint]) -> [NSLayoutConstraint] {
        return builder(self.wrappedView)
    }
    
    @discardableResult
    public func active(@AutoLayoutBuilder _ builder: (UIView) -> [NSLayoutConstraint]) -> AutoLayout {
        let constraints = builder(self.wrappedView)
        NSLayoutConstraint.activate(constraints)
        return self
    }
    
    public func make(with otherView: UIView, @AutoLayoutBuilder _ builder: (UIView, UIView) -> [NSLayoutConstraint]) -> [NSLayoutConstraint] {
        return builder(self.wrappedView, otherView)
    }
    
    @discardableResult
    public func active(with otherView: UIView, @AutoLayoutBuilder _ builder: (UIView, UIView) -> [NSLayoutConstraint]) -> AutoLayout {
        let constraints = builder(self.wrappedView, otherView)
        NSLayoutConstraint.activate(constraints)
        return self
    }
}


extension AutoLayout {
    
    public func makeFill(_ targetView: UIView, edges: UIEdgeInsets = .zero, withSafeArea: Bool = false) -> [NSLayoutConstraint] {
        
        if withSafeArea {
            return self.wrappedView.autoLayout.make(with: targetView) {
                $0.leadingAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.leadingAnchor, constant: edges.left)
                $0.topAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.topAnchor, constant: edges.top)
                $0.bottomAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.bottomAnchor, constant: -edges.bottom)
                $0.trailingAnchor.constraint(equalTo: $1.safeAreaLayoutGuide.trailingAnchor, constant: -edges.right)
            }
        } else {
            return self.wrappedView.autoLayout.make(with: targetView) {
                $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor, constant: edges.left)
                $0.topAnchor.constraint(equalTo: $1.topAnchor, constant: edges.top)
                $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor, constant: -edges.bottom)
                $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor, constant: -edges.right)
            }
        }
    }
    
    public func fill(_ targetView: UIView, edges: UIEdgeInsets = .zero, withSafeArea: Bool = false) {
        
        NSLayoutConstraint.activate(self.makeFill(targetView, edges: edges, withSafeArea: withSafeArea))
    }
}


extension NSLayoutConstraint {
    
    public func setupPriority(_ newValue: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = newValue
        return self
    }
}

