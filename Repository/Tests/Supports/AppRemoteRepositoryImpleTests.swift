//
//  AppRemoteRepositoryImpleTests.swift
//  RepositoryTests
//

import XCTest
import UnitTestHelpKit

@testable import Domain
@testable import Repository


class AppRemoteRepositoryImpleTests: BaseTestCase {

    private var stubRemote: StubRemoteAPI!

    override func setUpWithError() throws {
        self.stubRemote = .init(responses: DummyResponse().responses)
    }

    override func tearDownWithError() throws {
        self.stubRemote = nil
    }

    private func makeRepository(
        shouldFail: Bool = false
    ) -> AppRemoteRepositoryImple {
        if shouldFail {
            self.stubRemote.shouldFailRequest = true
        }
        return AppRemoteRepositoryImple(remoteAPI: self.stubRemote)
    }
}


extension AppRemoteRepositoryImpleTests {

    func test_loadUpdateInfo() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let info = try await repository.loadUpdateInfo()

        // then
        XCTAssertEqual(info.forceUpdateVersion, "3.0.0")
        XCTAssertEqual(info.recommendUpdateVersion, "2.5.0")
    }

    func test_whenFetchFails_throwError() async {
        // given
        let repository = self.makeRepository(shouldFail: true)

        // when + then
        do {
            let _ = try await repository.loadUpdateInfo()
            XCTFail("should fail")
        } catch {
            // expected
        }
    }
}


private struct DummyResponse {

    private var updateInfoResponse: String {
        return """
        {
            "force_update_version": "3.0.0",
            "recommend_update_version": "2.5.0"
        }
        """
    }

    var responses: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .get,
                endpoint: AppEndpoints.updateInfo,
                resultJsonString: .success(self.updateInfoResponse)
            )
        ]
    }
}
