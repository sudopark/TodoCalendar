//
//  AppEnvironment.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/02.
//

import Foundation
import Domain
import Repository

struct AppEnvironment {
    
    private enum Constant {
        static let testDBFileNamePrefix: String = "test_dummy"
        static let e2eRunMarkerFileName: String = "e2e-run.marker"
        // 1회 실행이 67초라 한 실행을 충분히 덮으면서, 잔존 시 오염 창을 짧게 남긴다
        static let e2eRunMarkerTTL: TimeInterval = 600
    }
    
    static var useEmulator: Bool { false }
    
    static var isTestBuild: Bool {
#if DEBUG
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
#endif
        return false
    }
    
    static var isUITestRun: Bool {
#if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uiTest")
#endif
        return false
    }
    
    static var isExternalDependencyBlocked: Bool {
        return self.isTestBuild || self.isUITestRun || self.isE2ERunMarked
    }
    
    // 포트 1은 예약 포트라 즉시 refuse — 타임아웃 대기가 없다
    static var blockedAPIHost: String { "http://127.0.0.1:1" }
    
    static var e2eLaunchAPIHost: String? {
        return ProcessInfo.processInfo.environment["E2E_API_HOST"]
    }
    
    // 확장 프로세스는 실행 인자·환경변수를 못 받아 마커 파일이 유일한 인지 수단이다
    static var isE2ERunMarked: Bool {
        return self.e2eRunMarker?.isValid(at: Date()) == true
    }
    
    private static var e2eMarkedAPIHost: String? {
        guard let marker = self.e2eRunMarker, marker.isValid(at: Date()) else { return nil }
        return marker.host
    }
    
    // 캐싱하면 앱보다 먼저 뜬 확장이 뒤늦게 생긴 마커를 영영 못 본다 (실측: 위젯이 1초 앞선다)
    private static var e2eRunMarker: E2ERunMarker? {
#if DEBUG
        guard let url = self.e2eRunMarkerURL,
              let data = try? Data(contentsOf: url)
        else { return nil }
        return E2ERunMarker(data: data)
#else
        return nil
#endif
    }
    
    private static var e2eRunMarkerURL: URL? {
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: self.groupID)?
            .appending(path: Constant.e2eRunMarkerFileName)
    }
    
    static func writeE2ERunMarker(host: String) {
        guard let url = self.e2eRunMarkerURL else { return }
        let marker = E2ERunMarker(
            host: host,
            expiresAt: Date().addingTimeInterval(Constant.e2eRunMarkerTTL)
        )
        try? marker.encoded().write(to: url, options: .atomic)
    }
    
    static func removeE2ERunMarker() {
        guard let url = self.e2eRunMarkerURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    private static var dbFileName: String {
        if self.isExternalDependencyBlocked {
            return Constant.testDBFileNamePrefix
        } else {
            return "models"
        }
    }
    
    // AppDelegate 의 접두 매칭 청소가 그대로 커버하도록 실행별 DB 도 같은 접두를 쓴다
    private static func isolatedDBFileName(_ name: String) -> String {
        guard self.isExternalDependencyBlocked else { return name }
        return "\(Constant.testDBFileNamePrefix)_\(name)"
    }
    
    static var groupID: String {
        return "group.sudo.park.todo-calendar"
    }
    
    // 실 저장소와 갈라야 테스트 실행이 앱이 쌓은 값을 못 본다 — dbFileName 과 같은 축이다
    static var userDefaultSuiteName: String {
        if self.isExternalDependencyBlocked {
            return "\(self.groupID).test"
        } else {
            return self.groupID
        }
    }
    
    static var appId: String { "6639620385" }
    static var appstoreLinkPath: String {
        return "https://itunes.apple.com/app/id/\(self.appId)"
    }
    
    static func dbFilePath(for userId: String?) -> String {
        let fileName = userId.map { "\(self.dbFileName)_\($0)" } ?? self.dbFileName
        return self.dbPath(fileName: fileName)
    }
    
    static func externalCalendarDBPaths() -> [String: String] {
        let googlePath = self.dbPath(
            fileName: self.isolatedDBFileName("\(GoogleCalendarService.id)_calendar")
        )
        let applePath = self.dbPath(
            fileName: self.isolatedDBFileName("\(AppleCalendarService.id)__calendar")
        )
        return [
            GoogleCalendarService.id: googlePath,
            AppleCalendarService.id: applePath
        ]
    }
    
    private static func dbPath(fileName: String) -> String {
        let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupID)
        let dbUrl = directory?.appending(path: "\(fileName).db")
        return dbUrl?.path() ?? ""
    }
    
    static var keyChainStoreName: String {
        if self.isExternalDependencyBlocked {
            return "TodoCalendar.test"
        } else {
            return "TodoCalendar"
        }
    }
    
    static func calendarAPIHost(secrets: [String: Any]) -> String? {
        guard self.isExternalDependencyBlocked == false
        else {
            return self.e2eLaunchAPIHost ?? self.e2eMarkedAPIHost ?? self.blockedAPIHost
        }
        return self.useEmulator
            ? secrets["emulator_caleandar_api_host"] as? String
            : secrets["caleandar_api_host"] as? String
    }
    
    static let apiDefaultTimeoutSeconds: TimeInterval = 30
    
    static let eventUploadMaxFailCount: Int = 10
    
    static let googleCalendarService = GoogleCalendarService(scopes: [.readonly])
    static let appleCalendarService = AppleCalendarService()
    static var supportExternalCalendarServices: [ExternalCalendarService] {
        return [googleCalendarService, appleCalendarService]
    }

    struct AdUnitIds {
        let banner: String
        let mediumRectangle: String
        let fullScreen: String
    }

    static var admobUnitIds: AdUnitIds {
        // MREC 전용 단위를 따로 발급하지 않아 배너와 한 단위를 공유한다
        let banner: String = "ca-app-pub-4980913859277199/4855632588"
        return AdUnitIds(
            banner: banner,
            mediumRectangle: banner,
            fullScreen: "ca-app-pub-4980913859277199/7394166018"
        )
    }
    
    static var admobTestDeviceIdentifiers: [String] { ["ae5e8b3d51ff482948d92b1ee888e81f"] }

    static let dbVersion: Int32 = 7
    static let googleCalendarDBVersion: Int32 = 1
    static let appleCalendarDBVersion: Int32 = 0
    
    static func deviceId(_ storage: any EnvironmentStorage) -> String {
        let installKey = "install_id"
        if let installId: String = storage.load(installKey) {
            return installId
        }
        let newId = UUID().uuidString
        storage.update(installKey, newId)
        return newId
    }
}
