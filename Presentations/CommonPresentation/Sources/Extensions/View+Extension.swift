//
//  View+Extension.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/11.
//

import SwiftUI
import Prelude
import Optics

extension View {
    
    public func asAnyView() -> AnyView {
        return AnyView(self)
    }
    
    public func eventHandler<Handler>(
        _ keyPath: WritableKeyPath<Self, Handler>,
        _ handler: Handler
    ) -> Self {
        return self |> keyPath .~ handler
    }
}


extension View {
    
    public func onWillAppear(_ perform: @escaping () -> Void) -> some View {
        modifier(WillAppearModifier(callback: perform))
    }
}

struct WillAppearModifier: ViewModifier {
    
    let callback: () -> Void
    
    func body(content: Content) -> some View {
        content.background(
            UIViewLiftCycleHandler(onWillAppear: callback)
        )
    }
}

struct UIViewLiftCycleHandler: UIViewControllerRepresentable {
    
    typealias UIViewControllerType = UIViewController
    
    var onWillAppear: () -> Void = { }
    
    func makeUIViewController(context: Context) -> UIViewController {
        context.coordinator
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
    
    func makeCoordinator() -> Self.Coordinator {
        Coordinator(onWillAppear: onWillAppear)
    }
    
    class Coordinator: UIViewControllerType {
        
        let onWillAppear: () -> Void
        init(onWillAppear: @escaping () -> Void) {
            self.onWillAppear = onWillAppear
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            onWillAppear()
        }
    }
}
