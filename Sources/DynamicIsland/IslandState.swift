import AppKit
import Foundation
import Combine

// MARK: - Island State

class IslandState: ObservableObject {
    static let shared = IslandState()

    @Published var isExpanded: Bool = false

    // Timer
    @Published var timerActive: Bool = false
    @Published var timerRemaining: Int = 0
    @Published var timerTotal: Int = 0
    private var timerCancellable: AnyCancellable?

    private init() {}

    // MARK: - Timer

    func startTimer(seconds: Int) {
        stopTimer()
        timerTotal = seconds
        timerRemaining = seconds
        timerActive = true

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.timerRemaining > 0 {
                    self.timerRemaining -= 1
                } else {
                    self.timerFinished()
                }
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        timerActive = false
    }

    private func timerFinished() {
        timerCancellable?.cancel()
        timerCancellable = nil
        NSSound(named: "Glass")?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.timerActive = false
        }
    }

    var timerProgress: CGFloat {
        guard timerTotal > 0 else { return 0 }
        return CGFloat(timerRemaining) / CGFloat(timerTotal)
    }

    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Toggle Expand

    func toggleExpand() {
        isExpanded.toggle()
    }
}
