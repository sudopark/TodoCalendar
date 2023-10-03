//
//  
//  EventTagListView.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//


import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation


// MARK: - EventTagListViewController

final class EventTagListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var cellviewModels: [EventTagCellViewModel] = []
    
    func bind(_ viewModel: any EventTagListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.cellViewModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] cellViewModels in
                withAnimation {
                    self?.cellviewModels = cellViewModels
                }
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - EventTagListContainerView

struct EventTagListContainerView: View {
    
    @StateObject fileprivate var state: EventTagListViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (EventTagListViewState) -> Void = { _ in }
    var onAppear: () -> Void = { }
    var addTag: () -> Void = { }
    var closeScene: () -> Void = { }
    var toggleEventTagViewingIsOn: (AllEventTagId) -> Void = { _ in }
    var showTagDetail: (AllEventTagId) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return EventTagListView()
            .eventHandler(\.addTag, self.addTag)
            .eventHandler(\.closeScene, self.closeScene)
            .eventHandler(\.toggleEventTagViewingIsOn, self.toggleEventTagViewingIsOn)
            .eventHandler(\.showTagDetail, self.showTagDetail)
            .onAppear {
                self.stateBinding(self.state)
                self.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - EventTagListView

struct EventTagListView: View {
    
    @EnvironmentObject private var state: EventTagListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    fileprivate var addTag: () -> Void = { }
    fileprivate var closeScene: () -> Void = { }
    fileprivate var toggleEventTagViewingIsOn: (AllEventTagId) -> Void = { _ in }
    fileprivate var showTagDetail: (AllEventTagId) -> Void = { _ in }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(self.state.cellviewModels, id: \.compareKey) {
                    self.cellView($0)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .toolbar {
                HStack(spacing: 8) {
                    Button {
                        self.addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                self.appearance.colorSet.event.asColor,
                                self.appearance.colorSet.eventList.asColor
                            )
                            .font(.system(size: 20))
                    }
                    Button {
                        self.closeScene()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                self.appearance.colorSet.event.asColor,
                                self.appearance.colorSet.eventList.asColor
                            )
                            .font(.system(size: 20))
                            
                    }
                }
            }
            .navigationTitle("Event Types".localized())
        }
    }
    
    private func cellView(_ cellViewModel: EventTagCellViewModel) -> some View {
        
        HStack {
            Image(systemName: cellViewModel.isOn ? "checkmark.circle.fill" : "checkmark.circle")
                .foregroundStyle(cellViewModel.color.color(with: self.appearance).asColor)
                .font(.title3)
                .animation(.easeIn, value: cellViewModel.isOn)
                .onTapGesture {
                    self.toggleEventTagViewingIsOn(cellViewModel.id)
                }
            Text(cellViewModel.name)
                .lineLimit(1)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            Spacer()
            Button {
                self.showTagDetail(cellViewModel.id)
            } label: {
                HStack {
                    RoundedRectangle(cornerRadius: 1).frame(width: 1)
                        .foregroundStyle(self.appearance.colorSet.subNormalText.withAlphaComponent(0.1).asColor)
                    Image(systemName: "info.circle")
                        .foregroundStyle(self.appearance.colorSet.subNormalText.withAlphaComponent(0.6).asColor)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.eventList.asColor)
        )
    }
}

private extension AllEventTagId {
    var compareKey: String {
        switch self {
        case .holiday: return "holiday"
        case .default: return "default"
        case .custom(let id): return id
        }
    }
}

private extension EventTagColor {
    var compareKey: String {
        switch self {
        case .holiday: return "holiday"
        case .default: return "default"
        case .custom(let hex): return hex
        }
    }
}

private extension EventTagCellViewModel {
    
    var compareKey: String {
        let components = [
            self.id.compareKey, self.name, self.color.compareKey, "\(self.isOn)"
        ]
        return components.joined(separator: "-")
    }
}



// MARK: - preview

struct EventTagListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        let state = EventTagListViewState()
        state.cellviewModels = (0..<20).map {
            EventTagCellViewModel(id: .custom("id:\($0)"), name: "name:\($0)", color: .custom(hex: "#ff0000"))
        }
        return EventTagListView()
            .eventHandler(\.toggleEventTagViewingIsOn) { id in
                guard let index = state.cellviewModels.firstIndex(where: { $0.id == id })
                else { return }
                let newCells = state.cellviewModels |> ix(index) %~ {
                    $0 |> \.isOn .~ !$0.isOn
                }
                state.cellviewModels = newCells
            }
            .environmentObject(viewAppearance)
            .environmentObject(state)
    }
}
