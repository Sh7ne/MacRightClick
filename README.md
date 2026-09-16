<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="Mac RightClick: send photos and videos from Finder to iOS Simulator, copy paths, and convert files locally.">
</p>

<p align="center">
  <strong>English</strong> ·
  <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="#add-to-ios-simulator">Add to iOS Simulator</a> ·
  <a href="#features">Features</a> ·
  <a href="#install">Install</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="#changelog">Changelog</a>
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-111827?labelColor=0F172A">
  <img alt="macOS 27 tested" src="https://img.shields.io/badge/macOS-27-tested-2AD88F?labelColor=111827">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-F05138?labelColor=111827">
  <img alt="Finder Sync" src="https://img.shields.io/badge/Finder-Sync-2F80ED?labelColor=111827">
  <img alt="Local only" src="https://img.shields.io/badge/Local-only-2AD88F?labelColor=111827">
</p>

**Mac RightClick** puts small, useful file operations in Finder's right-click menu: send test photos and videos to **iOS Simulator**, copy a path with one hand, turn PDFs into JPGs, or convert AVI clips to MP4. Select your files, right-click, and get back to what you were doing. Native and local, with no Shortcuts, Automator workflows, or cloud uploads.

## Add to iOS Simulator

Test a photo picker, video editor, or media workflow with your own files. Select photos or videos in Finder, right-click, and choose **Add to iOS Simulator** directly in the main context menu. The files are imported into the target simulator's **Photos library**; the originals stay untouched.

| Simulator state | What happens |
| --- | --- |
| **One running device** | Imports immediately into that device, with no chooser |
| **Multiple running devices** | Opens a chooser showing each available device's name, iOS version, and running state |
| **No running devices** | Lets you choose an available device, starts it, waits for boot to finish, then imports |

- Select multiple photos and videos at once, including files with spaces in their paths.
- The action appears only when every selected item is an image or video.
- Every import targets an explicit **device UUID**, never the ambiguous `booted` alias.
- A native dialog reports success or failure. Menus and simulator dialogs follow your system language, with English and Simplified Chinese supported.

**Requires Xcode**, an installed iOS Simulator runtime, and at least one available iOS simulator. Your active developer directory must point to Xcode, not only Command Line Tools. Media compatibility follows Apple's `simctl addmedia`; this action imports files without transcoding them. Xcode is not required for Copy Path or the conversion actions.

> Available in [v1.1.0](https://github.com/Sh7ne/MacRightClick/releases/tag/v1.1.0) and later. See the [changelog](#changelog).

## Why Copy Path?

Finder already lets you hold **Option** in its contextual menu to reveal **Copy as Pathname**. That works, but I do not want to press Option either. This operation is so simple it deserves a one-handed flow from start to finish: select the file, right-click it, choose **Copy Path**.

<p align="center">
  <img src="./assets/readme/workflow.svg" width="100%" alt="Select files in Finder, right-click, and import media to Simulator, copy paths, or convert files locally.">
</p>

<p align="center">
  <img src="./assets/readme/section-features.svg" width="100%" alt="Small menu. Practical file work.">
</p>

## Features

| Action | Appears when | Output |
| --- | --- | --- |
| **Add to iOS Simulator** | Every selected item is an image or video | Imports the selection into the chosen iOS simulator's Photos library |
| **Copy Path** | Any Finder item is selected | Copies absolute file paths to the clipboard, one per line |
| **Convert PDF to JPG** | Every selected item is a PDF | Single-page PDFs create `Name.jpg`; multi-page PDFs create a `Name JPG` folder |
| **Convert AVI to MP4** | Every selected item is an `.avi` file | Creates `Name.mp4` beside the source AVI |

### Built on Apple frameworks and tools

- **Finder Sync** adds the root contextual menu items in Finder.
- **Xcode's simctl** discovers, boots, and imports media into the selected iOS simulator.
- **PDFKit** renders PDF pages to JPG at 200 DPI with high-quality JPEG output.
- **AVFoundation** exports AVI video to MP4 locally.
- **AppKit pasteboard** powers `Copy Path` without extra dependencies.

## Install

Download the [latest release DMG](https://github.com/Sh7ne/MacRightClick/releases/latest), open it, and drag **MacRightClick.app** into **Applications**.

Use **v1.1.0 or later** for simulator import, localized menus, and the updated app icon.

Then enable the Finder extension:

1. Open **System Settings**.
2. Go to **General > Login Items & Extensions**.
3. Open **Extensions / Finder Extensions**.
4. Enable **Mac RightClick**.
5. Relaunch Finder, or run:

```bash
killall Finder
```

## Use

Right-click selected files in Finder:

```text
Copy Path
Convert PDF to JPG
Convert AVI to MP4
Add to iOS Simulator
```

Conversion output is written next to the source file. Existing files are not overwritten; Mac RightClick adds a numeric suffix when needed.

Simulator imports appear in **Photos inside the selected simulator**, not in a new folder beside the source. Only actions relevant to the selection are shown; the list above uses the English menu labels.

## Privacy

Mac RightClick is intentionally boring about data:

- It processes files locally on your Mac.
- It does not upload files.
- It does not request notification permission.
- It only acts on files the user selected in Finder.
- macOS may ask for file access when reading media or writing output in protected folders such as Downloads, Desktop, or Documents. Allow access to the folder containing the files you want to process.

## Changelog

### [v1.1.0](https://github.com/Sh7ne/MacRightClick/releases/tag/v1.1.0) · 2026-09-16

- **Add to iOS Simulator:** import selected photos and videos from Finder into Simulator Photos. Includes one-click import to a single running device, a device chooser, automatic boot, explicit UUID targeting, multi-file support, and success or failure feedback.
- **Localization:** English and Simplified Chinese menus and simulator dialogs follow the system language.
- **macOS 27:** updated for Xcode 27 and verified on macOS 27, retaining the macOS 14+ deployment target.
- **App icon:** refreshed design with a light background and a neutral, predominantly black dark appearance.

[Changes since v1.0.0](https://github.com/Sh7ne/MacRightClick/compare/v1.0.0...v1.1.0)

### [v1.0.0](https://github.com/Sh7ne/MacRightClick/releases/tag/v1.0.0) · 2026-08-11

- Initial release with **Copy Path**, **Convert PDF to JPG** at 200 DPI, and **Convert AVI to MP4** using Apple frameworks.
- Native Finder extension, local processing, and DMG distribution.

## Notes

Finder Sync extensions are managed by macOS. If a newly installed build does not appear immediately, relaunch Finder and confirm the extension is enabled in System Settings.

Mac RightClick is built with Xcode 27 and verified on macOS 27 while retaining its macOS 14+ deployment target.
