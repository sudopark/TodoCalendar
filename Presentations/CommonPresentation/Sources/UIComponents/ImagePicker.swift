//
//  ImagePicker.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import PhotosUI
import UniformTypeIdentifiers


// MARK: - ImagePickSource

public enum ImagePickSource: Sendable, Equatable {

    case photoLibrary
    case camera

    @MainActor
    public var isAvailable: Bool {
        switch self {
        case .photoLibrary: return true
        case .camera: return UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }
}


// MARK: - ImagePicker

/// 소스별 시스템 피커를 만들어 선택 결과를 이미지 Data로 넘긴다.
/// 시스템 피커가 delegate를 weak으로 잡으므로 호출측이 이 인스턴스를 붙들고 있어야 한다.
public final class ImagePicker: NSObject, @unchecked Sendable {

    private enum Constant {
        static let cameraJpegQuality: CGFloat = 0.9
    }

    private var onPick: ((Data?) -> Void)?

    public override init() {
        super.init()
    }

    @MainActor
    public func makeViewController(
        source: ImagePickSource,
        onPick: @escaping (Data?) -> Void
    ) -> UIViewController {
        self.onPick = onPick
        switch source {
        case .photoLibrary: return self.makePhotoLibraryPicker()
        case .camera: return self.makeCameraPicker()
        }
    }

    @MainActor
    private func makePhotoLibraryPicker() -> UIViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        return picker
    }

    @MainActor
    private func makeCameraPicker() -> UIViewController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        return picker
    }

    @MainActor
    private func finish(_ viewController: UIViewController, with data: Data?) {
        let handler = self.onPick
        self.onPick = nil
        viewController.dismiss(animated: true) {
            handler?(data)
        }
    }
}


// MARK: - PHPickerViewControllerDelegate

extension ImagePicker: PHPickerViewControllerDelegate {

    public func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        guard let provider = results.first?.itemProvider,
              provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        else {
            self.finish(picker, with: nil)
            return
        }

        // loadDataRepresentation 콜백은 백그라운드 큐다 — 소비측 계약을 메인으로 고정한다.
        provider.loadDataRepresentation(
            forTypeIdentifier: UTType.image.identifier
        ) { data, _ in
            Task { @MainActor in
                self.finish(picker, with: data)
            }
        }
    }
}


// MARK: - UIImagePickerControllerDelegate

extension ImagePicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = info[.originalImage] as? UIImage
        let data = image?.jpegData(compressionQuality: Constant.cameraJpegQuality)
        self.finish(picker, with: data)
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.finish(picker, with: nil)
    }
}
