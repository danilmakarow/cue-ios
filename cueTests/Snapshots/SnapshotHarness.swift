//
//  SnapshotHarness.swift
//  cueTests
//
//  Vendored, dependency-free snapshot helper. Renders a SwiftUI view hosted in a
//  device-sized UIWindow and writes a PNG into the test process's Documents
//  directory (which lives on the host disk under the simulator's container), so
//  the rendered screen can be pulled out and diffed against the design reference
//  offline. Chosen over Point-Free's swift-snapshot-testing to avoid a new
//  dependency; if we later need perceptual diffing we can revisit.
//

import SwiftUI
import Testing
import UIKit

/// Renders SwiftUI views to PNGs for design-fidelity (Storybook-style) snapshot
/// tests. All work is on the main actor — UIKit hosting requires it.
@MainActor
enum SnapshotHarness {
    /// iPhone 17 Pro logical points — matches the 393×852 design frames.
    static let deviceSize = CGSize(width: 393, height: 852)

    /// Renders `view` at `size` (Retina @3x) and returns PNG data, or nil on
    /// failure. The view is hosted in a real key window and a runloop tick is
    /// pumped so SwiftUI resolves layout, fonts, and images before capture.
    static func png<Content: View>(
        of view: Content,
        size: CGSize = deviceSize,
        scale: CGFloat = 3,
        settle: TimeInterval = 0.2
    ) -> Data? {
        let root = view
            .frame(width: size.width, height: size.height)
            .ignoresSafeArea()

        // Host + rasterize inside an explicit autorelease pool. The pool boundary
        // guarantees the `UIHostingController` (and, critically, the SwiftData
        // `@Query` observers it holds onto this test's `ModelContainer`) are
        // released the instant the pool drains — not deferred to some later
        // runloop turn. Without this teardown the window stays the process key
        // window and the orphaned `@Query` outlives the test; the NEXT test seeds
        // a fresh container and calls `context.save()`, whose process-wide
        // SwiftData change notification the stale `@Query` observes and re-fetches
        // against its now-foreign context, tripping an intermittent, test-ordering
        // trap inside SwiftData. Draining here keeps every capture isolated.
        let data: Data? = autoreleasepool {
            let host = UIHostingController(rootView: root)
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.backgroundColor = .clear

            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.layoutIfNeeded()

            // Let SwiftUI settle (async fonts/layout, and any in-flight `.task`
            // network reads stubbed in-process) before rasterizing. Screens that
            // kick off a cold load in `.task` and only render real content once
            // it resolves need a longer `settle` so the captured PNG is the
            // loaded state, not the spinner.
            RunLoop.current.run(until: Date().addingTimeInterval(settle))

            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { _ in
                host.view.drawHierarchy(
                    in: CGRect(origin: .zero, size: size),
                    afterScreenUpdates: true
                )
            }
            let pngData = image.pngData()

            // Detach + hide so nothing keeps the window as the key window once
            // the pool drains and releases `host`/`window`.
            host.view.removeFromSuperview()
            window.rootViewController = nil
            window.resignKey()
            window.isHidden = true
            window.windowScene = nil
            return pngData
        }

        // Pump the runloop so any deallocation + SwiftData observer removal that
        // the pool drain scheduled completes before the next test seeds + saves.
        // SwiftUI tears the hosting controller's `@Query` observers down over a
        // couple of runloop turns; a too-short drain can leave a stale observer
        // bound to *this* test's container alive into the next test, where its
        // `context.save()` posts a process-wide SwiftData notification that the
        // orphaned `@Query` re-fetches against a foreign context and traps.
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        return data
    }

    /// Renders `view` and attaches the PNG to the current test's result bundle as
    /// `<name>.png`, so it can be extracted on the host with
    /// `xcrun xcresulttool export attachments --path <bundle> --output-path <dir>`.
    /// Returns the PNG data (nil only on render failure) so callers can
    /// `#expect(record(...) != nil)`.
    @discardableResult
    static func record<Content: View>(
        _ view: Content,
        named name: String,
        size: CGSize = deviceSize,
        settle: TimeInterval = 0.2
    ) -> Data? {
        guard let data = png(of: view, size: size, settle: settle) else {
            Issue.record("Snapshot render failed for \(name)")
            return nil
        }
        Attachment.record(Attachment(data, named: "\(name).png"))
        return data
    }
}
