//
//  
//  SelectEventRepeatOptionScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Prelude
import Optics
import Domain
import Scenes


// MARK: - SelectEventRepeatOptionScene Interactable & Listenable

struct EventRepeatingTimeSelectResult: Equatable {
    let text: String
    let repeating: EventRepeating
        
    init(text: String, repeating: EventRepeating) {
        self.text = text
        self.repeating = repeating
    }
    
    init?(_ repeating: EventRepeating, timeZone: TimeZone) {
        guard let model = SelectRepeatingOptionModel(
            repeating.repeatOption, 
            Date(timeIntervalSince1970: repeating.repeatingStartTime),
            timeZone
        ) else {
            return nil
        }
        self.text = model.text
        self.repeating = repeating
    }
    
    func updateRepeatStartTime(
        _ startTime: TimeInterval, _ timeZone: TimeZone
    ) -> EventRepeatingTimeSelectResult? {
        let newRepeating = EventRepeating(
            repeatingStartTime: startTime,
            repeatOption: self.repeating.repeatOption
        )
        |> \.repeatingEndOption .~ self.repeating.repeatingEndOption
        let model = SelectRepeatingOptionModel(self.repeating.repeatOption, Date(timeIntervalSince1970: startTime), timeZone)
        return model.map { .init(text: $0.text, repeating: newRepeating)}
    }
}

protocol SelectEventRepeatOptionSceneInteractor: AnyObject { }
//
protocol SelectEventRepeatOptionSceneListener: Sendable, AnyObject {
    
    func selectEventRepeatOption(didSelect repeating: EventRepeatingTimeSelectResult)
    func selectEventRepeatOptionNotRepeat()
}

// MARK: - SelectEventRepeatOptionScene

protocol SelectEventRepeatOptionScene: Scene where Interactor == any SelectEventRepeatOptionSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectEventRepeatOptionSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectEventRepeatOptionScene(
        selectTime: Date,
        previousSelected repeating: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) -> any SelectEventRepeatOptionScene
}
