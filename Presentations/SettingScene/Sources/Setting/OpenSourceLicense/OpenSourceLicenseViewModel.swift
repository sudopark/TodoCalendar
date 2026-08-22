//
//  OpenSourceLicenseViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Scenes


// MARK: - models

struct OpenSourceLibrary: Decodable, Equatable, Sendable {
    let name: String
    let copyright: String
    let license: String
    let sourceURL: String
}

struct OpenSourceLicenseText: Decodable, Equatable, Sendable {
    let name: String
    let text: String
}

struct OpenSourceLicenseNotice: Decodable, Equatable, Sendable {
    let libraries: [OpenSourceLibrary]
    let licenses: [OpenSourceLicenseText]
}


// MARK: - OpenSourceLicenseViewModel

protocol OpenSourceLicenseViewModel: AnyObject, Sendable, OpenSourceLicenseSceneInteractor {

    // interactor
    func prepare()
    func selectLibrary(_ name: String)
    func close()
    
    // presenter
    var libraries: AnyPublisher<[OpenSourceLibrary], Never> { get }
    var licenses: AnyPublisher<[OpenSourceLicenseText], Never> { get }
}


// MARK: - OpenSourceLicenseViewModelImple

final class OpenSourceLicenseViewModelImple: OpenSourceLicenseViewModel, @unchecked Sendable {
    
    var router: (any OpenSourceLicenseRouting)?
    
    private struct Subject {
        let notice = CurrentValueSubject<OpenSourceLicenseNotice?, Never>(nil)
    }
    
    private let subject = Subject()
}


// MARK: - OpenSourceLicenseViewModelImple Interactor

extension OpenSourceLicenseViewModelImple {
    
    func prepare() {
        let notice = self.loadNotice()
        self.subject.notice.send(notice)
    }
    
    private func loadNotice() -> OpenSourceLicenseNotice {
        guard let url = Bundle.module.url(
                forResource: "open-source-licenses", withExtension: "json"
              ),
              let data = try? Data(contentsOf: url),
              let notice = try? JSONDecoder().decode(OpenSourceLicenseNotice.self, from: data)
        else {
            return .init(libraries: [], licenses: [])
        }
        return notice
    }
    
    func selectLibrary(_ name: String) {
        guard let library = self.subject.notice.value?.libraries.first(where: { $0.name == name })
        else { return }
        self.router?.openSafari(library.sourceURL)
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - OpenSourceLicenseViewModelImple Presenter

extension OpenSourceLicenseViewModelImple {
    
    var libraries: AnyPublisher<[OpenSourceLibrary], Never> {
        return self.subject.notice
            .compactMap { $0?.libraries }
            .eraseToAnyPublisher()
    }
    
    var licenses: AnyPublisher<[OpenSourceLicenseText], Never> {
        return self.subject.notice
            .compactMap { $0?.licenses }
            .eraseToAnyPublisher()
    }
}
