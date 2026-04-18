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

    @ViewBuilder
    private var popupContent: some View {
        switch requirement {
        case .forceRequired:
            forceRequiredContent
        case .recommended:
            recommendedContent
        }
    }

    private var forceRequiredContent: some View {
        popupCard {
            Text("force_update.title".localized())
                .font(appearance.fontSet.bigBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.center)

            Text("force_update.message".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
                .multilineTextAlignment(.center)

            ConfirmButton(
                title: "common.update".localized(),
                textColor: appearance.colorSet.primaryBtnText.asColor,
                backgroundColor: appearance.colorSet.primaryBtnBackground.asColor
            )
            .eventHandler(\.onTap) {
                self.onUpdate()
            }
        }
    }

    private var recommendedContent: some View {
        popupCard {
            Text("recommend_update.title".localized())
                .font(appearance.fontSet.bigBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.center)

            Text("recommend_update.message".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ConfirmButton(
                    title: "common.close".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap) {
                    self.closePopup { self.onClose?() }
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
    }

    private func popupCard<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(spacing: 20) {
            content()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(appearance.colorSet.bg0.asColor)
        )
    }

    private func closePopup(_ handler: @escaping () -> Void) {
        popupShown = false
        backgroundShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            handler()
        }
    }
}
