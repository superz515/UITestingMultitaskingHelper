//
//  MultitaskingHelper.swift
//  UITestingMultitaskingHelper
//
//  Created by Zhang, Yiliang on 6/25/20.
//  Copyright © 2020 Zhang, Yiliang. All rights reserved.
//

import Foundation
import XCTest

// MARK: - split screen modes

/// Includes all supported split screen modes.
///
/// NOTE: These modes are summarized and named based on experience. If Apple adds more modes in the future, we need to enhance it.
enum SplitScreenMode: Int {
    /// Used as key to get/set associated object for XCUIApplication.
    static fileprivate var associatedKey = "splitScreenModeAssociatedKey"

    // modes available in landscape

    /// Our app takes more than half of the screen.
    case landscapeTwoThirds = 0

    /// Our app takes less than half of the screen.
    case landscapeOneThird = 1

    /// Our app takes half of the screen.
    case halfHalf = 2

    // modes available in portrait

    /// Our app takes more than half of the screen.
    case portraitMajor = 3

    /// Our app takes less than half of the screen.
    case portraitMinor = 4

    /// The proportion our app takes from the whole screen.
    ///
    /// NOTE: These values are calculated based on observed results. It's calculated as ("width of our app" / "total screen width").
    /// Even for the same mode, the actual proportion is slightly different on different devices. This proportion is used to calculate the distance we need to drag the grab handle.
    /// We don't need a very precise value as the grab handle will automatically snap to the nearest position, so I simplify it as this.
    /// If some value doesn't work properly, we need to further tweak it.
    var splitFactor: CGFloat {
        switch self {
        case .landscapeTwoThirds:
            return 0.72
        case .landscapeOneThird:
            return 0.28
        case .halfHalf:
            return 1/2
        case .portraitMajor:
            return 3/5
        case .portraitMinor:
            return 2/5
        }
    }

    /// Checks if we are allowed to switch from current screen mode to another.
    ///
    /// For now, we only allow to switch between modes in same orientation. Once rotated, iOS will automatically switch to another mode and fail some of our logic.
    /// But it should be easy to support it if you really need it.
    func isAllowedToSwitch(to another: SplitScreenMode) -> Bool {
        switch self {
        case .landscapeTwoThirds, .landscapeOneThird, .halfHalf:
            return another.rawValue <= 2
        case .portraitMajor, .portraitMinor:
            return another.rawValue > 2
        }
    }
}

// MARK: - XCUIApplication multitasking support

extension XCUIApplication {
    // MARK: - Here I use associated object to record current split screen mode as a global state.

    /// Indicates current split screen mode.
    ///
    /// A nil value is returned if the app is currently running with full screen.
    var splitScreenMode: SplitScreenMode? {
        get {
            return objc_getAssociatedObject(self, &SplitScreenMode.associatedKey) as? SplitScreenMode
        }
        set {
            objc_setAssociatedObject(self, &SplitScreenMode.associatedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Some convenient values we need to perform a drag.

    /// Normalized offset on bottom edge.
    ///
    /// Could be used to perform a swipe up from bottom edge.
    var bottomEdgeNormalizedOffset: CGVector {
        // In practice, I found 0.999 works better than 0.99 or 1 since we need to make the touch point as close as possible to the edge but still leave some tiny distance to it.
        return CGVector(dx: 0.5, dy: 0.999)
    }

    /// Normalized offset on right edge.
    ///
    /// Could be used as destination of app dragging.
    var rightEdgeNormalizedOffset: CGVector {
        return CGVector(dx: 0.999, dy: 0.5)
    }

    /// Normalized offset of initial touch point to drag other app from dock.
    var otherAppNormalizedOffset: CGVector {
        return CGVector(dx: 0.5, dy: 0.95)
    }

    // MARK: - public APIs

    /// Begins multitasking.
    func beginMultitasking() {
        guard isIPad() else {
            return
        }

        guard splitScreenMode == nil else {
            // already in multitasking
            return
        }

        // swipe from bottom edge to call out the dock
        callOutDock()

        // drag another app to right edge
        switchSplitScreenMode(to: .portraitMajor)
    }

    /// Ends multitasking.
    func endMultitasking() {
        guard isIPad() else {
            return
        }

        guard let current = splitScreenMode else {
            // nothing happens if currently not in split screen mode
            return
        }

        let windowWidth = windows.firstMatch.frame.width

        // drag from right edge (the grab handle) by a large distance to the right
        let dragBegin = windows.firstMatch.coordinate(withNormalizedOffset: rightEdgeNormalizedOffset)
        let dragEnd = dragBegin.withOffset(CGVector(dx: windowWidth / current.splitFactor - windowWidth, dy: 0))
        dragBegin.press(forDuration: edgeSwipePressDuration, thenDragTo: dragEnd)

        // clear current mode
        splitScreenMode = nil

        // sleep for a while until stable as there's animation
        sleep(2)
    }

    /// Switches current split screen mode to another.
    ///
    /// - Parameters:
    ///     - next: The target split screen mode. The passed-in value will be ignored if current `splitScreenMode` is nil,
    ///     since we can only activate specific mode initially.
    func switchSplitScreenMode(to next: SplitScreenMode) {
        guard isIPad() else {
            return
        }

        let targetMode: SplitScreenMode
        let dragBegin: XCUICoordinate
        let dragEnd: XCUICoordinate

        if let current = splitScreenMode {
            // switch from current split screen mode

            guard current.isAllowedToSwitch(to: next) else {
                // nothing happens if current switch is not allowed
                return
            }

            targetMode = next

            let windowWidth = windows.firstMatch.frame.width

            // drag from right edge (the grab handle) by certain distance to the left/right
            dragBegin = windows.firstMatch.coordinate(withNormalizedOffset: rightEdgeNormalizedOffset)
            dragEnd = dragBegin.withOffset(CGVector(dx: windowWidth * (next.splitFactor / current.splitFactor - 1), dy: 0))
        } else {
            // activate initial mode from full screen

            // target mode is determined based on current orientation
            targetMode = XCUIDevice.shared.orientation.isLandscape ? .halfHalf : .portraitMajor

            // drag from dock
            dragBegin = windows.firstMatch.coordinate(withNormalizedOffset: otherAppNormalizedOffset)

            // drag to right edge
            dragEnd = windows.firstMatch.coordinate(withNormalizedOffset: rightEdgeNormalizedOffset)
        }

        // drag
        dragBegin.press(forDuration: splitScreenMode == nil ? dragPressDuration : edgeSwipePressDuration, thenDragTo: dragEnd)

        // update current split screen mode
        splitScreenMode = targetMode

        // sleep for a while until stable as there's animation
        sleep(2)
    }
}

// MARK: - private helpers

extension XCUIApplication {
    /// Brings up the dock.
    private func callOutDock() {
        // swipe up a small distance from bottom center
        let bottomEdgeSwipeBegin = windows.firstMatch.coordinate(withNormalizedOffset: bottomEdgeNormalizedOffset)
        let bottomEdgeSwipeEnd = bottomEdgeSwipeBegin.withOffset(CGVector(dx: 0, dy: -edgeSwipeDistance))

        // press down for a small while then drag
        bottomEdgeSwipeBegin.press(forDuration: edgeSwipePressDuration, thenDragTo: bottomEdgeSwipeEnd)
    }

    /// Checks if current device is iPad.
    private func isIPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}

// MARK: - helper constants

/// Distance of edge swipe.
private let edgeSwipeDistance: CGFloat = 100

/// Duration of press down before edge swipe.
///
/// NOTE: This duration should be small otherwise the edge swipe gesture will fail to be recognized.
private let edgeSwipePressDuration: TimeInterval = 0.1

/// Duration of press down before dragging.
private let dragPressDuration: TimeInterval = 0.5
