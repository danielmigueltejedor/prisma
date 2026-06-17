import SwiftUI
import UIKit

/// Detecta cuando el usuario pulsa de nuevo la pestaña ya activa (p. ej. Para ti).
struct TabBarReTapDetector: UIViewControllerRepresentable {
  let selectedIndex: Int
  let onReTap: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(selectedIndex: selectedIndex, onReTap: onReTap)
  }

  func makeUIViewController(context: Context) -> Controller {
    let controller = Controller()
    controller.coordinator = context.coordinator
    return controller
  }

  func updateUIViewController(_ uiViewController: Controller, context: Context) {
    context.coordinator.selectedIndex = selectedIndex
    context.coordinator.onReTap = onReTap
    uiViewController.installIfNeeded()
  }

  final class Controller: UIViewController {
    weak var coordinator: Coordinator?

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      installIfNeeded()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
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
    var selectedIndex: Int
    var onReTap: () -> Void
    weak var forwardingDelegate: UITabBarControllerDelegate?

    init(selectedIndex: Int, onReTap: @escaping () -> Void) {
      self.selectedIndex = selectedIndex
      self.onReTap = onReTap
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
      let targetIndex = tabBarController.viewControllers?.firstIndex(of: viewController) ?? -1
      if tabBarController.selectedIndex == selectedIndex, targetIndex == selectedIndex {
        onReTap()
      }
      return forwardingDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
    }
  }
}
