//
//  
//  CountrySelectViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 12/1/23.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - CountrySelectViewModel

protocol CountrySelectViewModel: AnyObject, Sendable, CountrySelectSceneInteractor {

    // interactor
    func prepare()
    func selectCountry(_ code: String)
    func confirm()
    
    // presenter
    var supportCountries: AnyPublisher<[HolidaySupportCountry], Never> { get }
    var selectedCountryCode: AnyPublisher<String, Never> { get }
    var isConfirmable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
}


// MARK: - CountrySelectViewModelImple

final class CountrySelectViewModelImple: CountrySelectViewModel, @unchecked Sendable {
    
    private let holidayUsecase: any HolidayUsecase
    var router: (any CountrySelectRouting)?
    
    init(
        holidayUsecase: any HolidayUsecase
    ) {
        self.holidayUsecase = holidayUsecase
    }
    
    
    private struct Subject {
        let selectedCode = CurrentValueSubject<String?, Never>(nil)
        let countries = CurrentValueSubject<[HolidaySupportCountry]?, Never>(nil)
        let isSaving = CurrentValueSubject<Bool, Never>(false)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - CountrySelectViewModelImple Interactor

extension CountrySelectViewModelImple {
    
    func prepare() {
        
        self.holidayUsecase.currentSelectedCountry
            .first()
            .sink(receiveValue: { [weak self] country in
                self?.subject.selectedCode.send(country.code)
            })
            .store(in: &self.cancellables)
        
        self.holidayUsecase.availableCountries
            .sink(receiveValue: { [weak self] countries in
                self?.subject.countries.send(countries)
            })
            .store(in: &self.cancellables)
        
        Task { [weak self] in
            try? await self?.holidayUsecase.refreshAvailableCountries()
        }
        .store(in: &self.cancellables)
    }
    
    func selectCountry(_ code: String) {
        self.subject.selectedCode.send(code)
    }
    
    func confirm() {
        guard let code = self.subject.selectedCode.value,
              let country = self.subject.countries.value?.first(where: { $0.code == code })
        else { return }
        
        let confirm: () -> Void = { [weak self] in
            self?.saveSelectCountry(country)
        }
        
        let message = "change_country_confirm".localized(with: country.name)
        let info = ConfirmDialogInfo()
            |> \.title .~ "Change Country".localized()
            |> \.message .~ pure(message)
            |> \.confirmed .~ pure(confirm)
            |> \.withCancel .~ true
        self.router?.showConfirm(dialog: info)
    }
    
    private func saveSelectCountry(_ country: HolidaySupportCountry) {
        Task { [weak self] in
            self?.subject.isSaving.send(true)
            
            do {
                try await self?.holidayUsecase.selectCountry(country)
                self?.subject.isSaving.send(true)
                self?.router?.showToast("holiday_country_selected".localized())
                self?.router?.closeScene()
            } catch {
                self?.subject.isSaving.send(false)
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
}


// MARK: - CountrySelectViewModelImple Presenter

extension CountrySelectViewModelImple {
    
    var selectedCountryCode: AnyPublisher<String, Never> {
        return self.subject.selectedCode
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var supportCountries: AnyPublisher<[HolidaySupportCountry], Never> {
        return self.subject.countries
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    var isConfirmable: AnyPublisher<Bool, Never> {
        return self.subject.selectedCode
            .map { $0 != nil }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isSaving: AnyPublisher<Bool, Never> {
        return self.subject.isSaving
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
