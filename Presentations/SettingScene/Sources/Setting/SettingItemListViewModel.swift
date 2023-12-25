//
//  
//  SettingItemListViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import Foundation
import Combine
import Domain
import Scenes


protocol SettingItemModelType: Equatable {
    var compareKey: String { get }
}

struct SettingItemModel: SettingItemModelType {
    enum ItemId: String, Equatable {
        case appearance
        case editEvent
        case holidaySetting
        case feedback
        case faq
        case shareApp
        case addReview
        case sourceCode
    }
    
    let itemId: ItemId
    let iconNamge: String
    let text: String
    
    init(_ itemId: ItemId) {
        self.itemId = itemId
        switch itemId {
        case .appearance:
            self.iconNamge = "eyeglasses"
            self.text = "Appearance".localized()
        case .editEvent:
            self.iconNamge = "calendar"
            self.text = "Edit Event".localized()
        case .holidaySetting:
            self.iconNamge = "globe"
            self.text = "Holiday Setting".localized()
        case .feedback:
            self.iconNamge = "ellipsis.bubble"
            self.text = "Feedback".localized()
        case .faq:
            self.iconNamge = "questionmark.circle"
            self.text = "Help".localized()
        case .shareApp:
            self.iconNamge = "square.and.arrow.up"
            self.text = "Share App".localized()
        case .addReview:
            self.iconNamge = "star"
            self.text = "Write an App Store review".localized()
        case .sourceCode:
            self.iconNamge = "pc"
            self.text = "Source Code"
        }
    }
    
    var compareKey: String { self.itemId.rawValue }
}

struct SuggestAppItemModel: SettingItemModelType {
    
    let imagePath: String
    let name: String
    var description: String?
    let sourcePath: String
    
    var compareKey: String { self.sourcePath }
    
    static func readmind() -> SuggestAppItemModel {
        return SuggestAppItemModel(
            imagePath: "https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/c8/77/ec/c877ec10-f7bb-2762-f512-0fa769ff6d6f/AppIcon-1x_U007emarketing-0-10-0-85-220.png/230x0w.webp",
            name: "Readmind",
            description: "Reading list management".localized(),
            sourcePath: "http://itunes.apple.com/app/id/id1565634642"
        )
    }
}


protocol SettingSectionModelType {
    associatedtype ItemType: SettingItemModelType
    var headerText: String? { get }
    var compareKey: String { get }
    var items: [ItemType] { get }
}
struct SettingSectionModel<ItemType: SettingItemModelType>: SettingSectionModelType {
    
    let headerText: String?
    let items: [ItemType]
    
    init(headerText: String?, items: [ItemType]) {
        self.headerText = headerText
        self.items = items
    }
    
    var compareKey: String {
        let items = self.items.map { $0.compareKey }.joined(separator: ",")
        return "\((self.headerText ?? "default"))_\(items)"
    }
}


// MARK: - SettingItemListViewModel

protocol SettingItemListViewModel: AnyObject, Sendable, SettingItemListSceneInteractor {

    // interactor
    func prepare()
    func selectItem(_ model: any SettingItemModelType)
    func close()
    
    // presenter
    var sectionModels: AnyPublisher<[any SettingSectionModelType], Never> { get }
}


// MARK: - SettingItemListViewModelImple

final class SettingItemListViewModelImple: SettingItemListViewModel, @unchecked Sendable {
    
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any SettingItemListRouting)?
    
    init(
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
    }
    
    
    private struct Subject {
        let sections = CurrentValueSubject<[any SettingSectionModelType]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - SettingItemListViewModelImple Interactor

extension SettingItemListViewModelImple {
    
    func prepare() {
        let baseSectionItems: [SettingItemModel] = [
            .init(.appearance),
            .init(.editEvent),
            .init(.holidaySetting)
        ]
        let baseSection = SettingSectionModel(headerText: nil, items: baseSectionItems)
        
        let supportSectionItems: [SettingItemModel] = [
            .init(.feedback),
            .init(.faq)
        ]
        let supportSection = SettingSectionModel(headerText: "Support".localized(), items: supportSectionItems)
        
        let appInfoSectionItems: [SettingItemModel] = [
            .init(.shareApp),
            .init(.addReview),
            .init(.sourceCode)
        ]
        let appInfoSection = SettingSectionModel(headerText: "App".localized(), items: appInfoSectionItems)
        
        let suggestItem = SuggestAppItemModel.readmind()
        let suggestSection = SettingSectionModel(headerText: "Suggest".localized(), items: [suggestItem])
        
        let sections: [any SettingSectionModelType] = [
            baseSection, supportSection, appInfoSection, suggestSection
        ]
        
        self.subject.sections.send(sections)
    }
    
    func selectItem(_ model: any SettingItemModelType) {
        switch model {
        case let settingItem as SettingItemModel:
            self.handleSettingItemSelected(settingItem)
        case let suggest as SuggestAppItemModel:
            self.router?.openSafari(suggest.sourcePath)
        default: break
        }
    }
    
    func close() {
        self.router?.closeScene()
    }
    
    private func handleSettingItemSelected(_ model: SettingItemModel) {
        switch model.itemId {
        case .appearance:
            self.routeApearanceSetting()
            
        case .editEvent: break
            
        case .holidaySetting:
            self.router?.routeToHolidaySetting()
            
        case .feedback: break
        case .faq: break
        case .shareApp: break
        case .addReview: break
        case .sourceCode: break
        }
    }
    
    private func routeApearanceSetting() {
        let setting = self.uiSettingUsecase.loadAppearanceSetting()
        self.router?.routeToAppearanceSetting(inital: setting)
    }
}


// MARK: - SettingItemListViewModelImple Presenter

extension SettingItemListViewModelImple {
    
    var sectionModels: AnyPublisher<[any SettingSectionModelType], Never> {
        return self.subject.sections
            .compactMap { $0 }
            .removeDuplicates(by: { $0.map { $0.compareKey } == $1.map { $0.compareKey } })
            .eraseToAnyPublisher()
            
    }
}
