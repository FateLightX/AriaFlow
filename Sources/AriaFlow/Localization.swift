import Foundation

enum L10n {
    enum Language: Equatable {
        case chinese
        case english
    }

    struct Key: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Sendable {
        let template: String
        let values: [String]

        init(stringLiteral value: String) {
            template = value
            values = []
        }

        init(stringInterpolation: StringInterpolation) {
            template = stringInterpolation.template
            values = stringInterpolation.values
        }

        struct StringInterpolation: StringInterpolationProtocol, Sendable {
            var template = ""
            var values: [String] = []

            init(literalCapacity: Int, interpolationCount: Int) {
                template.reserveCapacity(literalCapacity + interpolationCount * 5)
                values.reserveCapacity(interpolationCount)
            }

            mutating func appendLiteral(_ literal: String) {
                template += literal
            }

            mutating func appendInterpolation<T>(_ value: T) {
                template += "{{\(values.count)}}"
                values.append(String(describing: value))
            }
        }
    }

    static func language(for preferredLanguages: [String] = Locale.preferredLanguages) -> Language {
        preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? .chinese : .english
    }

    static func tr(_ key: Key, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let localizedTemplate: String
        switch language(for: preferredLanguages) {
        case .chinese:
            localizedTemplate = key.template
        case .english:
            localizedTemplate = englishBundle.localizedString(
                forKey: key.template,
                value: key.template,
                table: nil
            )
        }

        return key.values.enumerated().reduce(localizedTemplate) { result, item in
            result.replacingOccurrences(of: "{{\(item.offset)}}", with: item.element)
        }
    }

    private static let englishBundle: Bundle = {
        var roots = [
            Bundle.main.resourceURL,
            Bundle.main.resourceURL?.appending(path: "Resources")
        ].compactMap { $0 }

        let bundleName = "AriaFlow_AriaFlow.bundle"
        let bundleURLs = [
            Bundle.main.bundleURL.appending(path: bundleName),
            Bundle.main.bundleURL.deletingLastPathComponent().appending(path: bundleName),
            URL(fileURLWithPath: CommandLine.arguments[0])
                .deletingLastPathComponent()
                .appending(path: bundleName)
        ]
        for bundleURL in bundleURLs {
            if let resourceURL = Bundle(url: bundleURL)?.resourceURL {
                roots.append(resourceURL)
                roots.append(resourceURL.appending(path: "Resources"))
            }
        }
        if Bundle.main.bundleURL.pathExtension != "app" {
            if let resourceURL = Bundle.module.resourceURL {
                roots.append(resourceURL)
                roots.append(resourceURL.appending(path: "Resources"))
            }
        }

        for root in roots {
            let localizationURL = root.appending(path: "en.lproj")
            if let bundle = Bundle(url: localizationURL) {
                return bundle
            }
        }
        return Bundle.main
    }()
}
