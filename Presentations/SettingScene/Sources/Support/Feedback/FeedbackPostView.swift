//
//  
//  FeedbackPostView.swift
//  SettingScene
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - FeedbackPostViewState

final class FeedbackPostViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var isPosting: Bool = false
    @Published var isPostable: Bool = false
    @Published var inputContact: String = ""
    @Published var inputMessage: String = ""
    
    func bind(_ viewModel: any FeedbackPostViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.isPostable
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isPostable = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.isPosting
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isPosting = flag
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - FeedbackPostViewEventHandler

final class FeedbackPostViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var enterMessage: (String) -> Void = { _ in }
    var enterContact: (String) -> Void = { _ in }
    var post: () -> Void = { }

    func bind(_ viewModel: any FeedbackPostViewModel) {
        
        self.close = viewModel.close
        self.enterMessage = viewModel.enter(message:)
        self.enterContact = viewModel.enter(contact:)
        self.post = viewModel.post
    }
}


// MARK: - FeedbackPostContainerView

struct FeedbackPostContainerView: View {
    
    @StateObject private var state: FeedbackPostViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: FeedbackPostViewEventHandler
    
    var stateBinding: (FeedbackPostViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: FeedbackPostViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return FeedbackPostView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - FeedbackPostView

struct FeedbackPostView: View {
    
    @EnvironmentObject private var state: FeedbackPostViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: FeedbackPostViewEventHandler
    
    private enum InputFields {
        case message
        case contact
    }
    @FocusState private var inputField: InputFields?
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                
                Text("feedback::guide:message".localized())
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                
                VStack(alignment: .leading, spacing: 8) {
                    messageInput
                    contactInput
                }
                
                HStack {
                    clearButton
                    sendButton
                }
                    
                Spacer()
            }
            .onTapGesture {
                self.inputField = nil
            }
            .padding()
            .padding(.top, 20)
            .navigationTitle("Feedback".localized())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton()
                        .eventHandler(\.onTap, eventHandlers.close)
                }
            }
        }
    }
    
    private var messageInput: some View {
        ZStack(alignment: .topLeading) {
            
            if state.inputMessage.isEmpty {
                Text("Enter a message".localized())
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.placeHolder.asColor)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            
            TextEditor(text: $state.inputMessage)
                .focused($inputField, equals: .message)
                .autocorrectionDisabled()
                .multilineTextAlignment(.leading)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .scrollContentBackground(.hidden)
                .frame(height: 200)
                .onReceive(state.$inputMessage, perform: eventHandlers.enterMessage)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    appearance.colorSet.bg2.asColor
                )
        )
    }
    
    
    private var contactInput: some View {
        TextField(
            "", text: $state.inputContact,
            prompt: Text("Contact Email Address")
                        .font(appearance.fontSet.normal.asFont)
                        .foregroundStyle(appearance.colorSet.placeHolder.asColor)
            )
            .focused($inputField, equals: .contact)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(appearance.fontSet.normal.asFont)
            .foregroundStyle(appearance.colorSet.text0.asColor)
            .padding(.vertical, 12).padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        appearance.colorSet.bg2.asColor
                    )
            )
            .onReceive(state.$inputContact, perform: eventHandlers.enterContact)
    }
    
    private var clearButton: some View {
        Button {
            self.state.inputContact = ""
            self.state.inputMessage = ""
            self.inputField = nil
        } label: {
            Text("Clear".localized())
                .font(appearance.fontSet.size(16).asFont)
                .foregroundStyle(appearance.colorSet.secondaryBtnText.asColor)
                .padding()
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            appearance.colorSet.secondaryBtnBackground.asColor
                        )
                )
        }
        .disabled(state.isPosting)
    }
    
    private var isPostDisabled: Bool {
        return !self.state.isPostable || self.state.isPosting
    }
    
    private var sendButton: some View {
        Button {
            appearance.impactIfNeed(.light)
            self.inputField = nil
            eventHandlers.post()
        } label: {
            HStack(alignment: .center) {
                
                if state.isPosting {
                    LoadingCircleView(appearance.colorSet.primaryBtnText.asColor)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "paperplane")
                    Text("Send".localized())
                }
            }
            .padding()
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .font(appearance.fontSet.size(16).asFont)
            .foregroundStyle(appearance.colorSet.primaryBtnText.asColor)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        appearance.colorSet.primaryBtnBackground.asColor
                            .opacity(state.isPostable ? 1 : 0.5)
                    )
            )
        }
        .disabled(isPostDisabled)
    }
}


// MARK: - preview

struct FeedbackPostViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let state = FeedbackPostViewState()
        let eventHandlers = FeedbackPostViewEventHandler()
        eventHandlers.enterMessage = { _ in
            state.isPostable = !state.inputContact.isEmpty && !state.inputMessage.isEmpty
        }
        eventHandlers.enterContact = { _ in
            state.isPostable = !state.inputContact.isEmpty && !state.inputMessage.isEmpty
        }
        eventHandlers.post = {
            state.isPosting.toggle()
        }
        
        let view = FeedbackPostView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

