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
import CommonPresentation


// MARK: - EventTagDetailViewController

final class EventTagDetailViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published fileprivate var suggestColorHexes: [String] = []
    @Published fileprivate var newTagName: String = ""
    @Published fileprivate var originalColor: EventTagColor?
    @Published fileprivate var selectedColor: EventTagColor?
    @Published fileprivate var isDeletable: Bool = false
    @Published fileprivate var isNameChangable: Bool = false
    @Published fileprivate var isSavable: Bool = false
    
    func bind(_ viewModel: any EventTagDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        self.originalColor = viewModel.originalColor
        self.suggestColorHexes = viewModel.suggestColorHexes
        self.newTagName = viewModel.originalName ?? ""
        self.isDeletable = viewModel.isDeletable
        self.isNameChangable = viewModel.isNameChangable
        
        viewModel.isSavable
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isSavable = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedColor
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] color in
                self?.selectedColor = color
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
    var colorSelected: (EventTagColor) -> Void = { _ in }
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
            .eventHandler(\.requestSelectOtherColor, self.requestSelectOtherColor)
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
    
    @EnvironmentObject private var state: EventTagDetailViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @FocusState private var isFocusInput: Bool
    
    fileprivate var nameEntered: (String) -> Void = { _ in }
    fileprivate var colorSelected: (EventTagColor) -> Void = { _ in }
    fileprivate var requestSelectOtherColor: () -> Void = { }
    fileprivate var saveChanges: () -> Void = { }
    fileprivate var deleteTag: () -> Void = { }
    
    private let suggestColorColums = [GridItem(.adaptive(minimum: 40))]
    
    var body: some View {
        VStack(alignment: .leading) {
            
            self.nameInputView
            
            Text("Event color".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .padding(.top, 24)
            
            self.suggestColorView
            
            Spacer()
            
            self.buttonViews
        }
        .padding()
    }
    
    private var nameInputView: some View {
        return HStack(spacing: 16) {
            Circle()
                .frame(width: 15, height: 15)
                .foregroundStyle(self.state.selectedColor?.color(with: self.appearance).asColor ?? .clear)
            
            TextField(
                "Add new tag name".localized(),
                text: self.$state.newTagName,
                axis: .vertical
            )
            .disabled(!self.state.isNameChangable)
            .onReceive(self.state.$newTagName, perform: self.nameEntered)
            .focused($isFocusInput)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(self.appearance.fontSet.size(22, weight: .semibold).asFont)
            .foregroundColor(
                self.appearance.colorSet.normalText.asColor
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
                        self.circleView(.custom(hex: hex))
                    }
                }
                
                Section {
                    
                    self.circleView(self.state.originalColor ?? .default)
                    
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
                .fill(self.appearance.colorSet.eventList.asColor)
        )
    }
    
    private func circleView(
        _ tagColor: EventTagColor
    ) -> some View {
        let color = tagColor.color(with: self.appearance).asColor
        return Button {
            self.colorSelected(tagColor)
        } label: {
            ZStack {
                Circle()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(color)
                
                if tagColor == self.state.selectedColor {
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
        return Button {
            self.requestSelectOtherColor()
        } label: {
            ZStack {
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
                        self.state.selectedColor?.color(with: self.appearance).asColor ?? .clear
                    )
                    
            }
        }
    }
    
    private var buttonViews: some View {
        
        return HStack {
            if self.state.isDeletable {
                Button {
                    self.deleteTag()
                } label: {
                    Text("Delete".localized())
                        .font(self.appearance.fontSet.bottomButton.asFont)
                        .foregroundStyle(self.appearance.colorSet.negativeBtnBackground.asColor)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(self.appearance.colorSet.secondaryBtnBackground.asColor)
                )
            }
            
            Button {
                self.saveChanges()
            } label: {
                Text("Save".localized())
                    .font(self.appearance.fontSet.bottomButton.asFont)
                    .foregroundStyle(self.appearance.colorSet.primaryBtnText.asColor)
            }
            .disabled(!self.state.isSavable)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        self.appearance.colorSet.primaryBtnBackground.asColor
                            .opacity(self.state.isSavable ? 1.0 : 0.7)
                    )
            )
        }
    }
}


// MARK: - preview

struct EventTagDetailViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        let detailView = EventTagDetailView()
        let state = EventTagDetailViewState()
        state.selectedColor = .default
        state.originalColor = .custom(hex: "#ff0000")
        state.newTagName = "some name".localized()
        state.isDeletable = true
        state.isNameChangable = true
        return detailView
            .eventHandler(\.colorSelected) { state.selectedColor = $0 }
            .eventHandler(\.nameEntered) { state.isSavable = !$0.isEmpty }
            .environmentObject(viewAppearance)
            .environmentObject(state)
    }
}

