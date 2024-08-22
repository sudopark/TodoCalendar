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
    var suggestColorHexes: [String] { get }
    var selectedColor: AnyPublisher<EventTagColor, Never> { get }
    
    var isNameChangable: Bool { get }
    var isDeletable: Bool { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
}


// MARK: - EventTagDetailViewModelImple

final class EventTagDetailViewModelImple: EventTagDetailViewModel, @unchecked Sendable {
    
    private let originalInfo: OriginalTagInfo?
    private let eventTagUsecase: any EventTagUsecase
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any EventTagDetailRouting)?
    var listener: (any EventTagDetailSceneListener)?
    
    init(
        originalInfo: OriginalTagInfo?,
        eventTagUsecase: any EventTagUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.originalInfo = originalInfo
        self.eventTagUsecase = eventTagUsecase
        self.uiSettingUsecase = uiSettingUsecase
        
        self.subject.name.send(originalInfo?.name)
        self.subject.color.send(
            originalInfo?.color ?? self.suggestColorHexes.randomElement().map { .custom(hex: $0) }
        )
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
            |> \.message .~ "eventTag.remove::confirm::message".localized()
            |> \.confirmed .~ pure(confirmed)
        self.router?.showConfirm(dialog: info)
    }
    
    private func deleteTag(_ tagId: String) {
        Task { [weak self] in
            do {
                try await self?.eventTagUsecase.deleteTag(tagId)
                self?.show(message: "eventTag.removed::message".localized()) { [weak self] in
                    self?.listener?.eventTag(deleted: tagId)
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
            self.changeBaseTagColor(isHoliday: true)
            
        case .default:
            self.changeBaseTagColor(isHoliday: false)
            
        case .custom(let id):
            self.editTag(id)
            
        case nil:
            self.saveNewTag()
        }
    }
    
    private func changeBaseTagColor(isHoliday: Bool) {
        guard let newColor = self.subject.color.value?.customHex else { return }
        let params  = if isHoliday {
            EditDefaultEventTagColorParams() |> \.newHolidayTagColor .~ newColor
        } else {
            EditDefaultEventTagColorParams() |> \.newDefaultTagColor .~ newColor
        }
        Task { [weak self] in
            do {
                let newSetting = try await self?.uiSettingUsecase.changeDefaultEventTagColor(params)
                self?.router?.showToast("eventTag.color::changed::message".localized())
                self?.router?.closeScene()
            } catch {
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
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
                self.show(message: "eventTag.changed::message".localized()) {
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
                self.show(message: "eventTag.makeNew::message".localized()) {
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
    
    var suggestColorHexes: [String] {
        return [
            "#F42D2D", "#F9316D", "#FD838F", "#4034AB", "#4561DB",
            "#088CDA", "#41E6EC", "#06A192", "#036A73", "#72E985", "#F6DC41", "#FFA02E",
            "#FF5722", "#B75F17", "#CCD0DC", "#828DA9", "#8DACF6",
        ]
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
