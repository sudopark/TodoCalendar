//
//  AppStoreCaptionSnapshots.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/27/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import UIKit
import SnapshotTestHelpKit

@testable import CommonPresentation


/// Pillow 로는 31개 언어(데바나가리·타이·CJK)를 한 TTF 로 못 그려 시스템 폰트 폴백에 맡긴다.
final class AppStoreCaptionSnapshots: XCTestCase {

    private var canvasWidth: CGFloat { 440 }
    private var canvasHeight: CGFloat { 140 }

    private var captionLayout: StoreCaptionLayout {
        return StoreCaptionLayout(maxWidth: self.canvasWidth - 48, maxFontSize: 34, minFontSize: 18)
    }

    @MainActor
    func test_storeCaptions() {
        guard let language = self.currentTestLanguage else {
            XCTFail("AppleLanguages 를 읽을 수 없다 — -testLanguage 없이 돌린 것이다")
            return
        }
        guard let descriptionText = self.descriptionText(ofLanguage: language) else {
            XCTFail("\(language): description.txt 가 없다 (ASC 로케일 \(self.ascLocale(of: language)))")
            return
        }
        let headings = self.sectionHeadings(of: descriptionText)

        StoreCaptionSlot.allCases.forEach { slot in
            guard let caption = slot.caption(language: language, headings: headings) else {
                XCTFail("\(slot.slug): \(language) 캡션 원고가 없다 — `·` 불릿 파생 규칙이 아직 없다")
                return
            }
            captureSnapshotPair(
                named: slot.slug,
                layout: .fixed(width: self.canvasWidth, height: self.canvasHeight),
                snapshotDirectory: catalogSnapshotDirectory()
            ) { _ in
                self.captionView(caption)
            }
        }
    }
}


// MARK: - 맞춤형 제품 페이지 캡션 (#1029)

/// 원고는 gitignore 대상이라 신선한 클론·CI 에는 없다 — 그때는 건너뛴다.
extension AppStoreCaptionSnapshots {

    private var customProductPageCaptionsPath: String {
        return "\(self.repositoryRootPath)/fastlane/custom_product_pages/captions.json"
    }

    @MainActor
    func test_customProductPageCaptions() throws {
        let path = self.customProductPageCaptionsPath
        guard let data = FileManager.default.contents(atPath: path) else {
            throw XCTSkip("captions.json 이 없다 — 맞춤형 제품 페이지 원고를 아직 안 채웠다 (\(path))")
        }
        guard let language = self.currentTestLanguage else {
            XCTFail("AppleLanguages 를 읽을 수 없다 — -testLanguage 없이 돌린 것이다")
            return
        }
        let captions = try JSONDecoder().decode([String: [String: String]].self, from: data)

        captions.keys.sorted().forEach { sceneId in
            guard let caption = captions[sceneId]?[language] else {
                XCTFail("\(sceneId): \(language) 캡션 원고가 없다")
                return
            }
            captureSnapshotPair(
                named: sceneId,
                layout: .fixed(width: self.canvasWidth, height: self.canvasHeight),
                snapshotDirectory: catalogSnapshotDirectory()
            ) { _ in
                self.captionView(caption)
            }
        }
    }
}


// MARK: - caption view

extension AppStoreCaptionSnapshots {

    @MainActor
    private func captionView(_ caption: String) -> some View {
        let resolved = self.captionLayout.resolve(caption)
        return VStack(spacing: 8) {
            ForEach(Array(resolved.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(Font(resolved.font))
                    .foregroundStyle(UIColor.from(hex: "#1D1D1F")?.asColor ?? .black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UIColor.from(hex: "#F5F5F7")?.asColor ?? .white)
    }
}


// MARK: - 원고 읽기

extension AppStoreCaptionSnapshots {

    /// -testLanguage 는 AppleLanguages 로 전달된다 — 테스트 번들 로컬라이제이션은 31개 언어를 다 담지 않아 여기선 못 쓴다.
    private var currentTestLanguage: String? {
        return UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first
    }

    private var repositoryRootPath: String {
        let filePath = "\(#filePath)"
        guard let range = filePath.range(of: "/Presentations/") else { return filePath }
        return String(filePath[..<range.lowerBound])
    }

    private func ascLocale(of language: String) -> String {
        switch language {
        case "en": return "en-US"
        case "de": return "de-DE"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        case "nl": return "nl-NL"
        case "nb": return "no"
        default: return language
        }
    }

    private func descriptionText(ofLanguage language: String) -> String? {
        let path = "\(self.repositoryRootPath)/fastlane/metadata/\(self.ascLocale(of: language))/description.txt"
        return try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }

    private func sectionHeadings(of description: String) -> [String] {
        return description.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("■") else { return nil }
            return trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
        }
    }
}


// MARK: - 라인업별 캡션 출처

/// `·` 불릿을 줄인 캡션은 파생 규칙이 없어 언어별 원고를 직접 들고 있어야 한다.
private enum StoreCaptionSlot: CaseIterable {
    case calendar
    case repeatOptions
    case eventDetail
    case googleEvent
    case widgets
    case appearance

    var slug: String {
        switch self {
        case .calendar: return "01-calendar"
        case .repeatOptions: return "02-repeat-options"
        case .eventDetail: return "03-event-detail"
        case .googleEvent: return "04-google-event"
        case .widgets: return "05-widgets"
        case .appearance: return "06-appearance"
        }
    }

    private var headingIndex: Int? {
        switch self {
        case .calendar: return 0
        case .widgets: return 2
        case .googleEvent: return 3
        case .appearance: return 4
        case .repeatOptions, .eventDetail: return nil
        }
    }

    private var writtenCaptions: [String: String] {
        switch self {
        case .repeatOptions:
            return [
                "ca": "L'aplicació us munta la repetició",
                "cs": "Aplikace sestaví opakování",
                "da": "Appen bygger gentagelsen",
                "de": "Die App baut die Wiederholung",
                "el": "Η εφαρμογή φτιάχνει την επανάληψη",
                "en": "The app builds the repeat for you",
                "es": "La app te arma la repetición",
                "fi": "Sovellus rakentaa toiston",
                "fr": "L'application construit la récurrence",
                "hi": "दोहराव ऐप बना देता है",
                "hr": "Aplikacija složi ponavljanje",
                "hu": "Az alkalmazás felépíti az ismétlődést",
                "id": "Aplikasi menyusun pengulangan",
                "it": "L'app costruisce la ricorrenza",
                "ja": "繰り返しはアプリが組み立てます",
                "ko": "다양한 반복 옵션, 음력까지",
                "ms": "Aplikasi membina pengulangan",
                "nb": "Appen bygger gjentakelsen",
                "nl": "De app bouwt de herhaling",
                "pl": "Aplikacja zbuduje powtarzanie",
                "pt-BR": "O app monta a recorrência",
                "ro": "Aplicația construiește repetarea",
                "ru": "Приложение соберёт повтор",
                "sk": "Aplikácia zostaví opakovanie",
                "sv": "Appen bygger upprepningen åt dig",
                "th": "แอปประกอบรูปแบบการทำซ้ำให้",
                "tr": "Uygulama tekrarlamayı kurar",
                "uk": "Додаток складе повторення",
                "vi": "Ứng dụng dựng sẵn kiểu lặp lại",
                "zh-Hans": "应用替你配好重复规则",
                "zh-Hant": "應用程式替您配好重複規則"
            ]
        case .eventDetail:
            return [
                "ca": "Ubicació, enllaç, nota, recordatoris",
                "cs": "Místo, odkaz, poznámka, připomenutí",
                "da": "Sted, link, note, påmindelser",
                "de": "Ort, Link, Notiz, Benachrichtigungen",
                "el": "Τοποθεσία, σύνδεσμος, σημείωση, υπενθυμίσεις",
                "en": "Location, link, memo, reminders",
                "es": "Ubicación, enlace, nota, recordatorios",
                "fi": "Paikka, linkki, muistiinpano, muistutukset",
                "fr": "Lieu, lien, note, rappels",
                "hi": "स्थान, लिंक, मेमो, रिमाइंडर",
                "hr": "Lokacija, poveznica, bilješka, podsjetnici",
                "hu": "Helyszín, hivatkozás, jegyzet, értesítés",
                "id": "Lokasi, tautan, catatan, notifikasi",
                "it": "Luogo, link, nota, promemoria",
                "ja": "場所・リンク・メモ・リマインダー",
                "ko": "위치, 링크, 메모, 미리알림",
                "ms": "Lokasi, pautan, nota, peringatan",
                "nb": "Sted, lenke, notat, varsler",
                "nl": "Locatie, link, notitie, meldingen",
                "pl": "Miejsce, link, notatka, przypomnienia",
                "pt-BR": "Localização, link, anotação, lembretes",
                "ro": "Locație, link, notă, notificări",
                "ru": "Место, ссылка, заметка, напоминания",
                "sk": "Miesto, odkaz, poznámka, upozornenia",
                "sv": "Plats, länk, anteckning, påminnelser",
                "th": "สถานที่ ลิงก์ บันทึกช่วยจำ การแจ้งเตือน",
                "tr": "Konum, bağlantı, not, hatırlatmalar",
                "uk": "Місце, посилання, нотатка, нагадування",
                "vi": "Vị trí, liên kết, ghi chú, nhắc nhở",
                "zh-Hans": "地点、链接、备注、事件提醒",
                "zh-Hant": "地點、連結、備註、活動提醒"
            ]
        case .calendar, .googleEvent, .widgets, .appearance: return [:]
        }
    }

    func caption(language: String, headings: [String]) -> String? {
        guard let headingIndex = self.headingIndex else {
            return self.writtenCaptions[language]
        }
        guard headings.indices.contains(headingIndex) else { return nil }
        return headings[headingIndex]
    }
}


// MARK: - 줄 나눔·폰트 크기

/// 31개 언어 길이 편차가 커서 고정 크기로는 안 된다.
private struct StoreCaptionLayout {

    let maxWidth: CGFloat
    let maxFontSize: CGFloat
    let minFontSize: CGFloat

    func resolve(_ caption: String) -> (font: UIFont, lines: [String]) {
        let sizes: [CGFloat] = stride(from: self.maxFontSize, through: self.minFontSize, by: -1).map { $0 }
        let fitted = sizes.compactMap { size -> (font: UIFont, lines: [String])? in
            let font = UIFont.systemFont(ofSize: size, weight: .bold)
            guard let lines = self.lines(caption, with: font) else { return nil }
            return (font, lines)
        }.first
        return fitted ?? (UIFont.systemFont(ofSize: self.minFontSize, weight: .bold), [caption])
    }

    private func lines(_ caption: String, with font: UIFont) -> [String]? {
        guard self.width(caption, font) > self.maxWidth else { return [caption] }
        return self.balancedPair(caption, font)
    }

    private func balancedPair(_ caption: String, _ font: UIFont) -> [String]? {
        let pairs = self.wordStarts(of: caption).map { index in
            return [
                String(caption[..<index]).trimmingCharacters(in: .whitespaces),
                String(caption[index...]).trimmingCharacters(in: .whitespaces)
            ]
        }
        let fitting = pairs.filter { pair in
            pair.allSatisfy { !$0.isEmpty && self.width($0, font) <= self.maxWidth }
        }
        return fitting.min { self.widthGap($0, font) < self.widthGap($1, font) }
    }

    private func widthGap(_ pair: [String], _ font: UIFont) -> CGFloat {
        return abs(self.width(pair[0], font) - self.width(pair[1], font))
    }

    private func wordStarts(of caption: String) -> [String.Index] {
        var starts: [String.Index] = []
        caption.enumerateSubstrings(
            in: caption.startIndex..<caption.endIndex, options: [.byWords]
        ) { _, range, _, _ in
            starts.append(range.lowerBound)
        }
        return Array(starts.dropFirst())
    }

    private func width(_ text: String, _ font: UIFont) -> CGFloat {
        return (text as NSString).size(withAttributes: [.font: font]).width
    }
}
