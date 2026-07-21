import SwiftUI
import AppKit

@main
struct WallperRunnerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @AppStorage("wallper.enableWallpaperChanges") private var isWallpaperChangesEnabled = false
    @AppStorage("wallper.pauseOnBattery") private var pauseOnBattery = true
    @AppStorage("wallper.restoreLastWallpapers") private var restoreLastWallpapers = true
    @AppStorage("wallper.autoStart") private var autoStartEnabled = false
    @AppStorage("wallper.applyToAllScreens") private var applyToAllScreens = false

    @State private var selectedVideoURL: URL? = nil
    @State private var statusText: String = "Select a local MP4 file to apply as live wallpaper."

    var body: some View {
        VStack(spacing: 12) {
            Text("Wallper Local Runner (Safe Mode)")
                .font(.title2)
            Text("This build compiles the open-source files but does not apply wallpapers or modify system settings.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Toggle("Enable wallpaper changes (main screen only)", isOn: $isWallpaperChangesEnabled)
                .toggleStyle(.switch)
                .padding(.top, 8)
            Toggle("Pause on battery power", isOn: $pauseOnBattery)
                .toggleStyle(.switch)
            Toggle("Restore last wallpaper on launch", isOn: $restoreLastWallpapers)
                .toggleStyle(.switch)
            Toggle("Start at login", isOn: $autoStartEnabled)
                .toggleStyle(.switch)
                .onChange(of: autoStartEnabled) { newValue in
                    setAutoStart(enabled: newValue)
                }
            Toggle("Apply to all screens", isOn: $applyToAllScreens)
                .toggleStyle(.switch)
            HStack(spacing: 12) {
                Button("Choose Video…") {
                    selectVideo()
                }
                .disabled(!isWallpaperChangesEnabled)

                Button(applyToAllScreens ? "Apply to All Screens" : "Apply to Main Screen") {
                    applyWallpaper()
                }
                .disabled(!isWallpaperChangesEnabled || selectedVideoURL == nil)

                Button("Stop Wallpaper") {
                    stopWallpaper()
                }
                .disabled(!isWallpaperChangesEnabled)
            }
            .padding(.top, 4)

            Text(statusText)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 240)
    }

    private func selectVideo() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie]
        panel.title = "Select a video file"
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            selectedVideoURL = url
            statusText = "Selected: \(url.lastPathComponent)"
        }
    }

    private func applyWallpaper() {
        guard isWallpaperChangesEnabled else {
            statusText = "Wallpaper changes are disabled."
            return
        }
        guard let url = selectedVideoURL else {
            statusText = "No video selected."
            return
        }

        if pauseOnBattery, PowerMonitor.shared.isCurrentlyOnBattery() {
            statusText = "On battery power. Wallpaper paused."
            return
        }

        UserDefaults.standard.set(false, forKey: "advancedWallpaperApply")
        UserDefaults.standard.set(false, forKey: "adaptMenuBar")
        UserDefaults.standard.set(restoreLastWallpapers, forKey: "restoreLastWallpapers")
        UserDefaults.standard.set(pauseOnBattery, forKey: "pauseOnBattery")
        let applyAll = applyToAllScreens
        VideoWallpaperManager.shared.setVideoAsWallpaper(
            from: url,
            screenIndex: 0,
            applyToAll: applyAll
        )
        statusText = applyAll
            ? "Applied live wallpaper to all screens."
            : "Applied live wallpaper to main screen."
    }

    private func stopWallpaper() {
        if applyToAllScreens {
            VideoWallpaperManager.shared.stopCurrentWallpaper(screenIndex: nil)
            statusText = "Stopped live wallpaper on all screens."
        } else {
            VideoWallpaperManager.shared.stopCurrentWallpaper(screenIndex: 0)
            statusText = "Stopped live wallpaper on main screen."
        }
    }

    private func setAutoStart(enabled: Bool) {
        do {
            if enabled {
                try LaunchAgentManager.install()
                statusText = "Start at login enabled."
            } else {
                try LaunchAgentManager.uninstall()
                statusText = "Start at login disabled."
            }
        } catch {
            statusText = "Auto-start change failed: \(error.localizedDescription)"
        }
    }
}
