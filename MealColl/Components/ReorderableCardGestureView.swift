import SwiftUI
import UIKit

public struct ReorderableCardGestureView: UIViewRepresentable {
    public let isEnabled: Bool
    public var minimumPressDuration: Double = 0.16
    public let onLongPressBegan: (CGPoint) -> Void
    public var onLongPressBeganWithScrollView: ((CGPoint, UIScrollView?) -> Void)? = nil
    public let onDragChanged: (CGPoint, CGSize) -> Void
    public let onDragEnded: () -> Void
    public let onDragCancelled: () -> Void
    
    public init(
        isEnabled: Bool,
        minimumPressDuration: Double = 0.16,
        onLongPressBegan: @escaping (CGPoint) -> Void,
        onLongPressBeganWithScrollView: ((CGPoint, UIScrollView?) -> Void)? = nil,
        onDragChanged: @escaping (CGPoint, CGSize) -> Void,
        onDragEnded: @escaping () -> Void,
        onDragCancelled: @escaping () -> Void
    ) {
        self.isEnabled = isEnabled
        self.minimumPressDuration = minimumPressDuration
        self.onLongPressBegan = onLongPressBegan
        self.onLongPressBeganWithScrollView = onLongPressBeganWithScrollView
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onDragCancelled = onDragCancelled
    }
    
    public func makeUIView(context: Context) -> ReorderGestureHandlingView {
        let view = ReorderGestureHandlingView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = isEnabled
        
        let recognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleGesture(_:)))
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.allowableMovement = 12
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        context.coordinator.recognizer = recognizer
        return view
    }
    
    public func updateUIView(_ uiView: ReorderGestureHandlingView, context: Context) {
        uiView.isUserInteractionEnabled = isEnabled
        context.coordinator.parent = self
        context.coordinator.recognizer?.isEnabled = isEnabled
        context.coordinator.recognizer?.minimumPressDuration = minimumPressDuration
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: ReorderableCardGestureView
        weak var recognizer: UILongPressGestureRecognizer?
        private var initialTouchLocation: CGPoint = .zero
        private var hasDetachedInitialScrollPanTouch: Bool = false
        
        init(parent: ReorderableCardGestureView) {
            self.parent = parent
        }
        
        private func ancestorScrollViews(from view: UIView?) -> [UIScrollView] {
            var result: [UIScrollView] = []
            var current = view?.superview
            while let curr = current {
                if let sv = curr as? UIScrollView {
                    result.append(sv)
                }
                current = curr.superview
            }
            return result
        }
        
        private func nearestVerticalScrollView(from view: UIView?) -> UIScrollView? {
            for sv in ancestorScrollViews(from: view) {
                let name = String(describing: type(of: sv))
                if !name.contains("Paging") && !name.contains("Queuing") && sv.contentSize.height >= sv.bounds.height * 0.5 {
                    return sv
                }
            }
            return ancestorScrollViews(from: view).first
        }
        
        private func detachCurrentTouchFromScrollViews(from view: UIView?) {
            for sv in ancestorScrollViews(from: view) {
                let lockedOffset = sv.contentOffset
                // Toggling panGestureRecognizer.isEnabled drops the current single-finger touch
                // from UIScrollView's pan recognizer so moving Finger 1 never scrolls the screen,
                // while leaving it enabled for a future 2nd finger touch.
                sv.panGestureRecognizer.isEnabled = false
                sv.panGestureRecognizer.isEnabled = true
                sv.setContentOffset(lockedOffset, animated: false)
            }
            hasDetachedInitialScrollPanTouch = true
        }
        
        public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.isEnabled else { return false }
            // If the user has already started actively scrolling the ScrollView beyond the threshold,
            // do not start dragging a card.
            for sv in ancestorScrollViews(from: gestureRecognizer.view) {
                if sv.panGestureRecognizer.state == .began || sv.panGestureRecognizer.state == .changed {
                    let translation = sv.panGestureRecognizer.translation(in: sv)
                    if hypot(translation.x, translation.y) > 10 {
                        return false
                    }
                }
            }
            // We are beginning a card drag! Immediately detach Finger 1 from all ancestor ScrollViews
            // so single-finger dragging NEVER pans the background ScrollView.
            detachCurrentTouchFromScrollViews(from: gestureRecognizer.view)
            return true
        }
        
        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard otherGestureRecognizer.view is UIScrollView else {
                return false
            }
            // Before the long-press begins (.possible), allow UIScrollView.panGestureRecognizer
            // to track the touch so normal 1-finger scrolling starts immediately if the user swipes.
            if gestureRecognizer.state == .possible {
                return true
            }
            // Once the card drag has begun (.began / .changed), Finger 1 was already detached
            // from UIScrollView.panGestureRecognizer, so simultaneous recognition only occurs
            // if a second finger (Finger 2) touches down to scroll.
            return hasDetachedInitialScrollPanTouch
        }
        
        @objc func handleGesture(_ gesture: UILongPressGestureRecognizer) {
            guard parent.isEnabled else { return }
            let windowLocation = gesture.location(in: nil)
            
            switch gesture.state {
            case .began:
                initialTouchLocation = windowLocation
                gesture.cancelsTouchesInView = false
                if !hasDetachedInitialScrollPanTouch {
                    detachCurrentTouchFromScrollViews(from: gesture.view)
                }
                let sv = nearestVerticalScrollView(from: gesture.view)
                parent.onLongPressBegan(windowLocation)
                parent.onLongPressBeganWithScrollView?(windowLocation, sv)
                
            case .changed:
                let translation = CGSize(
                    width: windowLocation.x - initialTouchLocation.x,
                    height: windowLocation.y - initialTouchLocation.y
                )
                parent.onDragChanged(windowLocation, translation)
                
            case .ended:
                hasDetachedInitialScrollPanTouch = false
                gesture.cancelsTouchesInView = false
                parent.onDragEnded()
                
            case .cancelled, .failed:
                hasDetachedInitialScrollPanTouch = false
                gesture.cancelsTouchesInView = false
                parent.onDragCancelled()
                
            default:
                break
            }
        }
    }
}

public class ReorderGestureHandlingView: UIView {
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Leave top-right region (delete badge button) free to receive taps directly
        if point.x >= (bounds.width - 55) && point.y <= 55 {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

