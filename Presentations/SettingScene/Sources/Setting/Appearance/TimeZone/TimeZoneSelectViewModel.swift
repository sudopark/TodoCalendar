//
//  
//  TimeZoneSelectViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 12/25/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Domain
import Scenes


struct TimeZoneModel: Equatable {
    let identifier: String
    let title: String
    var description: String?
    
    init?(timeZone: TimeZone) {
        self.identifier = timeZone.identifier
        guard let title = timeZone.localizedName(for: .generic, locale: .current)
        else { return nil }
        self.title = title
        
        let standardName = timeZone.localizedName(for: .standard, locale: .current)
        self.description = standardName.map {
            name in timeZone.abbreviation().map { "\(name) (\($0))" } ?? name
        }
    }
}

struct TimeZoneListModel: Equatable {
    
    let systemTimeZone: TimeZoneModel
    let timeZones: [TimeZoneModel]
    
    init(_ systemTimeZone: TimeZoneModel, _ timeZones: [TimeZoneModel]) {
        self.systemTimeZone = systemTimeZone
        self.timeZones = timeZones
    }
    
    init?(_ timeZones: [TimeZone]) {
        let system = TimeZone.current
        guard let systemTimeZone = TimeZoneModel(timeZone: system)
        else { return nil }
        
        self.systemTimeZone = systemTimeZone
        self.timeZones = timeZones.filter { $0 != system }.compactMap { TimeZoneModel(timeZone: $0) }
    }
    
    func filter(_ keyword: String) -> TimeZoneListModel {
        let matching: (TimeZoneModel) -> Bool = { model in
            return model.title.contains(keyword)
            || model.identifier.contains(keyword)
            || model.description?.contains(keyword) == true
        }
        return TimeZoneListModel(
            self.systemTimeZone,
            self.timeZones.filter(matching)
        )
    }
}

// MARK: - TimeZoneSelectViewModel

protocol TimeZoneSelectViewModel: AnyObject, Sendable, TimeZoneSelectSceneInteractor {

    // interactor
    func loadList()
    func search(keyword: String)
    func selectTimeZone(_ identifier: String)
    func close()
    
    // presenter
    
    /// 구독하는쪽에서 subscribeon 써야함
    var timeZoneModels: AnyPublisher<TimeZoneListModel, Never> { get }
    var selectedTimeZoneIdentifier: AnyPublisher<String, Never> { get }
}


// MARK: - TimeZoneSelectViewModelImple

final class TimeZoneSelectViewModelImple: TimeZoneSelectViewModel, @unchecked Sendable {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    var router: (any TimeZoneSelectRouting)?
    
    init(
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
    }
    
    
    private struct Subject {
        let timeZones = CurrentValueSubject<[TimeZone]?, Never>(nil)
        let searchKeyword = CurrentValueSubject<String?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - TimeZoneSelectViewModelImple Interactor

extension TimeZoneSelectViewModelImple {
    
    func loadList() {
        let timeZones = self.calendarSettingUsecase.loadAllTimeZones()
        self.subject.timeZones.send(timeZones)
    }
    
    func search(keyword: String) {
        self.subject.searchKeyword.send(keyword)
    }
    
    func selectTimeZone(_ identifier: String) {
        guard let timeZone = self.subject.timeZones.value?.first(where: { $0.identifier == identifier })
        else { return }
        self.calendarSettingUsecase.selectTimeZone(timeZone)
        
        self.close()
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - TimeZoneSelectViewModelImple Presenter

extension TimeZoneSelectViewModelImple {
    
    var timeZoneModels: AnyPublisher<TimeZoneListModel, Never> {
        
        let transform: (TimeZoneListModel, String?) -> TimeZoneListModel = { list, keyword in
            guard let keyword = keyword, !keyword.isEmpty else { return list }
            return list.filter(keyword)
        }
        
        let list = self.subject.timeZones.compactMap { $0 }
            .compactMap { TimeZoneListModel($0) }
        return Publishers.CombineLatest(
            list, self.subject.searchKeyword
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var selectedTimeZoneIdentifier: AnyPublisher<String, Never> {
        return self.calendarSettingUsecase.currentTimeZone
            .map { $0.identifier }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
