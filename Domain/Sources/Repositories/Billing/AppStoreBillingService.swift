//
//  AppStoreBillingService.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// StoreKit 어댑터 계약. StoreKit 타입이 시그니처에 새어나오지 않게 해
// 구현체(StoreKitService.AppStoreBillingServiceImple)가 별도 프레임워크에 있어도 이 계약은 그대로 유지된다
public protocol AppStoreBillingService: AnyObject, Sendable {

    func loadProducts(ids: [String]) async throws -> [BillingProduct]

    // 결제 UI 를 띄우고 결과를 outcome 으로 구분해 반환.
    // 유저 취소(.cancelled)와 승인대기(Ask to Buy, .pending)는 둘 다 검증된 트랜잭션이 없지만
    // UI 대응이 다르다 — 취소는 닫기, 승인대기는 "보호자 승인 대기 중" 안내가 필요하다
    func purchase(productId: String) async throws -> BillingTransactionOutcome

    // 복원 — 현재 유효한 권한. 소모품(top-up)은 여기 잡히지 않는다
    func restorePurchases() async throws -> [BillingSignedTransaction]

    // 서버 반영 전 앱이 죽어 finish 되지 않은 트랜잭션
    func unfinishedTransactions() async -> [BillingSignedTransaction]

    // 앱 밖 갱신·환불·가족공유·승인대기 통과가 들어오는 유일한 경로
    var transactionUpdates: AsyncStream<BillingSignedTransaction> { get }

    // 서버 반영이 성공한 뒤에만 호출 — 먼저 부르면 실패 시 영수증이 사라져 복구 불가
    func finishTransaction(id: String) async
}
