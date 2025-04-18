//
//  
//  EventTagDetailView.swift
//  SettingScene
//
//  Created by sudo.park on 2023/10/03.
//
//


import SwiftUI
import Combine
import Domain
import Scenes
import CommonPresentation


// MARK: - EventTagDetailViewController

final class EventTagDetailViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published fileprivate var suggestColorHexes: [String] = []
    @Published fileprivate var newTagName: String = ""
    @Published fileprivate var originalColorHex: String?
    @Published fileprivate var selectedColorHex: String?
    @Published fileprivate var isDeletable: Bool = false
    @Published fileprivate var isNameChangable: Bool = false
    @Published fileprivate var isSavable: Bool = false
    @Published fileprivate var isProcessing: Bool = false
    
    func bind(_ viewModel: any EventTagDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        self.suggestColorHexes = viewModel.suggestColorHexes
        self.newTagName = viewModel.originalName ?? ""
        self.isDeletable = viewModel.isDeletable
        self.isNameChangable = viewModel.isNameChangable
        
        viewModel.originalColorHex
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] hex in
                self?.originalColorHex = hex
            })
            .store(in: &self.cancellables)
        
        viewModel.isSavable
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isSavable = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedColorHex
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] color in
                self?.selectedColorHex = color
            })
            .store(in: &self.cancellables)
        
        viewModel.isProcessing
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isProcessing = flag
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - EventTagDetailContainerView

struct EventTagDetailContainerView: View {
    
    @StateObject fileprivate var state: EventTagDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (EventTagDetailViewState) -> Void = { _ in }
    var nameEntered: (String) -> Void = { _ in }
    var colorSelected: (String) -> Void = { _ in }
    var requestSelectOtherColor: () -> Void = { }
    var saveChanges: () -> Void = { }
    var deleteTag: () -> Void = { }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return EventTagDetailView()
            .eventHandler(\.nameEntered, self.nameEntered)
            .eventHandler(\.colorSelected, self.colorSelected)
            .eventHandler(\.saveChanges, self.saveChanges)
            .eventHandler(\.deleteTag, self.deleteTag)
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - EventTagDetailView

struct EventTagDetailView: View {
    
    @Environment(\.self) var environment
    @EnvironmentObject private var state: EventTagDetailViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @FocusState private var isFocusInput: Bool
    @State private var selectedOtherColor: Color = .clear
    
    fileprivate var nameEntered: (String) -> Void = { _ in }
    fileprivate var colorSelected: (String) -> Void = { _ in }
    fileprivate var saveChanges: () -> Void = { }
    fileprivate var deleteTag: () -> Void = { }
    
    private let suggestColorColums = [GridItem(.adaptive(minimum: 40))]
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                
                self.nameInputView
                
                Text("Event color".localized())
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                    .padding(.top, 24)
                
                self.suggestColorView
                
                Spacer()
                
                self.buttonViews
            }
            .padding()
            
            FullScreenLoadingView(isLoading: $state.isProcessing)
        }
        .background(appearance.colorSet.bg0.asColor)
    }
    
    private var nameInputView: some View {
        return HStack(spacing: 16) {
            Circle()
                .frame(width: 15, height: 15)
                .foregroundStyle(
                    self.state.selectedColorHex?.asColor ?? .clear
                )
            
            TextField(
                "",
                text: self.$state.newTagName,
                prompt: Text("eventTag.addNew::placeholder".localized()).foregroundStyle(appearance.colorSet.placeHolder.asColor),
                axis: .vertical
            )
            .disabled(!self.state.isNameChangable)
            .onReceive(self.state.$newTagName, perform: self.nameEntered)
            .focused($isFocusInput)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(self.appearance.fontSet.size(22, weight: .semibold).asFont)
            .foregroundColor(
                self.appearance.colorSet.text0.asColor
                    .opacity(self.state.isNameChangable ? 1.0 : 0.55)
            )
            .onSubmit {
                self.isFocusInput = false
            }
        }
    }
    
    private var suggestColorView: some View {
        VStack {
            LazyVGrid(columns: self.suggestColorColums, spacing: 20) {
                Section {
                    ForEach(self.state.suggestColorHexes, id: \.self) { hex in
                        self.circleView(hex)
                    }
                }
                
                Section {
                    
                    self.circleView(self.state.originalColorHex)
                    
                    self.selectColorView
                    
                } header: {
                    Divider()
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }
    
    private func circleView(
        _ tagColorHex: String?
    ) -> some View {
        let color = tagColorHex?.asColor ?? .clear
        return Button {
            guard let hex = tagColorHex else { return }
            self.colorSelected(hex)
        } label: {
            ZStack {
                Circle()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(color)
                
                if tagColorHex == self.state.selectedColorHex {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private var selectColorView: some View {
        let gradientColors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple
        ]
        return ZStack {
            Circle()
                .stroke(
                    .angularGradient(colors: gradientColors, center: .center, startAngle: .zero, endAngle: .radians(Double.pi * 2)),
                    lineWidth: 2
                )
                .foregroundStyle(.clear)
                .frame(width: 28, height: 28)
                
            Circle()
                .frame(width: 20, height: 20)
                .foregroundStyle(
                    self.state.selectedColorHex?.asColor ?? .clear
                )
                
        }
        .overlay {
            ColorPicker("", selection: $selectedOtherColor)
                .labelsHidden()
                .opacity(0.15)
        }
        .onChange(of: self.selectedOtherColor) { newColor in
            guard let hex = newColor.hex(environment) else { return }
            self.colorSelected(hex)
        }
    }
    
    private var buttonViews: some View {
        
        return HStack {
            if self.state.isDeletable {
                ConfirmButton(
                    title: "common.remove".localized(),
                    textColor: self.appearance.colorSet.accentWarn.asColor,
                    backgroundColor: self.appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap, self.deleteTag)
            }
            
            ConfirmButton(
                title: "common.save".localized(),
                isEnable: self.$state.isSavable
            )
            .eventHandler(\.onTap, self.saveChanges)
        }
    }
}


private extension String {
    var asColor: Color {
        return UIColor.from(hex: self)?.asColor ?? .clear
    }
}

// MARK: - preview

struct EventTagDetailViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let detailView = EventTagDetailView()
        let state = EventTagDetailViewState()
        state.selectedColorHex = "#ff0000"
        state.originalColorHex = "#ff0000"
        state.newTagName = "some name".localized()
        state.isDeletable = true
        state.isNameChangable = true
        return detailView
            .eventHandler(\.colorSelected) { state.selectedColorHex = $0 }
            .eventHandler(\.nameEntered) { state.isSavable = !$0.isEmpty }
            .environmentObject(viewAppearance)
            .environmentObject(state)
    }
}
