# Dynamic Island for macOS

A Dynamic Island-style panel for any Mac running macOS 14 or later. A black capsule sits at the top center of the screen, shows live system stats, and expands into a widget panel when you click it. Built with SwiftUI and AppKit, no dependencies.

## Features

- Compact capsule at the top center of the screen, visible on all Spaces and in fullscreen apps
- Click to expand into a widget panel, with spring animations and hover effects
- Widgets: CPU and RAM, battery, network and Wi-Fi, disk usage, system details (processes, local IP, swap, uptime, active app)
- Control panel with quick timers
- Optional voice assistant ("Ada"): press Option+Space, speak in Turkish, and it answers through the Claude API and can run Mac actions
- Menu bar icon, hidden from the Dock

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ (Xcode 15 or later, or the Swift toolchain)

## Build and run

```bash
git clone https://github.com/tahaogul/dynamic-island-macos.git
cd dynamic-island-macos
swift build -c release
.build/release/DynamicIsland
```

## Voice assistant setup

The assistant is off until you add an Anthropic API key. Create `~/.config/dynamicisland/config.json`:

```json
{ "claude_api_key": "sk-ant-..." }
```

macOS asks for microphone and speech recognition permission the first time you use it. Speech recognition is set to Turkish (`tr-TR`).

**Warning:** the assistant can run shell commands, quit apps and empty the Trash based on the model's reply, without asking for confirmation. Only enable it if you accept that risk.

## Project structure

```
Sources/DynamicIsland/
├── main.swift                    # App entry point and delegate
├── IslandState.swift             # Shared state: expand/collapse, timer
├── IslandWindowController.swift  # Always-on-top transparent panel, compact and expanded views
├── IslandWidgets.swift           # Widget views
├── SystemMonitor.swift           # CPU, memory, disk, network, battery readings
└── VoiceAssistant.swift          # Speech recognition, Claude API call, actions, TTS
```

## Contributing

Issues and pull requests are welcome. For larger changes, open an issue first so we can agree on the approach.

## License

[MIT](LICENSE)
