import SwiftUI

enum SauceColor {
    static let surface = Color(red: 0.976, green: 0.976, blue: 0.976)
    static let surfaceContainer = Color(red: 0.933, green: 0.933, blue: 0.933)
    static let surfaceContainerLow = Color(red: 0.953, green: 0.953, blue: 0.953)
    static let surfaceLowest = Color.white
    static let primary = Color(red: 0.718, green: 0.0, blue: 0.047)
    static let primaryContainer = Color(red: 0.902, green: 0.0, blue: 0.071)
    static let secondary = Color(red: 0.988, green: 0.831, blue: 0.0)
    static let onSurface = Color(red: 0.102, green: 0.110, blue: 0.110)
    static let onSurfaceVariant = Color(red: 0.372, green: 0.235, blue: 0.211)
    static let muted = Color(red: 0.620, green: 0.580, blue: 0.590)
    static let outline = Color(red: 0.580, green: 0.431, blue: 0.412)
    static let chip = Color(red: 0.925, green: 0.914, blue: 0.910)
    static let redTint = Color(red: 1.0, green: 0.918, blue: 0.925)
}

enum SauceSpacing {
    static let screen: CGFloat = 18
    static let section: CGFloat = 28
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 14
}

extension View {
    func sauceCard(cornerRadius: CGFloat = SauceSpacing.cardRadius) -> some View {
        background(SauceColor.surfaceLowest)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: SauceColor.primary.opacity(0.08), radius: 24, x: 0, y: 12)
    }

    func primarySauceButton() -> some View {
        font(.headline.weight(.bold))
            .foregroundStyle(.white)
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
            .shadow(color: SauceColor.primary.opacity(0.22), radius: 22, x: 0, y: 10)
    }
}
