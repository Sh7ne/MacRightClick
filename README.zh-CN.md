<p align="center">
  <img src="./assets/readme/hero.zh-CN.svg" width="100%" alt="Mac RightClick：从 Finder 右键导入图片和视频到 iOS 模拟器，复制路径，并在本地转换文件。">
</p>

<p align="center">
  <a href="./README.md">English</a> ·
  <strong>简体中文</strong>
</p>

<p align="center">
  <a href="#添加到-ios-模拟器">添加到 iOS 模拟器</a> ·
  <a href="#功能">功能</a> ·
  <a href="#安装">安装</a> ·
  <a href="#隐私">隐私</a> ·
  <a href="#版本记录">版本记录</a>
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-111827?labelColor=0F172A">
  <img alt="macOS 27 tested" src="https://img.shields.io/badge/macOS-27-tested-2AD88F?labelColor=111827">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-F05138?labelColor=111827">
  <img alt="Finder Sync" src="https://img.shields.io/badge/Finder-Sync-2F80ED?labelColor=111827">
  <img alt="Local only" src="https://img.shields.io/badge/Local-only-2AD88F?labelColor=111827">
</p>

**Mac RightClick** 把几件简单却常用的事放进 Finder 右键菜单：将测试图片和视频导入 **iOS 模拟器**、单手复制路径、将 PDF 转为 JPG、将 AVI 转为 MP4。选中文件，右键处理，然后继续手头的工作。原生、本地，不需要快捷指令、Automator 工作流或云上传。

## 添加到 iOS 模拟器

测试照片选择器、视频编辑器或其他媒体功能时，直接用自己的素材。在 Finder 中选中图片或视频，右键点击根菜单里的 **添加到 iOS 模拟器（Add to iOS Simulator）**，即可导入目标模拟器的**照片图库**，原文件保持不变。

| 模拟器状态 | 操作方式 |
| --- | --- |
| **只有一台正在运行** | 直接导入这台设备，不弹选择框 |
| **多台正在运行** | 弹出设备选择框，显示可用设备的名称、iOS 版本和运行状态 |
| **没有正在运行的设备** | 选择一台可用设备，自动启动，等待启动完成后导入 |

- 支持同时选中多张图片、多段视频，也支持路径中带空格的文件。
- 只有全部选中项都是图片或视频时，才显示此菜单项。
- 每次都使用明确的**设备 UUID**，不使用多设备场景下含义不明确的 `booted`。
- 导入完成或失败都会弹窗反馈。菜单和模拟器对话框跟随系统语言，支持英文和简体中文。

**需要安装 Xcode**、iOS Simulator runtime，并至少有一台可用的 iOS 模拟器。当前开发者目录需要指向 Xcode，而不是只有 Command Line Tools。可导入的媒体格式以 Apple 的 `simctl addmedia` 支持范围为准，本操作不会转码。复制路径和文件转换功能不依赖 Xcode。

> 此功能已包含在 [v1.1.0](https://github.com/Sh7ne/MacRightClick/releases/tag/v1.1.0) 及后续版本中。详见[版本记录](#版本记录)。

## 为什么有 Copy Path？

我知道 Finder 的右键菜单里按住 **Option** 会把 **拷贝** 变成 **拷贝为路径名**。它当然能用，但我连 Option 都不想按。这件事简单到应该一只手就能做完：选中文件、右键、点击 **Copy Path**。

<p align="center">
  <img src="./assets/readme/workflow.svg" width="100%" alt="在 Finder 中选中文件并右键，本地完成模拟器导入、路径复制或文件转换。">
</p>

<p align="center">
  <img src="./assets/readme/section-features.svg" width="100%" alt="小菜单，实用的文件操作。">
</p>

## 功能

| 操作 | 显示条件 | 输出 |
| --- | --- | --- |
| **Add to iOS Simulator / 添加到 iOS 模拟器** | 所有选中项都是图片或视频 | 导入所选 iOS 模拟器的照片图库 |
| **Copy Path** | 选中了任意 Finder 项目 | 将绝对路径复制到剪贴板，每行一个 |
| **Convert PDF to JPG** | 所有选中项都是 PDF | 单页 PDF 输出为 `Name.jpg`；多页 PDF 输出到 `Name JPG` 文件夹 |
| **Convert AVI to MP4** | 所有选中项都是 `.avi` 文件 | 在源 AVI 文件旁生成 `Name.mp4` |

### 使用 Apple 原生框架和工具

- **Finder Sync** 在 Finder 的根级右键菜单中加入操作。
- **Xcode 的 simctl** 发现、启动目标 iOS 模拟器，并导入媒体文件。
- **PDFKit** 以 200 DPI 高质量 JPEG 输出渲染 PDF 页面。
- **AVFoundation** 在本地将 AVI 视频导出为 MP4。
- **AppKit pasteboard** 为 **Copy Path** 提供无依赖的剪贴板支持。

## 安装

从 [GitHub Releases](https://github.com/Sh7ne/MacRightClick/releases/latest) 下载最新 DMG，打开后将 **MacRightClick.app** 拖入 **Applications**。

请使用 **v1.1.0 或更高版本**，以获得模拟器导入、本地化菜单及新图标。

然后启用 Finder 扩展：

1. 打开 **系统设置**。
2. 前往 **通用 > 登录项与扩展**。
3. 打开 **扩展 / Finder 扩展**。
4. 启用 **Mac RightClick**。
5. 重新启动 Finder，或运行：

```bash
killall Finder
```

## 使用

在 Finder 中选中文件后右键：

```text
Copy Path
Convert PDF to JPG
Convert AVI to MP4
Add to iOS Simulator
```

转换结果会写入源文件旁。已有文件不会被覆盖；需要时 Mac RightClick 会自动附加数字后缀。

模拟器导入结果位于**所选模拟器内的“照片”App**，不会在源文件旁生成新文件夹。菜单只显示适用于当前选择的操作；上面列出的是英文系统下的名称。

## 隐私

Mac RightClick 对数据的态度很简单：

- 所有文件均在本机处理。
- 不会上传文件。
- 不会请求通知权限。
- 只会处理用户在 Finder 中选中的文件。
- 读取素材或向“下载”“桌面”“文稿”等受保护目录写入结果时，macOS 可能请求文件访问权限；请允许访问待处理文件所在的目录。

## 版本记录

### [v1.1.0](https://github.com/Sh7ne/MacRightClick/releases/tag/v1.1.0) · 2026-09-16

- **添加到 iOS 模拟器：** 从 Finder 导入所选图片和视频到模拟器照片图库。支持单台运行设备一键导入、多设备选择、自动启动、明确 UUID、多选文件及成功或失败反馈。
- **本地化：** 菜单和模拟器对话框跟随系统语言，支持英文和简体中文。
- **macOS 27：** 更新为 Xcode 27 构建，并在 macOS 27 上验证，最低系统版本保持 macOS 14+。
- **App 图标：** 更新设计，提供浅色背景及以中性黑色为主的深色外观。

[查看 v1.0.0 以来的变更](https://github.com/Sh7ne/MacRightClick/compare/v1.0.0...v1.1.0)

### [v1.0.0](https://github.com/Sh7ne/MacRightClick/releases/tag/v1.0.0) · 2026-08-11

- 首次发布 **Copy Path**、200 DPI 的 **PDF 转 JPG** 和使用 Apple 原生框架的 **AVI 转 MP4**。
- 原生 Finder 扩展、本地处理、DMG 分发。

## 说明

Finder Sync 扩展由 macOS 管理。新安装的版本没有立即出现时，请重新启动 Finder，并确认扩展已在系统设置中启用。

Mac RightClick 使用 Xcode 27 构建，并已在 macOS 27 上验证；最低系统版本仍保持 macOS 14+。
