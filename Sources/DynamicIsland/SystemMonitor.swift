import Foundation
import AppKit
import IOKit.ps
import CoreAudio
import CoreWLAN

// MARK: - System Monitor

class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    // CPU
    @Published var cpuUsage: Double = 0
    private var previousCPUInfo: [Int32] = []

    // RAM
    @Published var memoryUsed: Double = 0
    @Published var memoryTotal: Double = 0
    @Published var memoryPercent: Double = 0
    @Published var memoryActive: Double = 0
    @Published var memoryWired: Double = 0
    @Published var memoryCompressed: Double = 0

    // Disk
    @Published var diskUsed: Double = 0
    @Published var diskTotal: Double = 0
    @Published var diskPercent: Double = 0

    // Network
    @Published var downloadSpeed: Double = 0
    @Published var uploadSpeed: Double = 0
    @Published var totalDownloaded: UInt64 = 0
    @Published var totalUploaded: UInt64 = 0
    private var previousDownload: UInt64 = 0
    private var previousUpload: UInt64 = 0
    private var sessionStartDownload: UInt64 = 0
    private var sessionStartUpload: UInt64 = 0
    private var lastNetworkCheck: Date = Date()

    // Battery
    @Published var batteryLevel: Int = 0
    @Published var isCharging: Bool = false
    @Published var batteryTimeRemaining: Int = -1

    // Uptime
    @Published var uptimeString: String = ""

    // Active App
    @Published var activeAppName: String = ""
    @Published var activeAppIcon: NSImage? = nil

    // WiFi
    @Published var wifiSSID: String = ""
    @Published var wifiRSSI: Int = 0

    // System Info
    @Published var processCount: Int = 0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var loadAverage: [Double] = [0, 0, 0]
    @Published var localIP: String = ""
    @Published var swapUsed: Double = 0 // GB

    // Static info
    let hostname: String = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    let macOSVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    let cpuCoreCount: Int = ProcessInfo.processInfo.activeProcessorCount

    private var timer: Timer?
    private var fastTimer: Timer?

    private init() {
        memoryTotal = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        updateAll()
        let initial = getNetworkBytes()
        previousDownload = initial.download
        previousUpload = initial.upload
        sessionStartDownload = initial.download
        sessionStartUpload = initial.upload

        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.updateAll()
        }

        fastTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateNetworkSpeed()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        updateActiveApp()
    }

    private func updateAll() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let cpu = self?.measureCPU() ?? 0
            let mem = self?.measureMemory() ?? (0, 0, 0, 0, 0)
            let disk = self?.measureDisk() ?? (0, 0)
            let battery = self?.measureBattery() ?? (0, false, -1)
            let uptime = self?.measureUptime() ?? ""
            let wifi = self?.measureWiFi() ?? ("", 0)
            let procCount = self?.measureProcessCount() ?? 0
            let thermal = ProcessInfo.processInfo.thermalState
            var loadavg = [Double](repeating: 0, count: 3)
            getloadavg(&loadavg, 3)
            let ip = self?.measureLocalIP() ?? ""
            let swap = self?.measureSwap() ?? 0

            DispatchQueue.main.async {
                self?.cpuUsage = cpu
                self?.memoryUsed = mem.0
                self?.memoryPercent = mem.1
                self?.memoryActive = mem.2
                self?.memoryWired = mem.3
                self?.memoryCompressed = mem.4
                self?.diskUsed = disk.0
                self?.diskTotal = disk.1
                if disk.1 > 0 { self?.diskPercent = disk.0 / disk.1 * 100 }
                self?.batteryLevel = battery.0
                self?.isCharging = battery.1
                self?.batteryTimeRemaining = battery.2
                self?.uptimeString = uptime
                self?.wifiSSID = wifi.0
                self?.wifiRSSI = wifi.1
                self?.processCount = procCount
                self?.thermalState = thermal
                self?.loadAverage = loadavg
                self?.localIP = ip
                self?.swapUsed = swap
            }
        }
    }

    // MARK: - CPU

    private func measureCPU() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0 }

        var currentInfo: [Int32] = []
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            currentInfo.append(info[offset + Int(CPU_STATE_USER)])
            currentInfo.append(info[offset + Int(CPU_STATE_SYSTEM)])
            currentInfo.append(info[offset + Int(CPU_STATE_IDLE)])
            currentInfo.append(info[offset + Int(CPU_STATE_NICE)])
        }

        var usage: Double = 0

        if !previousCPUInfo.isEmpty && previousCPUInfo.count == currentInfo.count {
            var totalDelta: Double = 0
            var usedDelta: Double = 0
            let step = 4
            var idx = 0
            while idx < currentInfo.count - 3 {
                let userD = Double(currentInfo[idx] - previousCPUInfo[idx])
                let sysD = Double(currentInfo[idx+1] - previousCPUInfo[idx+1])
                let idleD = Double(currentInfo[idx+2] - previousCPUInfo[idx+2])
                let niceD = Double(currentInfo[idx+3] - previousCPUInfo[idx+3])
                totalDelta += userD + sysD + idleD + niceD
                usedDelta += userD + sysD + niceD
                idx += step
            }
            if totalDelta > 0 { usage = (usedDelta / totalDelta) * 100 }
        }

        previousCPUInfo = currentInfo
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size))
        return usage
    }

    // MARK: - Memory (detaylı)

    private func measureMemory() -> (Double, Double, Double, Double, Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 0, 0, 0, 0) }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize / (1024 * 1024 * 1024)
        let wired = Double(stats.wire_count) * pageSize / (1024 * 1024 * 1024)
        let compressed = Double(stats.compressor_page_count) * pageSize / (1024 * 1024 * 1024)
        let usedGB = active + wired + compressed
        let percent = usedGB / memoryTotal * 100

        return (usedGB, percent, active, wired, compressed)
    }

    // MARK: - Disk

    private func measureDisk() -> (Double, Double) {
        let fileURL = URL(fileURLWithPath: "/")
        guard let values = try? fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) else {
            return (0, 0)
        }
        let total = Double(values.volumeTotalCapacity ?? 0) / (1024 * 1024 * 1024)
        let available = Double(values.volumeAvailableCapacityForImportantUsage ?? 0) / (1024 * 1024 * 1024)
        return (total - available, total)
    }

    // MARK: - Network

    private func getNetworkBytes() -> (download: UInt64, upload: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var totalDown: UInt64 = 0
        var totalUp: UInt64 = 0
        var ptr = firstAddr
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            if name.hasPrefix("en") || name.hasPrefix("lo") {
                if let data = ptr.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self)
                    totalDown += UInt64(networkData.pointee.ifi_ibytes)
                    totalUp += UInt64(networkData.pointee.ifi_obytes)
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return (totalDown, totalUp)
    }

    private func updateNetworkSpeed() {
        let now = Date()
        let interval = now.timeIntervalSince(lastNetworkCheck)
        guard interval > 0 else { return }

        let current = getNetworkBytes()
        if previousDownload > 0 {
            let downDelta = current.download > previousDownload ? current.download - previousDownload : 0
            let upDelta = current.upload > previousUpload ? current.upload - previousUpload : 0
            DispatchQueue.main.async { [weak self] in
                self?.downloadSpeed = Double(downDelta) / interval
                self?.uploadSpeed = Double(upDelta) / interval
                if let sd = self?.sessionStartDownload, let su = self?.sessionStartUpload {
                    self?.totalDownloaded = current.download > sd ? current.download - sd : 0
                    self?.totalUploaded = current.upload > su ? current.upload - su : 0
                }
            }
        }
        previousDownload = current.download
        previousUpload = current.upload
        lastNetworkCheck = now
    }

    // MARK: - Battery

    private func measureBattery() -> (Int, Bool, Int) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        var level = 0; var charging = false; var timeRemaining = -1
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] else { continue }
            if let cap = desc[kIOPSCurrentCapacityKey] as? Int { level = cap }
            if let state = desc[kIOPSPowerSourceStateKey] as? String { charging = state == kIOPSACPowerValue }
            if let time = desc[kIOPSTimeToEmptyKey] as? Int, time > 0 { timeRemaining = time }
        }
        return (level, charging, timeRemaining)
    }

    // MARK: - WiFi

    private func measureWiFi() -> (String, Int) {
        guard let iface = CWWiFiClient.shared().interface() else { return ("", 0) }
        return (iface.ssid() ?? "", iface.rssiValue())
    }

    // MARK: - Process Count

    private func measureProcessCount() -> Int {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: size_t = 0
        sysctl(&mib, 4, nil, &size, nil, 0)
        return size / MemoryLayout<kinfo_proc>.size
    }

    // MARK: - Local IP

    private func measureLocalIP() -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return "–" }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let addrFamily = ptr.pointee.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: ptr.pointee.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(ptr.pointee.ifa_addr, socklen_t(ptr.pointee.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    return String(cString: hostname)
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return "–"
    }

    // MARK: - Swap

    private func measureSwap() -> Double {
        var vmStat = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &vmStat, &size, nil, 0)
        return Double(vmStat.xsu_used) / (1024 * 1024 * 1024)
    }

    // MARK: - Uptime

    private func measureUptime() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            return "\(days)g \(hours % 24)s \(minutes)d"
        }
        return "\(hours)s \(minutes)d"
    }

    // MARK: - Active App

    @objc private func activeAppChanged(_ notification: Notification) {
        updateActiveApp()
    }

    private func updateActiveApp() {
        DispatchQueue.main.async { [weak self] in
            guard let app = NSWorkspace.shared.frontmostApplication else { return }
            self?.activeAppName = app.localizedName ?? ""
            self?.activeAppIcon = app.icon
        }
    }

    // MARK: - Helpers

    var thermalStateText: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Ilımlı"
        case .serious: return "Yüksek"
        case .critical: return "Kritik"
        @unknown default: return "?"
        }
    }

    var wifiSignalBars: Int {
        if wifiRSSI > -50 { return 4 }
        if wifiRSSI > -60 { return 3 }
        if wifiRSSI > -70 { return 2 }
        if wifiRSSI > -80 { return 1 }
        return 0
    }

    static func formatBytes(_ bytes: Double) -> String {
        if bytes < 1024 { return "0 B" }
        if bytes < 1024 * 1024 { return String(format: "%.0f KB", bytes / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", bytes / (1024 * 1024)) }
        return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
    }

    static func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 { return "0" }
        if bytesPerSec < 1024 * 1024 { return String(format: "%.0f KB/s", bytesPerSec / 1024) }
        return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
    }

    static func formatTraffic(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1024 * 1024 { return String(format: "%.0f KB", b / 1024) }
        if b < 1024 * 1024 * 1024 { return String(format: "%.1f MB", b / (1024 * 1024)) }
        return String(format: "%.2f GB", b / (1024 * 1024 * 1024))
    }
}
