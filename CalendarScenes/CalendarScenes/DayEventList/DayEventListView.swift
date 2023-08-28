//
//  
//  DayEventListView.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - DayEventListViewController

final class DayEventListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: DayEventListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}


// MARK: - DayEventListContainerView

struct DayEventListContainerView: View {
    
    @StateObject private var state: DayEventListViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (DayEventListViewState) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return DayEventListView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - DayEventListView

struct DayEventListView: View {
    
    @EnvironmentObject private var state: DayEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        ForEach(0..<30) {
            Text("DayEventListView => \($0)")
        }
    }
}


// MARK: - preview

struct DayEventListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        let containerView = DayEventListContainerView(viewAppearance: viewAppearance)
        return containerView
    }
}

