import Foundation
import Speech
import AVFoundation
import AppKit

class VoiceAssistant: ObservableObject {
    static let shared = VoiceAssistant()

    @Published var isListening = false
    @Published var transcript = ""
    @Published var response = ""
    @Published var isProcessing = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()

    private var apiKey: String = ""
    private var silenceTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {
        loadAPIKey()
    }

    // MARK: - API Key

    private func loadAPIKey() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/dynamicisland/config.json").path

        if let data = FileManager.default.contents(atPath: configPath),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let key = config["claude_api_key"] as? String {
            apiKey = key
        }
    }

    // MARK: - Listening

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard !isListening else { return }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                if status == .authorized {
                    self.beginRecording()
                } else {
                    self.response = "Konusma tanima izni verilmedi. Sistem Ayarlari > Gizlilik'ten izin verin."
                }
            }
        }
    }

    private func beginRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil

        guard speechRecognizer?.isAvailable == true else {
            response = "Konusma tanima su an kullanilamiyor."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            response = "Mikrofon baslatilamadi: \(error.localizedDescription)"
            return
        }

        isListening = true
        transcript = ""
        response = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                }

                if result.isFinal {
                    self.finishRecording()
                }
            }

            if error != nil && self.isListening {
                self.finishRecording()
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self, self.isListening else { return }
            self.finishRecording()
        }
    }

    private func finishRecording() {
        stopListening()
        let text = transcript
        if !text.isEmpty {
            processCommand(text)
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async {
            self.isListening = false
        }
    }

    // MARK: - Claude API

    func processCommand(_ text: String) {
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.response = "API anahtari bulunamadi.\n~/.config/dynamicisland/config.json:\n{\"claude_api_key\": \"sk-ant-...\"}"
            }
            return
        }

        DispatchQueue.main.async {
            self.isProcessing = true
        }

        let systemPrompt = """
        Sen kullanicinin kisisel Mac asistanisin. Adin "Ada". Turkce konusuyorsun. Kisa ve net cevaplar ver (max 2-3 cumle).

        Mac'te islem yapman gerekiyorsa asagidaki araclardan birini JSON formatinda dondur:
        {"tool": "arac_adi", "params": {...}, "message": "kullaniciya soylenecek mesaj"}

        Araclar:
        - open_app: Uygulama ac. params: {"name": "Safari"}
        - close_app: Uygulama kapat. params: {"name": "Safari"}
        - open_url: URL ac. params: {"url": "https://..."}
        - run_shell: Terminal komutu calistir. params: {"command": "ls ~/Desktop"}
        - set_volume: Ses seviyesi (0-100). params: {"level": 50}
        - search_web: Web aramasi. params: {"query": "hava durumu"}
        - search_files: Dosya ara (Spotlight). params: {"query": "rapor.pdf"}
        - toggle_dark_mode: Karanlik mod ac/kapat. params: {}
        - lock_screen: Ekrani kilitle. params: {}
        - screenshot: Ekran goruntusu al. params: {}
        - empty_trash: Cop kutusunu bosalt. params: {}
        - show_notification: Bildirim goster. params: {"title": "...", "message": "..."}
        - get_info: Sistem bilgisi al. params: {}

        Arac gerekmiyorsa duz metin cevap ver. Tehlikeli komutlarda (silme, format vb.) uyar.
        """

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 300,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.response = "Istek hazirlanamiyor."
            }
            return
        }
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }

            guard let data, error == nil else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.response = "Baglanti hatasi: \(error?.localizedDescription ?? "")"
                }
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let textContent = content.first?["text"] as? String else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMsg = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        self.response = "API hatasi: \(errorMsg)"
                    } else {
                        self.response = "Yanit islenemedi."
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self.isProcessing = false

                let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("{"),
                   let toolData = trimmed.data(using: .utf8),
                   let toolJSON = try? JSONSerialization.jsonObject(with: toolData) as? [String: Any],
                   let tool = toolJSON["tool"] as? String {
                    let params = toolJSON["params"] as? [String: Any] ?? [:]
                    let message = toolJSON["message"] as? String ?? "Yapiliyor..."
                    self.response = message
                    self.speak(message)
                    self.executeAction(tool: tool, params: params)
                } else {
                    self.response = textContent
                    self.speak(textContent)
                }
            }
        }.resume()
    }

    // MARK: - Actions

    private func executeAction(tool: String, params: [String: Any]) {
        switch tool {
        case "open_app":
            if let name = params["name"] as? String {
                runAppleScript("tell application \"\(name)\" to activate")
            }

        case "close_app":
            if let name = params["name"] as? String {
                runAppleScript("tell application \"\(name)\" to quit")
            }

        case "open_url":
            if let urlStr = params["url"] as? String, let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
            }

        case "run_shell":
            if let command = params["command"] as? String {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let output = self?.runShellCommand(command) ?? ""
                    DispatchQueue.main.async {
                        if !output.isEmpty {
                            self?.response += "\n" + String(output.prefix(500))
                        }
                    }
                }
            }

        case "set_volume":
            if let level = params["level"] as? Int {
                runAppleScript("set volume output volume \(max(0, min(100, level)))")
            }

        case "search_web":
            if let query = params["query"] as? String,
               let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }

        case "search_files":
            if let query = params["query"] as? String {
                let sanitized = query.replacingOccurrences(of: "'", with: "'\\''")
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let output = self?.runShellCommand("mdfind -name '\(sanitized)' | head -10") ?? ""
                    DispatchQueue.main.async {
                        if !output.isEmpty {
                            self?.response += "\n" + output
                        }
                    }
                }
            }

        case "toggle_dark_mode":
            runAppleScript("tell app \"System Events\" to tell appearance preferences to set dark mode to not dark mode")

        case "lock_screen":
            runAppleScript("""
            tell application "System Events"
                keystroke "q" using {control down, command down}
            end tell
            """)

        case "screenshot":
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.runShellCommand("screencapture -i ~/Desktop/screenshot-$(date +%Y%m%d-%H%M%S).png")
            }

        case "empty_trash":
            runAppleScript("tell application \"Finder\" to empty trash")

        case "show_notification":
            let title = params["title"] as? String ?? "Ada"
            let message = (params["message"] as? String ?? "")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
            runAppleScript("display notification \"\(message)\" with title \"\(safeTitle)\"")

        case "get_info":
            let monitor = SystemMonitor.shared
            let info = "CPU: %\(String(format: "%.0f", monitor.cpuUsage)) | RAM: \(String(format: "%.1f", monitor.memoryUsed))/\(Int(monitor.memoryTotal))GB | Pil: %\(monitor.batteryLevel)\(monitor.isCharging ? " (sarjda)" : "") | Disk: \(String(format: "%.0f", monitor.diskTotal - monitor.diskUsed))GB bos"
            response = info
            speak(info)

        default:
            break
        }
    }

    @discardableResult
    private func runAppleScript(_ script: String) -> String {
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        return result?.stringValue ?? ""
    }

    @discardableResult
    private func runShellCommand(_ command: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - TTS

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Clear

    func clearResponse() {
        transcript = ""
        response = ""
        stopSpeaking()
    }

    // MARK: - Global Hotkey (Option+Space)

    func setupGlobalHotkey() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 49 {
                DispatchQueue.main.async {
                    self?.toggleListening()
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 49 {
                DispatchQueue.main.async {
                    self?.toggleListening()
                }
                return nil
            }
            return event
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
