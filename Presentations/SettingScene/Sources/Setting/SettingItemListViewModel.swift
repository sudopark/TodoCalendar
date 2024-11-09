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


protocol SettingItemModelType {
    var compareKey: String { get }
}

struct SettingItemModel: SettingItemModelType {
    enum ItemId: String, Equatable {
        case appearance
        case editEvent
        case holidaySetting
        case feedback
        case help
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
            self.text = "setting.appearance.title".localized()
        case .editEvent:
            self.iconNamge = "calendar"
            self.text = "setting.appearance.event.edit::name".localized()
        case .holidaySetting:
            self.iconNamge = "globe"
            self.text = "setting.holiday.item::name".localized()
        case .feedback:
            self.iconNamge = "ellipsis.bubble"
            self.text = "setting.feedback::name".localized()
        case .help:
            self.iconNamge = "questionmark.circle"
            self.text = "setting.help::name".localized()
        case .shareApp:
            self.iconNamge = "square.and.arrow.up"
            self.text = "setting.share::name".localized()
        case .addReview:
            self.iconNamge = "star"
            self.text = "setting.write_review::name".localized()
        case .sourceCode:
            self.iconNamge = "pc"
            self.text = "Source Code"
        }
    }
    
    var compareKey: String { self.itemId.rawValue }
}

struct AccountSettingItemModel: SettingItemModelType {
    var compareKey: String {
        return "\(self.isSignIn)-\(self.signInMethod ?? "")"
    }
    let signInMethod: String?
    let isSignIn: Bool
    var iconName: String {
        return self.isSignIn ? "person.crop.circle" : "person.crop.circle.badge.plus"
    }
    var title: String {
        return self.isSignIn
            ? "setting.account.signedIn::manageAccount".localized()
            : "setting.account.needSignIn".localized()
    }
    
    init(_ accountInfo: AccountInfo?) {
        self.isSignIn = accountInfo != nil
        self.signInMethod = accountInfo?.signInMethod
    }
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
            name: "setting.suggest::readmind::appName".localized(),
            description: "setting.suggest::readmind::message".localized(),
            sourcePath: "http://itunes.apple.com/app/id/id1565634642"
        )
    }
}


protocol SettingSectionModelType {
    var headerText: String? { get }
    var compareKey: String { get }
    var items: [any SettingItemModelType] { get }
}
struct SettingSectionModel: SettingSectionModelType {
    
    let headerText: String?
    let items: [any SettingItemModelType]
    
    init(headerText: String?, items: [any SettingItemModelType]) {
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
    func selectItem(_ model: any SettingItemModelType)
    func close()
    
    // presenter
    var sectionModels: AnyPublisher<[any SettingSectionModelType], Never> { get }
}


// MARK: - SettingItemListViewModelImple

final class SettingItemListViewModelImple: SettingItemListViewModel, @unchecked Sendable {
    
    private let appId: String
    private let accountUsecase: any AccountUsecase
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any SettingItemListRouting)?
    
    init(
        appId: String,
        accountUsecase: any AccountUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.appId = appId
        self.accountUsecase = accountUsecase
        self.uiSettingUsecase = uiSettingUsecase
    }
    
    
    private struct Subject {
        let sections = CurrentValueSubject<[any SettingSectionModelType]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private var appstoreLinkPath: String {
        return "https://itunes.apple.com/app/id/\(self.appId)"
    }
    
    private var helpPath_ko: String {
        return "https://readmind.notion.site/To-do-Calendar-36cba0bdc84b44de9abdfd7d8721cd91"
    }
    
    private var helpPath_en: String {
        return "https://readmind.notion.site/To-do-Calendar-Help-a2183ee1a41946faa8e0658640fb4c6a?pvs=4"
    }
}


// MARK: - SettingItemListViewModelImple Interactor

extension SettingItemListViewModelImple {
    
    func selectItem(_ model: any SettingItemModelType) {
        switch model {
        case let settingItem as SettingItemModel:
            self.handleSettingItemSelected(settingItem)
        case let account as AccountSettingItemModel:
            self.handleSignIn(account)
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
            
        case .editEvent:
            self.router?.routeToEventSetting()
            
        case .holidaySetting:
            self.router?.routeToHolidaySetting()
            
        case .feedback:
            self.router?.routeToFeedbackPost()
            
        case .help:
            let isKorean = Locale.current.language.languageCode == .korean
            self.router?.openSafari(
                isKorean ? self.helpPath_ko : self.helpPath_en
            )
            
        case .shareApp:
            self.router?.openShare(link: self.appstoreLinkPath)
            
        case .addReview:
            self.router?.openSafari(self.appstoreLinkPath)
            
        case .sourceCode:
            self.router?.openSafari("https://github.com/sudopark/TodoCalendar")
        }
    }
    
    private func handleSignIn(_ item: AccountSettingItemModel) {
        if item.isSignIn {
            self.router?.routeToAccountManage()
        } else {
            self.router?.routeToSignIn()
        }
    }
    
    private func routeApearanceSetting() {
        
        let setting = self.uiSettingUsecase.loadSavedAppearanceSetting()
        self.router?.routeToAppearanceSetting(inital: setting.calendar)
    }
}


// MARK: - SettingItemListViewModelImple Presenter

extension SettingItemListViewModelImple {
    
    var sectionModels: AnyPublisher<[any SettingSectionModelType], Never> {
        
        let transform: (AccountInfo?) -> [any SettingSectionModelType] = { account in
            let baseSectionItems: [SettingItemModel] = [
                .init(.appearance),
                .init(.editEvent),
                .init(.holidaySetting)
            ]
            let accountItem = AccountSettingItemModel(account)
            let baseSection = SettingSectionModel(
                headerText: nil, 
                items: baseSectionItems + [accountItem]
            )
            
            let supportSectionItems: [SettingItemModel] = [
                .init(.feedback),
                .init(.help)
            ]
            let supportSection = SettingSectionModel(headerText: "setting.section.support::name".localized(), items: supportSectionItems)
            
            let appInfoSectionItems: [SettingItemModel] = [
                .init(.shareApp),
                .init(.addReview),
                .init(.sourceCode)
            ]
            let appInfoSection = SettingSectionModel(headerText: "setting.section.app::name".localized(), items: appInfoSectionItems)
            
            let suggestItem = SuggestAppItemModel.readmind()
            let suggestSection = SettingSectionModel(headerText: "setting.section.suggest::name".localized(), items: [suggestItem])
            
            let sections: [any SettingSectionModelType] = [
                baseSection, supportSection, appInfoSection, suggestSection
            ]
            return sections
        }
        
        return self.accountUsecase.currentAccountInfo
            .map(transform)
            .removeDuplicates(by: { $0.map { $0.compareKey } == $1.map { $0.compareKey } })
            .eraseToAnyPublisher()
    }
}
