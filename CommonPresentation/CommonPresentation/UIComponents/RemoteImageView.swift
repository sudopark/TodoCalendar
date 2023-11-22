//
//  RemoteImageView.swift
//  CommonPresentation
//
//  Created by sudo.park on 11/23/23.
//

import SwiftUI
import Kingfisher
import Extensions

public struct RemoteImageView: View {
    
    private let sourceURL: URL?
    private let targetSize: CGSize?
    
    var configurations: [(KFImage) -> KFImage] = []
    
    public init(_ sourcePath: String, targetSize: CGSize? = nil) {
        self.sourceURL = sourcePath.asURL()
        self.targetSize = targetSize
    }
    
    public var body: some View {
        return Group {
            self.configurations
                .reduce(self.initailImage()) { $1($0) }
                .downSamplingIfNeed(self.targetSize)
                .cancelOnDisappear(true)
                .cacheOriginalImage()
        }
    }
    
    private func initailImage() -> KFImage {
        if let path = self.sourceURL?.absoluteString,
           path.hasPrefix("file://"),
           let fileURL = URL(string: path) {
            
            let provider = LocalFileImageDataProvider(fileURL: fileURL)
            return KFImage(source: .provider(provider))
            
        } else {
            return KFImage(sourceURL)
        }
    }
    
    private func addConfigure(_ block: @escaping (KFImage) -> KFImage) -> RemoteImageView {
        var sender = self
        sender.configurations = self.configurations + [block]
        return sender
    }
}

extension RemoteImageView {
    
    public func resize(
        capInsets: EdgeInsets = EdgeInsets(),
        resizeMode: Image.ResizingMode = .stretch
    ) -> RemoteImageView {
        
        let block: (KFImage) -> KFImage = { $0.resizable(capInsets: capInsets, resizingMode: resizeMode) }
        return self.addConfigure(block)
    }
    
    public func renderingMode(_ renderingMode: Image.TemplateRenderingMode) -> RemoteImageView {
        let block: (KFImage) -> KFImage = { $0.renderingMode(renderingMode) }
        return self.addConfigure(block)
    }
    
    public func interpolation(_ interpolation: Image.Interpolation) -> RemoteImageView {
        let block: (KFImage) -> KFImage = { $0.interpolation(interpolation) }
        return self.addConfigure(block)
    }
    
    public func antialiased(_ isAntialiased: Bool) -> RemoteImageView {
        let block: (KFImage) -> KFImage = { $0.antialiased(isAntialiased) }
        return self.addConfigure(block)
    }
}

private extension KFImage {
    
    @MainActor
    func downSamplingIfNeed(_ resize: CGSize?) -> KFImage {
        guard let resize else { return self }
        let scale = UIScreen.main.scale
        let size = CGSize(
            width: resize.width * scale,
            height: resize.height * scale
        )
        return self.downsampling(size: size)
    }
}
