//
//  SelectGoogleCalendarDialogViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 11/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions
import EventDomainInterface
import ExternalCalendarDomainInterface


// MARK: - SelectGoogleCalendarDialogViewModel

protocol SelectGoogleCalendarDialogViewModel: AnyObject, Sendable, SelectGoogleCalendarDialogSceneInteractor {

    // interactor
    func toggleCalendar(_ id: EventTagId)
    func close()

    // presenter
    var accountId: String { get }
    var calendars: AnyPublisher<[ExternalCalendarEventTagCellViewModel], Never> { get }
}


// MARK: - SelectGoogleCalendarDialogViewModelImple

final class SelectGoogleCalendarDialogViewModelImple: SelectGoogleCalendarDialogViewModel, @unchecked Sendable {

    let accountId: String
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let eventTagUsecase: any EventTagUsecase
    var router: (any SelectGoogleCalendarDialogRouting)?

    init(
        accountId: String,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        eventTagUsecase: any EventTagUsecase
    ) {
        self.accountId = accountId
        self.googleCalendarUsecase = googleCalendarUsecase
        self.eventTagUsecase = eventTagUsecase
    }
}


// MARK: - SelectGoogleCalendarDialogViewModelImple Interactor

extension SelectGoogleCalendarDialogViewModelImple {

    func toggleCalendar(_ id: EventTagId) {
        self.eventTagUsecase.toggleEventTagIsOnCalendar(id)
    }

    func close() {
        self.router?.closeScene()
    }
}


// MARK: - SelectGoogleCalendarDialogViewModelImple Presenter

extension SelectGoogleCalendarDialogViewModelImple {

    var calendars: AnyPublisher<[ExternalCalendarEventTagCellViewModel], Never> {
        let transform: ([GoogleCalendar.Tag], Set<EventTagId>) -> [ExternalCalendarEventTagCellViewModel]
        transform = { [accountId] tags, offIds in
            return tags
                .filter { $0.ownerId == accountId }
                .map { ExternalCalendarEventTagCellViewModel(ExternalCalendarEventTag($0)) }
                .map { $0 |> \.isOn .~ !offIds.contains($0.id) |> \.accountEmail .~ nil }
        }
        return Publishers.CombineLatest(
            self.googleCalendarUsecase.calendarTags,
            self.eventTagUsecase.offEventTagIdsOnCalendar()
        )
        .map(transform)
        .eraseToAnyPublisher()
    }
}
