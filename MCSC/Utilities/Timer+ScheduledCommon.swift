import Foundation

extension Timer {
    // Common run-loop modes keep detection active while Mission Control tracks input.
    static func scheduledCommon(
        interval: TimeInterval,
        repeats: Bool,
        tolerance: TimeInterval,
        block: @escaping (Timer) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: block)
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
