//
//  
//  HolidayEventDetailViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


struct CountryModel: Equatable {
    let thumbnailUrl: String
    let name: String
}

// MARK: - HolidayEventDetailViewModel

protocol HolidayEventDetailViewModel: AnyObject, Sendable, HolidayEventDetailSceneInteractor {

    // interactor
    func refresh()
    func close()
    
    // presenter
    var holidayName: AnyPublisher<String, Never> { get }
    var dateText: AnyPublisher<String, Never> { get }
    var ddayText: AnyPublisher<String, Never> { get }
    var countryModel: AnyPublisher<CountryModel, Never> { get }
}


// MARK: - HolidayEventDetailViewModelImple

final class HolidayEventDetailViewModelImple: HolidayEventDetailViewModel, @unchecked Sendable {
    
    private let uuid: String
    private let holidayUsecase: any HolidayUsecase
    private let daysIntervalCountUsecase: any DaysIntervalCountUsecase
    var router: (any HolidayEventDetailRouting)?
    
    init(
        uuid: String,
        holidayUsecase: any HolidayUsecase,
        daysIntervalCountUsecase: any DaysIntervalCountUsecase
    ) {
        self.uuid = uuid
        self.holidayUsecase = holidayUsecase
        self.daysIntervalCountUsecase = daysIntervalCountUsecase
    }
    
    
    private struct Subject {
        let country = CurrentValueSubject<HolidaySupportCountry?, Never>(nil)
        let holiday = CurrentValueSubject<Holiday?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - HolidayEventDetailViewModelImple Interactor

extension HolidayEventDetailViewModelImple {
    
    func refresh() {
        
        self.holidayUsecase.holiday(self.uuid)
            .sink(receiveValue: { [weak self] holiday in
                self?.subject.holiday.send(holiday)
            })
            .store(in: &self.cancellables)
        
        self.holidayUsecase.currentSelectedCountry
            .sink(receiveValue: { [weak self] country in
                self?.subject.country.send(country)
            })
            .store(in: &self.cancellables)
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - HolidayEventDetailViewModelImple Presenter

extension HolidayEventDetailViewModelImple {
    
    var holidayName: AnyPublisher<String, Never> {
        return self.subject.holiday.compactMap { $0 }
            .map { $0.name }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var dateText: AnyPublisher<String, Never> {
        guard let utc = TimeZone(secondsFromGMT: 0) else { return Empty().eraseToAnyPublisher() }
        
        let transform: (Date) -> String = { date in
            let formatter = DateFormatter()
                |> \.timeZone .~ utc
                |> \.dateFormat .~ "date_form::yyyy_MM_dd_E_".localized()
            return formatter.string(from: date)
        }
        return self.subject.holiday.compactMap { $0 }
            .compactMap { $0.date(at: utc) }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var ddayText: AnyPublisher<String, Never> {
        let transform: (Holiday) -> AnyPublisher<Int, Never> = { [weak self] holiday in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.daysIntervalCountUsecase.countDays(to: holiday)
        }
        return self.subject.holiday.compactMap { $0 }
            .map(transform)
            .switchToLatest()
            .removeDuplicates()
            .map { DDayText($0).text }
            .eraseToAnyPublisher()
    }
    
    var countryModel: AnyPublisher<CountryModel, Never> {
        let transform: (HolidaySupportCountry) -> CountryModel = { country in
            return .init(
                thumbnailUrl: "https://flagcdn.com/w160/\(country.regionCode).jpg",
                name: country.name
            )
        }
        return self.subject.country.compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
