//
//  EventTagListViewUsecase.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


// MARK: - base calednar event tag

struct BaseCalendarEventTagCellViewModel: Equatable {
    
    var isOn: Bool = true
    let id: EventTagId
    let name: String
    var colorHex: String?
    
    init(_ tag: any EventTag) {
        self.id = tag.tagId
        self.name = tag.name
        self.colorHex = tag.colorHex
    }
}

// MARK: - external calendar event tag

struct ExternalCalendarEventTagCellViewModel: Equatable {
    
    var isOn: Bool = true
    let id: EventTagId
    let name: String
    var backgroundColor: String?
    var foregroundColor: String?
    var colorId: String?
    
    init(_ tag: ExternalCalendarEventTag) {
        self.id = tag.tagId
        self.name = tag.name
        self.backgroundColor = tag.colorHex
        self.foregroundColor = tag.foregroundColorHex
        self.colorId = tag.colorId
    }
}

struct ExternalCalendarEventTagListSectionModel: Equatable {
    let serviceId: String
    let serviceTitle: String
    var icon: String?
    let cellViewModels: [ExternalCalendarEventTagCellViewModel]
    
    init(
        serviceId: String,
        serviceTitle: String,
        icon: String? = nil,
        cellViewModels: [ExternalCalendarEventTagCellViewModel],
        offIds: Set<EventTagId>
    ) {
        self.serviceId = serviceId
        self.serviceTitle = serviceTitle
        self.icon = icon
        self.cellViewModels = cellViewModels
            .map { $0 |> \.isOn .~ !offIds.contains($0.id) }
    }
}


final class EventTagListViewUsecase {
    
    private let tagUsecase: any EventTagUsecase
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    init(
        tagUsecase: any EventTagUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase
    ) {
        self.tagUsecase = tagUsecase
        self.googleCalendarUsecase = googleCalendarUsecase
    }
    
    private let allTags = CurrentValueSubject<[any EventTag]?, Never>(nil)
    private let occuredError = PassthroughSubject<any Error, Never>()
    private var cancellables: Set<AnyCancellable> = []
}

extension EventTagListViewUsecase {
    
    func reload() {
        
        let loaded: ([any EventTag]) -> Void = { [weak self] tags in
            self?.allTags.send(tags)
        }
        
        let handleError: (any Error) -> Void = { [weak self] error in
            self?.occuredError.send(error)
        }
        
        self.tagUsecase.loadAllEventTags()
            .sink(receiveValue: loaded, receiveError: handleError)
            .store(in: &self.cancellables)
    }
    
    func reloadExternalCalendarIfNeed() {
        self.googleCalendarUsecase.integratedAccount
            .first()
            .sink(receiveValue: { [weak self] account in
                guard account != nil else { return }
                self?.googleCalendarUsecase.refreshGoogleCalendarEventTags()
            })
            .store(in: &self.cancellables)
    }
}

extension EventTagListViewUsecase {
    
    var reloadFailed: AnyPublisher<any Error, Never> {
        return self.occuredError
            .eraseToAnyPublisher()
    }
    
    var baseCalenadrCellViewModels: AnyPublisher<[BaseCalendarEventTagCellViewModel], Never> {
        let asCellViewModels: ([any EventTag]) -> [BaseCalendarEventTagCellViewModel] = { tags in
            return tags
                .sortDefaultTagsAtFirst()
                .map { BaseCalendarEventTagCellViewModel($0) }
        }
        
        let applyOnOff: ([BaseCalendarEventTagCellViewModel], Set<EventTagId>) -> [BaseCalendarEventTagCellViewModel] = { cvms, offTagIdSet in
            
            return cvms
                .map { $0 |> \.isOn .~ !offTagIdSet.contains($0.id) }
            
        }
        
        return Publishers.CombineLatest(
            self.allTags.compactMap { $0 }.map(asCellViewModels),
            self.tagUsecase.offEventTagIdsOnCalendar()
        )
        .map(applyOnOff)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var externalCalendars: AnyPublisher<[ExternalCalendarEventTagListSectionModel], Never> {
        
        let transform: ([ExternalCalendarEventTagCellViewModel], Set<EventTagId>) -> [ExternalCalendarEventTagListSectionModel]
        transform = { googles, offIds in
            
            let googleSection = ExternalCalendarEventTagListSectionModel(
                serviceId: GoogleCalendarService.id,
                serviceTitle: "event_setting::external_calendar::google::serviceName".localized(),
                icon: "google_calendar_icon",
                cellViewModels: googles,
                offIds: offIds
            )
            
            return [googleSection]
        }
        
        return Publishers.CombineLatest(
            self.googleCalendarTags,
            self.tagUsecase.offEventTagIdsOnCalendar()
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    private var googleCalendarTags: AnyPublisher<[ExternalCalendarEventTagCellViewModel], Never> {
        
        let transform: ([GoogleCalendar.Tag]) -> [ExternalCalendarEventTagCellViewModel] = { tags in
            return tags
                .map { ExternalCalendarEventTag($0) }
                .map { ExternalCalendarEventTagCellViewModel($0) }
        }
        
        return self.googleCalendarUsecase.calendarTags
            .map(transform)
            .eraseToAnyPublisher()
    }
}
