//
//  ForceUpdatePopupView.swift
//  TodoCalendarApp
//

import SwiftUI
import Domain
import CommonPresentation
import Extensions

struct ForceUpdatePopupView: View {

    let requirement: AppUpdateRequirement
    let onUpdate: () -> Void
    let onClose: (() -> Void)?

    @State private var popupShown: Bool = false
    @State private var backgroundShown: Bool = false
    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundShown ? 0.5 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: backgroundShown)

            popupContent
                .padding(.horizontal, 40)
                .opacity(popupShown ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: popupShown)
        }
        .onAppear {
            popupShown = true
            backgroundShown = true
        }
    }

    private var popupContent: some View {
        VStack(spacing: 20) {
            Text(titleText)
                .font(appearance.fontSet.bigBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.center)

            Text(messageText)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
                .multilineTextAlignment(.center)

            actionButtons
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            
            if self.requirement == .recommended {
                ConfirmButton(
                    title: "common.close".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap) {
                    self.closePopup { self.onClose?() }
                }
            }
            
            ConfirmButton(
                title: "common.update".localized(),
                textColor: appearance.colorSet.primaryBtnText.asColor,
                backgroundColor: appearance.colorSet.primaryBtnBackground.asColor
            )
            .eventHandler(\.onTap) {
                self.closePopup { self.onUpdate() }
            }
        }
    }

    private func closePopup(_ handler: @escaping () -> Void) {
        popupShown = false
        backgroundShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            handler()
        }
    }

    private var titleText: String {
        switch requirement {
        case .forceRequired:
            return "force_update.title".localized()
        case .recommended:
            return "recommend_update.title".localized()
        }
    }

    private var messageText: String {
        switch requirement {
        case .forceRequired:
            return "force_update.message".localized()
        case .recommended:
            return "recommend_update.message".localized()
        }
    }
}
