import SwiftUI

enum PrismaTypography {
    static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, design: .default, weight: weight)
    }

    static func title(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title2, design: .default, weight: weight)
    }

    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, design: .default, weight: weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.body, design: .default, weight: weight)
    }

    static func callout(_ weight: Font.Weight = .regular) -> Font {
        .system(.callout, design: .default, weight: weight)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption, design: .default, weight: weight)
    }

    static func caption2(_ weight: Font.Weight = .regular) -> Font {
        .system(.caption2, design: .default, weight: weight)
    }

    /// Scales article reader text based on user preference multiplier.
    static func readerBody(
      sizeMultiplier: Double = 1.0,
      family: ReaderFontFamily = .serif
    ) -> Font {
        .system(size: 17 * sizeMultiplier, weight: .regular, design: family.fontDesign)
    }

    static func readerTitle(sizeMultiplier: Double = 1.0) -> Font {
        .system(size: 28 * sizeMultiplier, weight: .bold, design: .default)
    }
}
