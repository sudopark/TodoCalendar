//
//  
//  SelectEventRepeatOptionView.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//


import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation


// MARK: - SelectEventRepeatOptionViewController

enum SelectEndOptionType: Int {
    case never
    case on
    case after
    
    var text: String {
        switch self {
        case .never: return "eventDetail.repeating.endtime::option::never".localized()
        case .on: return "eventDetail.repeating.endtime::option::on".localized()
        case .after: return "eventDetail.repeating.endtime::option::after".localized()
        }
    }
}

@Observable final class SelectEventRepeatOptionViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var optionList: [[SelectRepeatingOptionModel]] = []
    var selectedOptionId: String?
    var repeatStartTimeText: String?
    var selectedEndCountText: String = "10"
    var selectedEndDate: Date = Date()
    var selectEndOptionType: SelectEndOptionType = .never
    var isNoRepeatOption = false
    let availableEndOptionTypee: [SelectEndOptionType] = [.after, .on, .never]
    
    func bind(_ viewModel: any SelectEventRepeatOptionViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.repeatStartTimeText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.repeatStartTimeText = text
            })
            .store(in: &self.cancellables)
        
        viewModel.options
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] list in
                self?.optionList = list
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedOptionId
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] id in
                self?.selectedOptionId = id
            })
            .store(in: &self.cancellables)
        
        viewModel.defaultRepeatEndDate
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] date in
                self?.selectedEndDate = date
            })
            .store(in: &self.cancellables)
        
        viewModel.repeatEndOption
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                let optionType = model.asType
                guard self?.selectEndOptionType != optionType else { return }
                switch model {
                case .never:
                    self?.selectEndOptionType = .never
                case .on(let date):
                    self?.selectedEndDate = date.date
                    self?.selectEndOptionType = .on
                case .after(let count):
                    self?.selectedEndCountText = "\(count)"
                    self?.selectEndOptionType = .after
                }
            })
            .store(in: &self.cancellables)
        
        viewModel.isNoRepeatOption
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isNoRepeatOption = flag
            })
            .store(in: &self.cancellables)
    }
}

final class SelectEventRepeatOptionViewEventHandlers: Observable {
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var itemSelect: (String) -> Void = { _ in }
    var removeEndOption: () -> Void = { }
    var endTimeSelect: (Date) -> Void = { _ in }
    var endCountSelect: (Int) -> Void = { _ in }
}


// MARK: - SelectEventRepeatOptionContainerView

struct SelectEventRepeatOptionContainerView: View {
    
    @State private var state: SelectEventRepeatOptionViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SelectEventRepeatOptionViewEventHandlers
    
    var stateBinding: (SelectEventRepeatOptionViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SelectEventRepeatOptionViewEventHandlers
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SelectEventRepeatOptionView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}

// MARK: - SelectEventRepeatOptionView

struct SelectEventRepeatOptionView: View {
    
    @Environment(SelectEventRepeatOptionViewState.self) private var state
    @Environment(SelectEventRepeatOptionViewEventHandlers.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    @FocusState private var isEditing: Bool
    
    var body: some View {
        NavigationStack {
            
            ZStack {
                
                List {
                    
                    if let start = self.state.repeatStartTimeText {
                        self.repeatStartTimeView(start)
                            .listRowSeparator(.hidden)
                            .listRowBackground(appearance.colorSet.bg0.asColor)
                    }
                    
                    ForEach(self.state.optionList, id: \.compareKey) {
                        self.sectionView($0)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                    .listRowBackground(appearance.colorSet.bg0.asColor)
                    
                    Spacer()
                        .frame(height: 80)
                        .listRowSeparator(.hidden)
                }
                .listSectionSpacing(0)
                .listStyle(.plain)
                .background(appearance.colorSet.bg0.asColor)
                
                VStack(spacing: 0) {
                    Spacer()
                    if !self.state.isNoRepeatOption {
                        self.repeatEndOptionView
                    }
                }
            }
            .navigationTitle(R.String.EventDetail.Repeating.title)
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
            .toolbar {
                CloseButton()
                    .eventHandler(\.onTap, self.eventHandlers.close)
            }
        }
        .id(appearance.navigationBarId)
    }
    
    private func repeatStartTimeView(_ text: String) -> some View {
        Section {
            HStack {
                Text("eventDetail.repeating.starttime:title".localized())
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                
                Spacer()
                
                Text(text)
                    .font(self.appearance.fontSet.size(16).asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                
            }
            .padding(.top, 20)
        }
    }
    
    private func sectionView(_ section: [SelectRepeatingOptionModel]) -> some View {
        Section {
            ForEach(section, id: \.compareKey) { option in
                HStack {
                    Text(option.text)
                        .font(self.appearance.fontSet.normal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text0.asColor)
                        .lineLimit(1)
                    
                    Spacer()
                    if self.state.selectedOptionId == option.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundStyle(appearance.colorSet.text0.asColor)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(self.appearance.colorSet.bg1.asColor)
                }
                .onTapGesture {
                    self.appearance.impactIfNeed()
                    self.eventHandlers.itemSelect(option.id)
                    self.isEditing = false
                }
            }
        } header: {
            VStack {
                Spacer()
                HStack {
                    Text("")
                    Spacer()
                }
                Spacer()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .background(appearance.colorSet.bg0.asColor)
        }
    }
    
    private var repeatEndOptionView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(appearance.colorSet.line.asColor)
                .frame(height: 0.5)
            
            HStack() {
                
                Text("eventDetail.repeating.endtime::title".localized())
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                
                Spacer()
                
                Menu {
                    ForEach(self.state.availableEndOptionTypee, id: \.self) { option in
                        Button {
                            self.state.selectEndOptionType = option
                            switch option {
                            case .never:
                                self.eventHandlers.removeEndOption()
                                self.isEditing = false
                            case .on:
                                self.eventHandlers.endTimeSelect(self.state.selectedEndDate)
                                self.isEditing = false
                            case .after:
                                let count = Int(self.state.selectedEndCountText) ?? 0
                                self.eventHandlers.endCountSelect(count)
                                self.isEditing = true
                            }
                        } label: {
                            HStack {
                                if state.selectEndOptionType == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12))
                                        .foregroundStyle(appearance.colorSet.text0.asColor)
                                }
                                Text(option.text)
                            }
                        }
                    }
                    
                } label: {
                    Button { } label: {
                        Text(self.state.selectEndOptionType.text)
                            .foregroundStyle(appearance.colorSet.text0.asColor)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .invertColorIfNeed(appearance)
                }
                
                switch self.state.selectEndOptionType {
                case .never:
                    EmptyView()
                case .on:
                    repeatEndTimeView
                case .after:
                    repeatEndCountView
                }
            }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        }
        .padding(.top, 0)
        .background(appearance.colorSet.bg2.asColor)
        .onTapGesture {
            isEditing = false
        }
    }
    
    private var repeatEndTimeView: some View {
        @Bindable var state = self.state
        return DatePicker(
            "",
            selection: $state.selectedEndDate,
            displayedComponents: [.date]
        )
        .invertColorIfNeed(appearance)
        .labelsHidden()
        .onChange(of: self.state.selectedEndDate) { _, date in
            self.eventHandlers.endTimeSelect(date)
        }
    }
    
    private var repeatEndCountView: some View {
        @Bindable var state = self.state
        return HStack {
            TextField("", text: $state.selectedEndCountText)
                .keyboardType(.numberPad)
                .focused($isEditing)
                .onChange(of: state.selectedEndCountText) { _, new in
                    let newCount = Int(new) ?? 0
                    self.eventHandlers.endCountSelect(newCount)
                }
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 50)
                .textFieldStyle(.roundedBorder)
                .invertColorIfNeed(appearance)
            Text("eventDetail.repeating.endtime::option::after_occurrences".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
        }
    }
}

private extension SelectRepeatingOptionModel {
    
    var compareKey: String {
        return "\(id)_\(text)_\(option?.compareHash ?? 0)"
    }
}

private extension Array where Element == SelectRepeatingOptionModel {
    
    var compareKey: String {
        return self.map { $0.compareKey }.joined(separator: "+")
    }
}

private extension RepeatEndOptionModel {
    
    var asType: SelectEndOptionType {
        switch self {
        case .never: return .never
        case .on: return .on
        case .after: return .after
        }
    }
}

// MARK: - preview

struct SelectEventRepeatOptionViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let handler = SelectEventRepeatOptionViewEventHandlers()
        let view = SelectEventRepeatOptionView()
        let state = SelectEventRepeatOptionViewState()
        state.repeatStartTimeText = Date().text("eventDetail.repeating.starttime:form".localized())
        state.optionList = [
            [.init("some", nil)],
            [.init("option1", nil), .init("option2", nil), .init("option3", nil)],
            [
                .init("option4", nil), .init("option5", nil), .init("option6", nil),
                .init("option7", nil), .init("option8", nil), .init("option9", nil)
            ]
        ]
        return view
            .environment(state)
            .environment(handler)
            .environment(viewAppearance)
    }
}
