import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnOutsideTap() -> some View {
        background(KeyboardDismissalInstaller())
    }
}

private struct KeyboardDismissalInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> HostingView {
        let view = HostingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: HostingView, context: Context) {
        context.coordinator.installIfNeeded(from: uiView)
    }

    static func dismantleUIView(_ uiView: HostingView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class HostingView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.installIfNeeded(from: self)
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            nil
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private weak var recognizer: UITapGestureRecognizer?

        func installIfNeeded(from view: UIView) {
            guard let window = view.window, installedWindow !== window else {
                return
            }

            uninstall()

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            installedWindow = window
            self.recognizer = recognizer
        }

        func uninstall() {
            if let recognizer, let installedWindow {
                installedWindow.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            installedWindow = nil
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else {
                return
            }
            UIApplication.shared.dismissKeyboard()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let touchedView = touch.view else {
                return true
            }
            return !touchedView.hasTextInputAncestor
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private extension UIView {
    var hasTextInputAncestor: Bool {
        var view: UIView? = self
        while let currentView = view {
            if currentView is UITextField || currentView is UITextView {
                return true
            }
            view = currentView.superview
        }
        return false
    }
}
