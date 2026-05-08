import SwiftUI

struct StartupSplashContainer<Content: View>: View {
    private let minimumDisplayDuration: UInt64 = 1_150_000_000
    private let content: Content

    @State private var isSplashVisible = true
    @State private var hasStartedDismissalClock = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            if isSplashVisible {
                StartupSplashView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
            }
        }
        .task {
            guard !hasStartedDismissalClock else {
                return
            }
            hasStartedDismissalClock = true
            try? await Task.sleep(nanoseconds: minimumDisplayDuration)
            withAnimation(.easeInOut(duration: 0.32)) {
                isSplashVisible = false
            }
        }
    }
}

private struct StartupSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            SauceColor.surface
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Image("SplashIconMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 210, height: 210)
                    .scaleEffect(reduceMotion ? 1 : (isBreathing ? 1.035 : 0.985))
                    .offset(y: hasAppeared ? 0 : 8)
                    .opacity(hasAppeared ? 1 : 0)

                Image("SplashWordmark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(SauceColor.onSurface)
                    .frame(width: 208)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 6)
            }
            .padding(.horizontal, 44)
            .onAppear {
                withAnimation(.easeOut(duration: 0.42)) {
                    hasAppeared = true
                }

                guard !reduceMotion else {
                    return
                }

                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("NuguSauce")
    }
}

#Preview {
    StartupSplashView()
}
