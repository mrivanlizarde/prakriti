import AppKit
import Foundation
import Observation

/// Swaps the menu bar's two working frames every 0.7 s, only while work runs, and never with Reduce
/// Motion on (docs/v2/icons/README.md, "The working animation").
///
/// Why it lives on the model: a `TimelineView` inside a `MenuBarExtra` label draws once and never
/// ticks (measured 10 Oct 2026 on macOS 27.2: one render in five seconds), while a change to an
/// `@Observable` value redraws the label (eight renders in five seconds). So the label reads `frame`
/// and this class flips it. The timer exists only while the menu bar shows the working state, so
/// Prakriti never wakes twice a second for nothing.
@MainActor
@Observable
final class WorkingTicker {
    /// How long each frame shows.
    static let interval: TimeInterval = 0.7

    /// False shows the first working frame, true the second.
    private(set) var odd = false

    /// The repeating timer. Nil whenever nothing is working or Reduce Motion is on; tests read it.
    @ObservationIgnored private(set) var timer: (any TickerTimer)?

    @ObservationIgnored private let clock: any TickerClock
    @ObservationIgnored private let reduceMotion: @MainActor () -> Bool
    @ObservationIgnored private var isWorking = false
    @ObservationIgnored private var reduceMotionObserver: ObserverToken?

    /// - Parameters:
    ///   - clock: schedules the tick; tests pass a clock they move by hand.
    ///   - reduceMotion: whether Reduce Motion is on (System Settings, Accessibility, Display).
    ///   - reduceMotionChanges: where macOS says the accessibility display options changed, so
    ///     turning Reduce Motion on stops the animation at once and turning it off starts it again.
    init(clock: any TickerClock = SystemTickerClock(),
         reduceMotion: @escaping @MainActor () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
         reduceMotionChanges: NotificationCenter? = NSWorkspace.shared.notificationCenter) {
        self.clock = clock
        self.reduceMotion = reduceMotion
        if let center = reduceMotionChanges {
            let token = center.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                           object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            reduceMotionObserver = ObserverToken(center: center, token: token)
        }
    }

    /// The working frame the menu bar should draw now. With Reduce Motion on it is always the first.
    var frame: String { StatusSummary.Icon.workingFrames[odd ? 1 : 0] }

    /// Called whenever the menu bar's state changes: true while it shows the working state.
    func setWorking(_ working: Bool) {
        guard working != isWorking else { return }
        isWorking = working
        refresh()
    }

    /// Starts or stops the timer to match the work and the Reduce Motion setting.
    func refresh() {
        if isWorking && !reduceMotion() {
            guard timer == nil else { return }
            timer = clock.every(Self.interval) { [weak self] in self?.odd.toggle() }
        } else {
            timer?.cancel()
            timer = nil
            odd = false
        }
    }
}

/// A repeating timer the ticker can stop.
@MainActor
protocol TickerTimer: AnyObject {
    func cancel()
}

/// Schedules the ticker's repeating tick on the main thread.
@MainActor
protocol TickerClock {
    func every(_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Void) -> any TickerTimer
}

/// The app's clock: a Foundation timer on the main run loop, in the common modes so the frames keep
/// turning while the menu is open, with 10% tolerance so macOS may group the wake-ups.
@MainActor
struct SystemTickerClock: TickerClock {
    func every(_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Void) -> any TickerTimer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        timer.tolerance = interval / 10
        RunLoop.main.add(timer, forMode: .common)
        return FoundationTickerTimer(timer: timer)
    }
}

@MainActor
private final class FoundationTickerTimer: TickerTimer {
    private let timer: Timer
    init(timer: Timer) { self.timer = timer }
    func cancel() { timer.invalidate() }
}

/// Removes a block observer when the ticker that owns it goes away.
private final class ObserverToken: @unchecked Sendable {
    private let center: NotificationCenter
    private let token: any NSObjectProtocol
    init(center: NotificationCenter, token: any NSObjectProtocol) {
        self.center = center
        self.token = token
    }
    deinit { center.removeObserver(token) }
}
