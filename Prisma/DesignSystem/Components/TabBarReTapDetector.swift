import SwiftUI
import UIKit

/// Detecta cuando el usuario pulsa de nuevo una pestaña ya activa.
/// Debe haber una sola instancia (p. ej. en `MainTabView`) para no pisar `UITabBarController.delegate`.
struct TabBarReTapDetector: UIViewControllerRepresentable {
  let onReTap: (Int) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onReTap: onReTap)
  }

  func makeUIViewController(context: Context) -> Controller {
    let controller = Controller()
    controller.coordinator = context.coordinator
    return controller
  }

  func updateUIViewController(_ uiViewController: Controller, context: Context) {
    context.coordinator.onReTap = onReTap
    uiViewController.installIfNeeded()
  }

  final class Controller: UIViewController {
    weak var coordinator: Coordinator?

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      installIfNeeded()
    }

    func installIfNeeded() {
      guard let coordinator, let tabBar = tabBarController else { return }
      if tabBar.delegate !== coordinator {
        coordinator.forwardingDelegate = tabBar.delegate
        tabBar.delegate = coordinator
      }
    }
  }

  final class Coordinator: NSObject, UITabBarControllerDelegate {
    var onReTap: (Int) -> Void
    weak var forwardingDelegate: UITabBarControllerDelegate?

    init(onReTap: @escaping (Int) -> Void) {
      self.onReTap = onReTap
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
      let targetIndex = tabBarController.viewControllers?.firstIndex(of: viewController) ?? -1
      if targetIndex >= 0, tabBarController.selectedIndex == targetIndex {
        onReTap(targetIndex)
      }
      return forwardingDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
    }
  }
}
