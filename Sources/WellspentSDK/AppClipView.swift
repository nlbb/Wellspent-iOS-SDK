import LinkPresentation
import SwiftUI

@available(iOS 15.0, *)
internal struct AppClipView: View {

    @Environment(\.dismiss) var dismiss
    var url: URL

    @State
    private var metadata: LPLinkMetadata?

    var body: some View {
        VStack {
            if let metadata {
                LinkView(metadata: metadata)
                    .overlay(alignment: .topTrailing) {
                        Button(action: {
                            dismiss()
                        }, label: {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .rotationEffect(.degrees(45), anchor: .center)
                                .padding()
                                .tint(.gray)
                                .foregroundStyle(.white)
                        })
                    }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .task(priority: .high) {
             metadata = try? await LPMetadataProvider().startFetchingMetadata(for: url)
        }
    }
}

private struct LinkView: UIViewRepresentable {
    var metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        LPLinkView()
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}



private final class WSPresentationController: UIPresentationController {
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }

        let size = CGSize(
            width: containerView.bounds.width * 0.9,
            height: containerView.bounds.height * 0.5
        )
        let origin = CGPoint(
            x: (containerView.bounds.width - size.width) / 2,
            y: containerView.bounds.height - size.height
        )
        return CGRect(origin: origin, size: size)
    }

    override func presentationTransitionWillBegin() {
           super.presentationTransitionWillBegin()
           guard let containerView = containerView else { return }

           let dimmingView = UIView(frame: containerView.bounds)
           dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
           dimmingView.alpha = 0.0
           containerView.addSubview(dimmingView)
           dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissController)))

           presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
               dimmingView.alpha = 1.0
           }, completion: nil)
       }

    @objc private func dismissController() {
           presentedViewController.dismiss(animated: true, completion: nil)
       }
}

internal final class WSTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        return WSPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

extension UIApplication {
    func topViewController(base: UIViewController? = UIApplication.shared.windows.first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
