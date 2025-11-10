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
    var originalColorHex: AnyPublisher<String, Never> { get }
    var suggestColorHexes: [String] { get }
    var selectedColorHex: AnyPublisher<String, Never> { get }
    
    var isNameChangable: Bool { get }
    var isDeletable: Bool { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isProcessing: AnyPublisher<Bool, Never> { get }
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
        
        let initialColor = originalInfo?.colorHex ?? self.suggestColorHexes.randomElement()
        self.subject.color.send(initialColor)
    }
    
    
    private struct Subject {
        let name = CurrentValueSubject<String?, Never>(nil)
        let color = CurrentValueSubject<String?, Never>(nil)
        let isProcessing = CurrentValueSubject<Bool, Never>(false)
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
        self.subject.color.send(color)
    }
    
    func delete() {
        guard case let .custom(id) = self.originalInfo?.id else { return }
        let onlyRemoveTag = ActionSheetForm.Action("eventTag.remove::only_tag".localized()) { [weak self] in
            self?.deleteTag(id)
        }
        let withAllEvents = ActionSheetForm.Action("eventTag.remove::tag_and_evets".localized(), style: .destructive) { [weak self] in
            self?.deleteTagWithEvents(id)
        }
        let cancelAction = ActionSheetForm.Action("common.cancel".localized(), style: .cancel)
        let form = ActionSheetForm()
            |> \.message .~ "eventTag.remove::confirm::message".localized()
            |> \.actions .~ [onlyRemoveTag, withAllEvents, cancelAction]
        self.router?.showActionSheet(form)
    }
    
    private func deleteTag(_ tagId: String) {
        self.subject.isProcessing.send(true)
        Task { [weak self] in
            do {
                try await self?.eventTagUsecase.deleteTag(tagId)
                self?.show(message: "eventTag.removed::message".localized()) { [weak self] in
                    self?.listener?.eventTag(deleted: .custom(tagId))
                }
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isProcessing.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func deleteTagWithEvents(_ tagId: String) {
        self.subject.isProcessing.send(true)
        Task { [weak self] in
            do {
                try await self?.eventTagUsecase.deleteTagWithAllEvents(tagId)
                self?.show(message: "eventTag.removed_with_events::message".localized()) { [weak self] in
                    self?.listener?.eventTag(deleted: .custom(tagId))
                }
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isProcessing.send(false)
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
            
        case .externalCalendar:
            break
            
        case nil:
            self.saveNewTag()
        }
    }
    
    private func changeBaseTagColor(isHoliday: Bool) {
        guard let newColor = self.subject.color.value else { return }
        let params  = if isHoliday {
            EditDefaultEventTagColorParams() |> \.newHolidayTagColor .~ newColor
        } else {
            EditDefaultEventTagColorParams() |> \.newDefaultTagColor .~ newColor
        }
        self.subject.isProcessing.send(true)
        Task { [weak self] in
            do {
                let _ = try await self?.uiSettingUsecase.changeDefaultEventTagColor(params)
                self?.router?.showToast("eventTag.color::changed::message".localized())
                self?.router?.closeScene()
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isProcessing.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func editTag(_ id: String) {
        guard let name = self.subject.name.value,
              let colorHex = self.subject.color.value
        else { return }
        let params = CustomEventTagEditParams(name: name, colorHex: colorHex)
        
        self.subject.isProcessing.send(true)
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
            self.subject.isProcessing.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func saveNewTag() {
        guard let name = self.subject.name.value,
              let colorHex = self.subject.color.value
        else { return }
        let params = CustomEventTagMakeParams(name: name, colorHex: colorHex)
        
        self.subject.isProcessing.send(true)
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
            self.subject.isProcessing.send(false)
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
    
    var originalColorHex: AnyPublisher<String, Never> {
        return self.subject.color
            .compactMap { $0 }
            .first()
            .eraseToAnyPublisher()
    }
    
    var suggestColorHexes: [String] {
        return [
            "#F42D2D", "#F9316D", "#FF5722", "#FD838F", "#FFA02E", "#F6DC41", "#B75F17",
            "#6800f2", "#9370DB", "#6A5ACD", "#4034AB", "#1E90FF", "#4682B4", "#5F9EA0",
            "#4561DB", "#5e86d6", "#87CEEB", "#088CDA", "#AFEEEE", "#036A73", "#3CB371",
            "#06A192", "#41E6EC", "#72E985", "#CCD0DC", "#828DA9", "#8DACF6",
        ]
    }
    
    var selectedColorHex: AnyPublisher<String, Never> {
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
        let transform: (String?, String?) -> Bool = { name, color in
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
    
    var isProcessing: AnyPublisher<Bool, Never> {
        return self.subject.isProcessing
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
