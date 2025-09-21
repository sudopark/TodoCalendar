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

@Observable final class FeedbackPostViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var isPosting: Bool = false
    var isPostable: Bool = false
    var inputContact: String = ""
    var inputMessage: String = ""
    
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

final class FeedbackPostViewEventHandler: Observable {
    
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
    
    @State private var state: FeedbackPostViewState = .init()
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
            .environment(state)
            .environment(eventHandlers)
            .environmentObject(viewAppearance)
    }
}

// MARK: - FeedbackPostView

struct FeedbackPostView: View {
    
    @Environment(FeedbackPostViewState.self) private var state
    @Environment(FeedbackPostViewEventHandler.self) private var eventHandlers
    @EnvironmentObject private var appearance: ViewAppearance
    
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
            .background(appearance.colorSet.bg0.asColor)
            .navigationTitle("setting.feedback::name".localized())
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
                Text("feedback::enterMessage::placeholder".localized())
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.placeHolder.asColor)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            
            @Bindable var state = self.state
            TextEditor(text: $state.inputMessage)
                .focused($inputField, equals: .message)
                .autocorrectionDisabled()
                .multilineTextAlignment(.leading)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .scrollContentBackground(.hidden)
                .frame(height: 200)
                .onChange(of: state.inputMessage) { _ , new in
                    eventHandlers.enterMessage(new)
                }
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
        @Bindable var state = state
        return TextField(
            "", text: $state.inputContact,
            prompt: Text("feedback::contact::placeholder".localized())
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
            .onChange(of: state.inputContact) { _, new in
                eventHandlers.enterContact(new)
            }
    }
    
    private var clearButton: some View {
        Button {
            self.state.inputContact = ""
            self.state.inputMessage = ""
            self.inputField = nil
        } label: {
            Text("common.clear".localized())
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
                    Text("common.send".localized())
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
            calendar: .init(colorSetKey: .defaultDark, fontSetKey: .systemDefault),
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
            .environment(state)
            .environment(eventHandlers)
            .environmentObject(viewAppearance)
        return view
    }
}

