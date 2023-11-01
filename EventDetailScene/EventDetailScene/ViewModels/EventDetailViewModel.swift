//
//  EventDetailViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/1/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain

protocol EventDetailViewModel: Sendable, AnyObject {
    
    func prepare()
    func chooseMoreAction()
    func close()
    func enter(name: String)
    func toggleIsTodo()
    func selectStartTime(_ date: Date)
    func selectEndtime(_ date: Date)
    func removeTime()
    func removeEventEndTime()
    func toggleIsAllDay()
    func selectRepeatOption()
    func selectEventTag()
    func selectPlace()
    func enter(url: String)
    func enter(memo: String)
    func save()
    
    // presenter
    var initialName: String? { get }
    var isTodo: AnyPublisher<Bool, Never> { get }
    var isTodoOrScheduleTogglable: Bool { get }
    var selectedTime: AnyPublisher<SelectedTime?, Never> { get }
    var repeatOption: AnyPublisher<String?, Never> { get }
    var selectedTag: AnyPublisher<SelectedTag, Never> { get }
    var selectedPlace: AnyPublisher<Place?, Never> { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
}

