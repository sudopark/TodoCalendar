//
//  
//  EventTagDetailViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 2023/10/03.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


struct OriginalTagInfo {
    let id: AllEventTagId
    let name: String
    let color: EventTagColor
}

// MARK: - EventTagDetailViewModel

protocol EventTagDetailViewModel: AnyObject, Sendable, EventTagDetailSceneInteractor {

    // interactor
    func selectColor(_ color: String)
    func enterName(_ name: String)
    func delete()
    func save()
    
    // presenter
    var originalName: String? { get }
    var originalColor: EventTagColor { get }
    var selectedColor: AnyPublisher<EventTagColor, Never> { get }
    
    var isNameChangable: Bool { get }
    var isDeletable: Bool { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
}


// MARK: - EventTagDetailViewModelImple

final class EventTagDetailViewModelImple: EventTagDetailViewModel, @unchecked Sendable {
    
    private let originalInfo: OriginalTagInfo?
    private let eventTagUsecase: EventTagUsecase
    var router: (any EventTagDetailRouting)?
    var listener: (any EventTagDetailSceneListener)?
    
    init(
        originalInfo: OriginalTagInfo?,
        eventTagUsecase: EventTagUsecase
    ) {
        self.originalInfo = originalInfo
        self.eventTagUsecase = eventTagUsecase
        
        self.subject.name.send(originalInfo?.name)
        self.subject.color.send(originalInfo?.color)
    }
    
    
    private struct Subject {
        let name = CurrentValueSubject<String?, Never>(nil)
        let color = CurrentValueSubject<EventTagColor?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventTagDetailViewModelImple Interactor

extension EventTagDetailViewModelImple {
    
    func enterName(_ name: String) {
        self.subject.name.send(name)
    }
    
    func selectColor(_ color: String) {
        self.subject.color.send(.custom(hex: color))
    }
    
    func delete() {
        guard case let .custom(id) = self.originalInfo?.id else { return }
        let confirmed: () -> Void = { [weak self] in
            self?.deleteTag(id)
        }
        let info = ConfirmDialogInfo()
            |> \.message .~ "[TODO] delte alert message".localized()
            |> \.confirmed .~ pure(confirmed)
        self.router?.showConfirm(dialog: info)
    }
    
    private func deleteTag(_ tagId: String) {
        Task { [weak self] in
            do {
                try await self?.eventTagUsecase.deleteTag(tagId)
                self?.show(message: "[TODO] delete message") { [weak self] in
                    self?.listener?.evetTag(deleted: tagId)
                }
            } catch {
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    func save() {
        switch self.originalInfo?.id {
        case .holiday:
             // TODO: change holiday color
            break
        case .default:
            // TODO: change default color
            break
        case .custom(let id):
            self.editTag(id)
            
        case nil:
            self.saveNewTag()
        }
    }
    
    private func editTag(_ id: String) {
        guard let name = self.subject.name.value,
              let colorHext = self.subject.color.value?.customHex
        else { return }
        let params = EventTagEditParams(name: name, colorHex: colorHext)
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let newTag = try await self.eventTagUsecase.editTag(id, params)
                self.show(message: "[TODO] edited messagte".localized()) {
                    self.listener?.eventTag(updated: newTag)
                }
            } catch {
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func saveNewTag() {
        guard let name = self.subject.name.value,
              let colorHex = self.subject.color.value?.customHex
        else { return }
        let params = EventTagMakeParams(name: name, colorHex: colorHex)
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let newTag = try await self.eventTagUsecase.makeNewTag(params)
                self.show(message: "[TODO] make message") {
                    self.listener?.eventTag(created: newTag)
                }
            } catch {
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func show(
        message: String,
        andCloseWith notify: @Sendable @escaping () -> Void
    ) {
        self.router?.showToast(message)
        self.router?.closeScene(animate: true) {
            notify()
        }
    }
}


// MARK: - EventTagDetailViewModelImple Presenter

extension EventTagDetailViewModelImple {
    
    var originalName: String? {
        return self.originalInfo?.name
    }
    var originalColor: EventTagColor {
        return self.originalInfo?.color ?? .default
    }
    
    var selectedColor: AnyPublisher<EventTagColor, Never> {
        return self.subject.color
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isNameChangable: Bool {
        switch self.originalInfo?.id {
        case .custom, .none: return true
        default: return false
        }
    }
    
    var isDeletable: Bool {
        guard case .custom = self.originalInfo?.id
        else { return false }
        return true
    }
    
    var isSavable: AnyPublisher<Bool, Never> {
        let transform: (String?, EventTagColor?) -> Bool = { name, color in
            return name?.isEmpty == false && color != nil
        }
        return Publishers.CombineLatest(
            self.subject.name,
            self.subject.color
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}
