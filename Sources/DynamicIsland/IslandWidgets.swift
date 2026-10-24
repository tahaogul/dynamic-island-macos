import SwiftUI

// MARK: - Widget Card Container

struct WidgetCard<Content: View>: View {
    var accentColor: Color = .white
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.1), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            content()
                .padding(12)
        }
    }
}

// MARK: - Widget Header

struct WidgetHeader: View {
    var icon: String
    var title: String
    var color: Color
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )

            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.white.opacity(0.3))
                .tracking(1.2)

            Spacer()

            if let trailing { trailing }
        }
    }
}

// MARK: - CPU & RAM Widget (Detaylı)

struct SystemWidget: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        WidgetCard(accentColor: .cyan) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(icon: "cpu", title: "İŞLEMCİ & BELLEK", color: .cyan,
                    trailing: AnyView(
                        Text("\(monitor.cpuCoreCount) çekirdek")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.18))
                    ))

                HStack(spacing: 14) {
                    VStack(spacing: 4) {
                        MiniGauge(value: monitor.cpuUsage / 100, color: .cyan, size: 42)
                        Text("CPU")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.cyan.opacity(0.4))
                    }

                    VStack(spacing: 4) {
                        MiniGauge(value: monitor.memoryPercent / 100, color: .purple, size: 42)
                        Text("RAM")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.purple.opacity(0.4))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.0f%%", monitor.cpuUsage))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)

                        HStack(spacing: 3) {
                            Text(String(format: "%.1f", monitor.memoryUsed))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                            Text("/ \(Int(monitor.memoryTotal))GB")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.2))
                        }

                        // Bellek detayı
                        HStack(spacing: 6) {
                            MemLabel(text: "A", value: monitor.memoryActive, color: .green)
                            MemLabel(text: "W", value: monitor.memoryWired, color: .orange)
                            MemLabel(text: "C", value: monitor.memoryCompressed, color: .yellow)
                        }
                    }

                    Spacer()
                }
            }
        }
    }
}

struct MemLabel: View {
    var text: String
    var value: Double
    var color: Color

    var body: some View {
        HStack(spacing: 1) {
            Text(text)
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(color.opacity(0.5))
            Text(String(format: "%.1f", value))
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
        }
    }
}

// MARK: - Battery Widget

struct BatteryWidget: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        WidgetCard(accentColor: batteryColor) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(
                    icon: monitor.isCharging ? "bolt.fill" : "battery.100",
                    title: monitor.isCharging ? "ŞARJ EDİLİYOR" : "PİL",
                    color: batteryColor,
                    trailing: AnyView(
                        Group {
                            if monitor.batteryTimeRemaining > 0 && !monitor.isCharging {
                                Text("\(monitor.batteryTimeRemaining / 60)s \(monitor.batteryTimeRemaining % 60)d")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                        }
                    ))

                HStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(monitor.batteryLevel)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(batteryColor)
                        Text("%")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    Spacer()

                    BatteryBar(level: monitor.batteryLevel, isCharging: monitor.isCharging, color: batteryColor)
                }
            }
        }
    }

    var batteryColor: Color {
        if monitor.isCharging { return .green }
        if monitor.batteryLevel > 50 { return .green }
        if monitor.batteryLevel > 20 { return .yellow }
        return .red
    }
}

struct BatteryBar: View {
    var level: Int
    var isCharging: Bool
    var color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: 50, height: 22)

            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                .frame(width: max(4, 46 * CGFloat(level) / 100), height: 18)
                .padding(.leading, 2)

            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black.opacity(0.6))
                    .frame(width: 50, height: 22)
            }

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.2))
                .frame(width: 3, height: 10)
                .offset(x: 52)
        }
        .frame(width: 55, height: 22)
    }
}

// MARK: - Network Widget (WiFi dahil)

struct NetworkWidget: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        WidgetCard(accentColor: .blue) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(icon: "wifi", title: "AĞ", color: .blue,
                    trailing: AnyView(
                        HStack(spacing: 3) {
                            HStack(spacing: 1) {
                                ForEach(0..<4, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 0.5)
                                        .fill(i < monitor.wifiSignalBars ? Color.blue : Color.white.opacity(0.08))
                                        .frame(width: 2.5, height: CGFloat(4 + i * 2))
                                }
                            }
                            .frame(height: 12, alignment: .bottom)

                            if !monitor.wifiSSID.isEmpty {
                                Text(monitor.wifiSSID)
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.2))
                                    .lineLimit(1)
                                    .frame(maxWidth: 55, alignment: .trailing)
                            }
                        }
                    ))

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                            Text(SystemMonitor.formatSpeed(monitor.downloadSpeed))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text("↓ \(SystemMonitor.formatTraffic(monitor.totalDownloaded))")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.15))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                            Text(SystemMonitor.formatSpeed(monitor.uploadSpeed))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text("↑ \(SystemMonitor.formatTraffic(monitor.totalUploaded))")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.15))
                    }
                }

                // IP adresi
                if !monitor.localIP.isEmpty && monitor.localIP != "–" {
                    Text("IP: \(monitor.localIP)")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.15))
                }
            }
        }
    }
}

// MARK: - Disk Widget

struct DiskWidget: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        WidgetCard(accentColor: .orange) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(icon: "internaldrive", title: "DEPOLAMA", color: .orange)

                HStack(spacing: 12) {
                    MiniGauge(value: monitor.diskPercent / 100, color: .orange, size: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.0f GB", monitor.diskUsed))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)

                        Text(String(format: "/ %.0f GB", monitor.diskTotal))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.2))

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * monitor.diskPercent / 100, height: 4)
                            }
                        }
                        .frame(height: 4)

                        Text(String(format: "%.0f GB boş", monitor.diskTotal - monitor.diskUsed))
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.15))
                    }
                }
            }
        }
    }
}

// MARK: - Sistem Detay Widget

struct SystemDetailWidget: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        WidgetCard(accentColor: .teal) {
            VStack(alignment: .leading, spacing: 7) {
                WidgetHeader(icon: "desktopcomputer", title: "SİSTEM", color: .teal)

                // Hostname + macOS
                VStack(alignment: .leading, spacing: 4) {
                    InfoRow(label: "Cihaz", value: monitor.hostname, color: .white)
                    InfoRow(label: "macOS", value: shortMacOS, color: .white)
                    InfoRow(label: "Uptime", value: monitor.uptimeString, color: .teal)

                    // Termal + İşlem
                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 8))
                                .foregroundColor(thermalColor)
                            Text(monitor.thermalStateText)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(thermalColor)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.3))
                            Text("\(monitor.processCount) işlem")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }

                    // Swap + Load
                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Text("Swap")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.2))
                            Text(String(format: "%.1f GB", monitor.swapUsed))
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(monitor.swapUsed > 2 ? .orange : .white.opacity(0.4))
                        }

                        HStack(spacing: 3) {
                            Text("Load")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.2))
                            ForEach(0..<3, id: \.self) { i in
                                Text(String(format: "%.1f", monitor.loadAverage[i]))
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundColor(loadColor(monitor.loadAverage[i]))
                            }
                        }
                    }
                }
            }
        }
    }

    var shortMacOS: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    var thermalColor: Color {
        switch monitor.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }

    func loadColor(_ load: Double) -> Color {
        if load < 2 { return .green }
        if load < 4 { return .yellow }
        if load < 6 { return .orange }
        return .red
    }
}

struct InfoRow: View {
    var label: String
    var value: String
    var color: Color = .white

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white.opacity(0.2))
                .frame(width: 38, alignment: .leading)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color.opacity(0.6))
                .lineLimit(1)
        }
    }
}

// MARK: - Kontrol Paneli Widget

struct ControlWidget: View {
    @ObservedObject var state = IslandState.shared

    var body: some View {
        WidgetCard(accentColor: .indigo) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(icon: "slider.horizontal.3", title: "KONTROL", color: .indigo)

                if state.timerActive {
                    // Timer aktif — geri sayım + durdur
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.formatTime(state.timerRemaining))
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.06))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * state.timerProgress)
                                }
                            }
                            .frame(height: 3)
                        }

                        Spacer()

                        // Durdur butonu
                        Button(action: { state.stopTimer() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Timer butonları
                    VStack(spacing: 6) {
                        Text("Zamanlayıcı")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.2))

                        HStack(spacing: 6) {
                            TimerButton(label: "1dk", seconds: 60)
                            TimerButton(label: "5dk", seconds: 300)
                            TimerButton(label: "10dk", seconds: 600)
                            TimerButton(label: "25dk", seconds: 1500)
                        }
                    }
                }

                // Çıkış butonu
                HStack {
                    Spacer()
                    Button(action: { NSApp.terminate(nil) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.system(size: 8, weight: .bold))
                            Text("Çıkış")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundColor(.red.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TimerButton: View {
    var label: String
    var seconds: Int
    @ObservedObject var state = IslandState.shared

    var body: some View {
        Button(action: { state.startTimer(seconds: seconds) }) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mini Gauge

struct MiniGauge: View {
    var value: Double
    var color: Color
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: size * 0.1)

            Circle()
                .trim(from: 0, to: min(value, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.3), color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: 4)

            Text(String(format: "%.0f", value * 100))
                .font(.system(size: size * 0.25, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
    }
}

// MARK: - Voice View

struct VoiceView: View {
    @ObservedObject var voice = VoiceAssistant.shared
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                if voice.isListening {
                    Circle()
                        .stroke(Color.red.opacity(0.2), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseScale)
                        .opacity(Double(2.0 - pulseScale))

                    Circle()
                        .stroke(Color.red.opacity(0.1), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseScale * 1.15)
                        .opacity(Double(2.0 - pulseScale * 1.15))
                }

                Button(action: { voice.toggleListening() }) {
                    ZStack {
                        Circle()
                            .fill(voice.isListening ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                            .frame(width: 64, height: 64)

                        Image(systemName: voice.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(voice.isListening ? .red : .blue)
                    }
                }
                .buttonStyle(.plain)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    pulseScale = 1.5
                }
            }

            if voice.isListening {
                Text("Dinleniyor...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            if !voice.transcript.isEmpty {
                Text(voice.transcript)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            if voice.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.7)
                    Text("Dusunuyor...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            if !voice.response.isEmpty && !voice.isProcessing {
                VStack(spacing: 10) {
                    Text(voice.response)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(8)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(action: { voice.clearResponse() }) {
                        Text("Tamam")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Text("Option + Space ile her yerden aktive et")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.12))
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Pulse Modifier

struct PulseModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.2 : 0.85)
            .opacity(pulsing ? 1 : 0.6)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}
