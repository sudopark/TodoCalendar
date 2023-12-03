//
//  
//  HolidayListViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 11/26/23.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


struct HolidayItemModel {
    let name: String
    let engName: String
    let dateText: String
    
    init?(_ holiday: Holiday) {
        self.name = holiday.localName
        self.engName = holiday.name
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: holiday.dateString) else { return nil }
        
        let presentFormatter = DateFormatter()
        presentFormatter.dateFormat = "yyyy MMM dd"
        self.dateText = presentFormatter.string(from: date)
    }
}

// MARK: - HolidayListViewModel

protocol HolidayListViewModel: AnyObject, Sendable, HolidayListSceneInteractor {
    
    // interactor
    func prepare()
    func selectCountry()
    func close()
    
    // presenter
    var currentCountryName: AnyPublisher<String, Never> { get }
    var currentYearHolidays: AnyPublisher<[HolidayItemModel], Never> { get }
}


// MARK: - HolidayListViewModelImple

final class HolidayListViewModelImple: HolidayListViewModel, @unchecked Sendable {
    
    private let holidayUsecase: any HolidayUsecase
    private let calendarSettingUscase: any CalendarSettingUsecase
    
    var router: (any HolidayListRouting)?
    
    init(
        holidayUsecase: any HolidayUsecase,
        calendarSettingUscase: any CalendarSettingUsecase
    ) {
        self.holidayUsecase = holidayUsecase
        self.calendarSettingUscase = calendarSettingUscase
    }
    
    
    private struct Subject {
        let currentYear = CurrentValueSubject<Int?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - HolidayListViewModelImple Interactor

extension HolidayListViewModelImple {
    
    func prepare() {
        self.calendarSettingUscase.currentTimeZone
            .first()
            .sink(receiveValue: { [weak self] timeZone in
                self?.setupCurrentYear(timeZone)
            })
            .store(in: &self.cancellables)
    }
    
    private func setupCurrentYear(_ timeZone: TimeZone) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let year = calendar.component(.year, from: Date())
        self.subject.currentYear.send(year)
        
        Task { [weak self] in
            try await self?.holidayUsecase.loadHolidays(year)
        }
        .store(in: &self.cancellables)
    }
    
    func selectCountry() {
        self.router?.routeToSelectCountry()
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - HolidayListViewModelImple Presenter

extension HolidayListViewModelImple {
    
    var currentCountryName: AnyPublisher<String, Never> {
        return self.holidayUsecase.currentSelectedCountry
            .map { $0.name }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var currentYearHolidays: AnyPublisher<[HolidayItemModel], Never> {
        let selectHolidayFromYear: (Int) -> AnyPublisher<[Holiday], Never> = { [weak self] year in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.holidayUsecase.holidays()
                .compactMap { $0[year] }
                .eraseToAnyPublisher()
        }
        let asItemModel: ([Holiday]) -> [HolidayItemModel] = { holidays in
            return holidays.compactMap { HolidayItemModel($0) }
        }
        return self.subject.currentYear
            .compactMap{ $0 }
            .flatMap(selectHolidayFromYear)
            .map(asItemModel)
            .eraseToAnyPublisher()
    }
}
