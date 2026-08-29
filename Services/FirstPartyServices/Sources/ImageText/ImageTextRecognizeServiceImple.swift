//
//  ImageTextRecognizeServiceImple.swift
//  FirstPartyServices
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Vision
import ImageIO
import Extensions
import Domain


public final class ImageTextRecognizeServiceImple: ImageTextRecognizeService, Sendable {

    public init() { }
}

extension ImageTextRecognizeServiceImple {

    private enum Constant {
        // share extension 메모리 제한 대비 다운샘플 상한
        static let maxPixelSize: CGFloat = 2048
    }

    public func recognizeTextLines(in imageData: Data) async throws -> [String] {
        let cancelHandle = TextRecognizeCancelHandle()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let lines = try self.recognizedLines(
                            in: imageData, cancelHandle: cancelHandle
                        )
                        continuation.resume(returning: lines)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancelHandle.cancel()
        }
    }

    private func downsampledImage(from imageData: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw RuntimeError(key: "invalidImageData", "failed to decode image data")
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Constant.maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw RuntimeError(key: "invalidImageData", "failed to downsample image")
        }
        return thumbnail
    }

    private func recognizedLines(
        in imageData: Data,
        cancelHandle: TextRecognizeCancelHandle
    ) throws -> [String] {
        let cgImage = try self.downsampledImage(from: imageData)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true
        try cancelHandle.register(request)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            try cancelHandle.throwIfCancelled()
            throw error
        }
        try cancelHandle.throwIfCancelled()

        let observations = request.results ?? []
        let recognizedTexts = observations.compactMap { $0.topCandidates(1).first?.string }
        return recognizedTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}


// MARK: - TextRecognizeCancelHandle

/// 실행 중인 OCR request를 Task 취소 시점에 끊기 위한 핸들.
/// 등록·취소가 서로 다른 스레드에서 일어나므로 lock으로 보호한다.
private final class TextRecognizeCancelHandle: @unchecked Sendable {

    private let lock = NSLock()
    private var request: VNRecognizeTextRequest?
    private var isCancelled: Bool = false

    func register(_ request: VNRecognizeTextRequest) throws {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self.isCancelled == false else { throw CancellationError() }
        self.request = request
    }

    func cancel() {
        self.lock.lock()
        defer { self.lock.unlock() }

        self.isCancelled = true
        self.request?.cancel()
    }

    func throwIfCancelled() throws {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self.isCancelled else { return }
        throw CancellationError()
    }
}
