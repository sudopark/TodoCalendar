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
    var addTag: () -> Void = { }
    var closeScene: () -> Void = { }
    var toggleEventTagViewingIsOn: (String) -> Void = { _ in }
    var showTagDetail: (String) -> Void = { _ in }
    
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
    fileprivate var toggleEventTagViewingIsOn: (String) -> Void = { _ in }
    fileprivate var showTagDetail: (String) -> Void = { _ in }
    
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
            Button {
                self.toggleEventTagViewingIsOn(cellViewModel.id)
            } label: {
                Image(systemName: cellViewModel.isOn ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(Color.from(cellViewModel.colorHext) ?? .clear)
                    .font(.title3)
                    .animation(.easeIn, value: cellViewModel.isOn)
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

private extension EventTagCellViewModel {
    
    var compareKey: String {
        let components = [
            self.id, self.name, self.colorHext, "\(self.isOn)"
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
            EventTagCellViewModel(id: "id:\($0)", name: "name:\($0)", colorHext: "#ff0000")
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
