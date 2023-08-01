//
//  ApplicationRootViewModel.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain

final class ApplicationRootViewModelImple {
 
    var router: ApplicationRootRouter?
}


extension ApplicationRootViewModelImple {
    
    func prepareInitialScene() {
        // TODO: 계정 유무에 따라 다른 팩토리 사용해서 초기 화면 구성해야함
        self.router?.setupInitialScene()
    }
}


