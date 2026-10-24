import AppKit
import SwiftUI
import Combine

// MARK: - Click-Through Hosting View

class ClickThroughHostingView<T: View>: NSHostingView<T> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        if result === self { return nil }
        return result
    }
}

// MARK: - Island Window Controller

class IslandWindowController: NSWindowController {
    private var cancellable: AnyCancellable?
    private var globalClickMonitor: Any?
    private let screenOffset: CGFloat = 70

    convenience init() {
        guard let screen = NSScreen.main else {
            self.init(window: nil)
            return
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY

        let compactWidth: CGFloat = 108
        let compactHeight: CGFloat = menuBarHeight

        let xPos = screenFrame.midX - compactWidth / 2 + 70
        let yPos = screenFrame.maxY - compactHeight

        let contentRect = NSRect(x: xPos, y: yPos, width: compactWidth, height: compactHeight)

        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        let hostingView = ClickThroughHostingView(rootView: IslandContainerView(menuBarHeight: menuBarHeight))
        panel.contentView = hostingView

        self.init(window: panel)

        cancellable = IslandState.shared.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                self?.updateWindowFrame(expanded: expanded)
                self?.updateGlobalClickMonitor(expanded: expanded)
            }
    }

    private func updateWindowFrame(expanded: Bool) {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY

        if expanded {
            let w: CGFloat = 580
            let h: CGFloat = 520
            let x = screenFrame.midX - w / 2 + screenOffset
            let y = screenFrame.maxY - h
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        } else {
            let w: CGFloat = 108
            let h: CGFloat = menuBarHeight
            let x = screenFrame.midX - w / 2 + screenOffset
            let y = screenFrame.maxY - h
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }
    }

    private func updateGlobalClickMonitor(expanded: Bool) {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }

        if expanded {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        IslandState.shared.isExpanded = false
                    }
                }
            }
        }
    }

    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Island Container View

struct IslandContainerView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var voice = VoiceAssistant.shared
    @State private var isHovering = false
    @State private var hoverScale: CGFloat = 1.0

    var menuBarHeight: CGFloat = 25

    private var compactHeight: CGFloat { menuBarHeight - 4 }
    private var compactWidth: CGFloat { 108 }
    private var expandedWidth: CGFloat { 560 }

    var body: some View {
        ZStack(alignment: .top) {
            if state.isExpanded {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.04), Color.clear],
                            center: .top,
                            startRadius: 0,
                            endRadius: 280
                        )
                    )
                    .blur(radius: 30)
                    .frame(width: expandedWidth + 40, height: 520)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if state.isExpanded {
                expandedView
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(white: 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(isHovering ? 0.15 : 0.06),
                                                Color.white.opacity(0.02),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.7), radius: 30, y: 10)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                    .scaleEffect(hoverScale)
                    .onHover { hovering in
                        isHovering = hovering
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            hoverScale = hovering ? 1.003 : 1.0
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).animation(.spring(response: 0.5, dampingFraction: 0.76).delay(0.05)),
                        removal: .opacity.animation(.easeOut(duration: 0.15))
                    ))
            } else {
                compactBar
                    .background(
                        RoundedRectangle(cornerRadius: compactHeight / 2)
                            .fill(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: compactHeight / 2)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(isHovering ? 0.15 : 0.06),
                                                Color.white.opacity(0.02),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 5, y: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: compactHeight / 2))
                    .contentShape(RoundedRectangle(cornerRadius: compactHeight / 2))
                    .scaleEffect(hoverScale)
                    .onTapGesture {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.74, blendDuration: 0)) {
                            state.toggleExpand()
                        }
                    }
                    .onHover { hovering in
                        isHovering = hovering
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            hoverScale = hovering ? 1.03 : 1.0
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.spring(response: 0.3, dampingFraction: 0.85)),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, max(2, (menuBarHeight - compactHeight) / 2))
        .onReceive(voice.$isListening) { listening in
            if listening && !state.isExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    state.isExpanded = true
                }
            }
        }
    }

    // MARK: - Compact Bar

    var compactBar: some View {
        HStack(spacing: 4) {
            if voice.isListening {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .modifier(PulseModifier())
            }

            Text(voice.isListening ? "Dinliyor" : "Taha Ogul")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .tracking(0.3)
        }
        .padding(.horizontal, 8)
        .frame(width: compactWidth, height: compactHeight)
    }

    // MARK: - Expanded View

    var expandedView: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Taha Ogul")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(0.5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.toggleExpand()
                        }
                    }

                Spacer()

                Button(action: { voice.toggleListening() }) {
                    Image(systemName: voice.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(voice.isListening ? .red : .white.opacity(0.3))
                        .frame(width: 26, height: 26)
                        .background(voice.isListening ? Color.red.opacity(0.15) : Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 5) {
                    if let icon = monitor.activeAppIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text(monitor.activeAppName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.07), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            if voice.isListening || voice.isProcessing || !voice.response.isEmpty {
                VoiceView()
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        SystemWidget()
                        BatteryWidget()
                    }

                    HStack(spacing: 8) {
                        NetworkWidget()
                        DiskWidget()
                    }

                    HStack(spacing: 8) {
                        SystemDetailWidget()
                        ControlWidget()
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(width: expandedWidth)
    }
}
