//
//  
//  FeedbackPostViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Prelude
import Optics
import Combine
import Domain
import Scenes


// MARK: - FeedbackPostViewModel

protocol FeedbackPostViewModel: AnyObject, Sendable, FeedbackPostSceneInteractor {

    // interactor
    func enter(contact: String)
    func enter(message: String)
    func post()
    func close()
    
    // presenter
    var isPostable: AnyPublisher<Bool, Never> { get }
    var isPosting: AnyPublisher<Bool, Never> { get }
}


// MARK: - FeedbackPostViewModelImple

final class FeedbackPostViewModelImple: FeedbackPostViewModel, @unchecked Sendable {
    
    private let feedbackUsecase: any FeedbackUsecase
    var router: (any FeedbackPostRouting)?
    
    init(feedbackUsecase: any FeedbackUsecase) {
        self.feedbackUsecase = feedbackUsecase
    }
    
    
    private struct Subject {
        let contact = CurrentValueSubject<String?, Never>(nil)
        let message = CurrentValueSubject<String?, Never>(nil)
        let isPosting = CurrentValueSubject<Bool, Never>(false)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - FeedbackPostViewModelImple Interactor

extension FeedbackPostViewModelImple {
    
    func enter(contact: String) {
        self.subject.contact.send(contact)
    }
    
    func enter(message: String) {
        self.subject.message.send(message)
    }
    
    func post() {
        guard let contact = self.subject.contact.value,
              let message = self.subject.message.value
        else { return }
        
        Task { [weak self] in
            self?.subject.isPosting.send(true)
            do {
                let feedback = FeedbackPostMessage(contactEmail: contact, message: message)
                try await self?.feedbackUsecase.postFeedback(feedback)
                self?.subject.isPosting.send(false)
                self?.showPostedAndClose()
            } catch {
                self?.subject.isPosting.send(false)
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func showPostedAndClose() {
        let confirmed: () -> Void = { [weak self] in
            self?.router?.closeScene()
        }
        let info = ConfirmDialogInfo()
            |> \.title .~ "setting.feedback::name".localized()
            |> \.message .~ pure("feedback::posted:message".localized())
            |> \.confirmed .~ pure(confirmed)
            |> \.withCancel .~ false
        
        self.router?.showConfirm(dialog: info)
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - FeedbackPostViewModelImple Presenter

extension FeedbackPostViewModelImple {
    
    var isPostable: AnyPublisher<Bool, Never> {
        let transform: (String?, String?) -> Bool = { contact, message in
            return contact?.isEmpty == false
                && message?.isEmpty == false
        }
        return Publishers.CombineLatest(
            self.subject.contact,
            self.subject.message
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var isPosting: AnyPublisher<Bool, Never> {
        return self.subject.isPosting
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
