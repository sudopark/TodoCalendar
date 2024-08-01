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
import CommonPresentation


// MARK: - SelectEventRepeatOptionViewController

final class SelectEventRepeatOptionViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var optionList: [[SelectRepeatingOptionModel]] = []
    @Published var selectedOptionId: String?
    @Published var selectedEndDate: Date = Date()
    @Published var hasEndTime: Bool = false
    
    func bind(_ viewModel: any SelectEventRepeatOptionViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
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
        
        viewModel.repeatEndTime
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] date in
                self?.selectedEndDate = date
            })
            .store(in: &self.cancellables)
        
        viewModel.hasRepeatEnd
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isOn in
                self?.hasEndTime = isOn
            })
            .store(in: &self.cancellables)
    }
}

final class SelectEventRepeatOptionViewEventHandlers: ObservableObject {
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var itemSelect: (String) -> Void = { _ in }
    var endTimeSelect: (Date) -> Void = { _ in }
    var toggleHasEndTime: (Bool) -> Void = { _ in }
}


// MARK: - SelectEventRepeatOptionContainerView

struct SelectEventRepeatOptionContainerView: View {
    
    @StateObject private var state: SelectEventRepeatOptionViewState = .init()
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
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - SelectEventRepeatOptionView

struct SelectEventRepeatOptionView: View {
    
    @EnvironmentObject private var state: SelectEventRepeatOptionViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    @EnvironmentObject private var eventHandlers: SelectEventRepeatOptionViewEventHandlers
    
    var body: some View {
        NavigationStack {
            
            List {
                ForEach(self.state.optionList, id: \.compareKey) {
                    self.sectionView($0)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .navigationTitle("Repeating".localized())
            .toolbar {
                CloseButton()
                    .eventHandler(\.onTap, self.eventHandlers.close)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    self.repeatEndBarView
                }
            }
        }
    }
    
    private func sectionView(_ section: [SelectRepeatingOptionModel]) -> some View {
        Section {
            ForEach(section, id: \.compareKey) { option in
                HStack {
                    Text(option.text)
                        .font(self.appearance.fontSet.normal.asFont)
                        .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                        .lineLimit(1)
                    
                    Spacer()
                    if self.state.selectedOptionId == option.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(self.appearance.colorSet.eventList.asColor)
                }
                .onTapGesture {
                    self.eventHandlers.itemSelect(option.id)
                }
            }
        } header: {
            Text("")
        }
    }
    
    private var repeatEndBarView: some View {
        HStack {
            Text("Repeat end date".localized())
            
            Spacer()
            
            DatePicker(
                "",
                selection: self.$state.selectedEndDate,
                displayedComponents: [.date]
            )
            .labelsHidden()
            .onChange(of: self.state.selectedEndDate) { date in
                self.eventHandlers.endTimeSelect(date)
            }
            
            Toggle(isOn: self.$state.hasEndTime) {
                Text("")
            }
            .onChange(of: self.state.hasEndTime) { new in
                self.eventHandlers.toggleHasEndTime(new)
            }
            .labelsHidden()
            .toggleStyle(.switch)
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
        let view = SelectEventRepeatOptionView()
        let state = SelectEventRepeatOptionViewState()
        state.optionList = [
            [.init("some", nil)],
            [.init("option1", nil), .init("option2", nil), .init("option3", nil)],
            [
                .init("option4", nil), .init("option5", nil), .init("option6", nil),
                .init("option7", nil), .init("option8", nil), .init("option9", nil)
            ]
        ]
        return view
            .environmentObject(viewAppearance)
            .environmentObject(state)
    }
}
