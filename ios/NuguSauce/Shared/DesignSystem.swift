import SwiftUI
import UIKit

enum SauceThemePreference: String, CaseIterable, Identifiable {
    static let storageKey = "sauce.themePreference"

    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            return "시스템"
        case .light:
            return "라이트"
        case .dark:
            return "다크"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum SauceColor {
    static let surface = dynamic(light: color(0.976, 0.976, 0.976), dark: color(0.082, 0.063, 0.059))
    static let surfaceContainer = dynamic(light: color(0.933, 0.933, 0.933), dark: color(0.153, 0.118, 0.110))
    static let surfaceContainerLow = dynamic(light: color(0.953, 0.953, 0.953), dark: color(0.118, 0.090, 0.086))
    static let surfaceLowest = dynamic(light: color(1.000, 1.000, 1.000), dark: color(0.188, 0.141, 0.129))
    static let primary = dynamic(light: color(0.718, 0.000, 0.047), dark: color(1.000, 0.314, 0.376))
    static let primaryContainer = dynamic(light: color(0.902, 0.000, 0.071), dark: color(1.000, 0.392, 0.447))
    static let secondary = dynamic(light: color(0.988, 0.831, 0.000), dark: color(1.000, 0.875, 0.239))
    static let onSurface = dynamic(light: color(0.102, 0.110, 0.110), dark: color(0.973, 0.929, 0.918))
    static let onSurfaceVariant = dynamic(light: color(0.372, 0.235, 0.211), dark: color(0.863, 0.753, 0.733))
    static let muted = dynamic(light: color(0.620, 0.580, 0.590), dark: color(0.678, 0.600, 0.584))
    static let outline = dynamic(light: color(0.580, 0.431, 0.412), dark: color(0.788, 0.580, 0.549))
    static let chip = dynamic(light: color(1.000, 0.956, 0.960), dark: color(0.231, 0.176, 0.165))
    static let redTint = dynamic(light: color(1.000, 0.894, 0.780), dark: color(0.267, 0.110, 0.129))
    static let recipeTagFill = dynamic(light: color(1.000, 0.949, 0.784), dark: color(0.392, 0.247, 0.098))
    static let recipeTagText = dynamic(light: color(0.635, 0.090, 0.043), dark: color(1.000, 0.855, 0.353))
    static let photoPlaceholderStart = dynamic(light: color(1.000, 0.965, 0.902), dark: color(0.169, 0.196, 0.188))
    static let photoPlaceholderEnd = dynamic(light: color(0.996, 0.860, 0.710), dark: color(0.282, 0.216, 0.176))
    static let onPrimary = Color.white
    static let cardShadow = Color.clear

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

enum SauceSpacing {
    static let screen: CGFloat = 18
    static let section: CGFloat = 28
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 14
}

enum SauceTypography {
    static func heroTitle(_ weight: Font.Weight = .black) -> Font {
        .system(size: 28, weight: weight)
    }

    static func sectionTitle(_ weight: Font.Weight = .black) -> Font {
        .system(size: 21, weight: weight)
    }

    static func cardTitle(_ weight: Font.Weight = .black) -> Font {
        .system(size: 14, weight: weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .subheadline.weight(weight)
    }

    static func supporting(_ weight: Font.Weight = .regular) -> Font {
        .footnote.weight(weight)
    }

    static func badge(_ weight: Font.Weight = .bold) -> Font {
        .caption2.weight(weight)
    }

    static func metric(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 11, weight: weight)
    }

    static func micro(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 9, weight: weight)
    }

    static func rankDisplay(_ weight: Font.Weight = .black) -> Font {
        .system(size: 50, weight: weight)
    }

    static func iconSmall(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 16, weight: weight)
    }

    static func iconMedium(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 21, weight: weight)
    }

    static func iconLarge(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 28, weight: weight)
    }

    static func avatarFallbackIcon(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size * 0.82, weight: weight)
    }

    static func favoriteIcon(size: CGFloat, isActive: Bool) -> Font {
        .system(size: size * 0.58, weight: isActive ? .black : .regular)
    }
}

extension View {
    func sauceCard(cornerRadius: CGFloat = SauceSpacing.cardRadius) -> some View {
        background(SauceColor.surfaceLowest)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func primarySauceButton() -> some View {
        font(SauceTypography.body(.bold))
            .foregroundStyle(SauceColor.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [SauceColor.primary, SauceColor.primaryContainer],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: SauceSpacing.controlRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: SauceSpacing.controlRadius, style: .continuous))
    }
}
