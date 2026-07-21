# Wallper macOS Live Wallpaper Runner

Wallper is a small macOS background runner for playing live wallpapers.

It is not a full standalone app yet. The goal of this project is to provide the background part of the Wallper experience: selecting a local video and keeping it running like a live desktop wallpaper on macOS.

## What It Does

- Plays a local video as a live wallpaper
- Runs quietly in the background
- Supports the main screen or all connected screens
- Loops the selected video continuously
- Can pause wallpaper playback while on battery power
- Can restore the last used wallpaper on launch
- Can optionally start automatically when you log in

## How It Works

The runner creates a borderless macOS window behind the desktop icons and plays the selected video using AVFoundation. The wallpaper window ignores mouse input, so the desktop remains usable while the video plays in the background.

## Project Structure

```text
local-runner/
  Package.swift
  Sources/WallperRunner/
    WallperRunner.swift
    Stubs.swift
    OpenSource/
      app-delegate.swift
      launch.manager.swift
      launch.provider.swift
      video.manager.swift

open-source-code/
  app-delegate.swift
  launch.manager.swift
  launch.provider.swift
  video.manager.swift
```

## Requirements

- macOS 13 or newer
- Xcode with Swift support
- Swift 6.2 or newer
- A local video file, such as MP4 or MOV

## Run Locally

Open the local runner folder:

```bash
cd local-runner
```

Build the project:

```bash
swift build
```

Run it:

```bash
swift run WallperRunner
```

## Notes

- This project is focused on the wallpaper runner behavior, not a complete polished app interface.
- Some files are included as open-source runner logic, while `local-runner` contains a safe local package setup for building and testing.
- Wallpaper behavior depends on macOS window levels and display handling, so results may vary across macOS versions and multi-monitor setups.

## Security

If you find a security issue, please see [SECURITY.md](SECURITY.md).
