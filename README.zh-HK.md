# Setpiece

> 撳一下。Window 入位、App 啟動、Focus 模式 kick in。好似 [Rectangle](https://rectangleapp.com) 嘅 snap layout 咁，但係多埋**情境（Workspaces）**將 app + layout + Focus mode 一齊 bundle 起，加上**自動觸發** — 接駁 monitor、夾啱時間、撞正 calendar event 都會自己 fire。

免費、開源 macOS menu bar 視窗管理工具。純 Swift 寫，零外部 dependency，Apple notarized。需要 macOS 14（Sonoma）或以上。Universal binary — Apple Silicon 同 Intel 都行到。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)](https://www.apple.com/macos/) [![Universal](https://img.shields.io/badge/binary-universal-brightgreen)](https://github.com/ChiFungHillmanChan/setpiece/releases/latest) [![Latest release](https://img.shields.io/github/v/release/ChiFungHillmanChan/setpiece)](https://github.com/ChiFungHillmanChan/setpiece/releases/latest) [![GitHub stars](https://img.shields.io/github/stars/ChiFungHillmanChan/setpiece?style=flat)](https://github.com/ChiFungHillmanChan/setpiece/stargazers)

![Setpiece — 喺 menu bar 揀個 layout，成枱窗即刻入位](docs/media/scene-demo.gif)

> English version: [README.md](README.md)

> **Setpiece 喺 v0.7.6 之前叫做 Scene。** 如果你已經裝咗，安裝本身完全唔受影響 —
> 同一個 Accessibility 授權、同一批 layout 同 workspace，而 `scene://` URL 會同新嘅
> `setpiece://` 一齊繼續用。指向呢個 repository 嘅舊連結會永久轉址過嚟。

## 點解揀 Setpiece？

呢個紅海入面，Setpiece 嘅 differentiator：

|                                                        | Setpiece         | [Rectangle](https://rectangleapp.com) | [Magnet](https://magnet.crowdcafe.com) | [Loop](https://github.com/MrKai77/Loop) | [Moom](https://manytricks.com/moom) |
| ------------------------------------------------------ | :-----------: | :-----------------------------------: | :------------------------------------: | :-------------------------------------: | :---------------------------------: |
| 售價                                                   | 免費          | 免費                                  | $7.99                                  | 免費                                    | $10                                 |
| 開源                                                   | 係            | 係                                    | 唔係                                   | 係                                      | 唔係                                |
| Snap 邊位排列                                          | ✓             | ✓                                     | ✓                                      | ✓                                       | ✓                                   |
| 自訂 layout 編輯器                                     | ✓ tree-split  | —                                     | —                                      | —                                       | ✓                                   |
| **情境 Workspaces**（apps + layout + Focus 一鋪過）    | ✓             | —                                     | —                                      | —                                       | partial                             |
| **自動觸發**（monitor / 時間 / calendar）              | ✓             | —                                     | —                                      | —                                       | —                                   |
| 拖 window 換位                                         | ✓             | —                                     | —                                      | —                                       | —                                   |
| 繁體中文（HK / TW）                                    | ✓             | —                                     | —                                      | —                                       | —                                   |

如果你淨係要 snap-to-edge 嘅 tiling，Rectangle 已經夠用。如果你想撳一下就切換成個情境 — apps、layout、Focus mode 加上自動觸發 — 嗰個就係 Setpiece。

## 安裝

**用 Homebrew**（推薦）：

```bash
brew install --cask chifunghillmanchan/tap/scene
```

自動幫你清走 quarantine flag，唔會彈「cannot be verified」嘅 Gatekeeper 警告。首次開 Setpiece 嗰陣，去 **System Settings → Privacy & Security → Accessibility** 撳着 Setpiece 就得。

**或者直接下載 DMG**：**[Scene-0.7.6.dmg](https://github.com/ChiFungHillmanChan/setpiece/releases/download/v0.7.6/Scene-0.7.6.dmg)**（Universal：Apple Silicon + Intel，macOS 14+，Apple notarized — 唔會彈 Gatekeeper 警告）

所有版本：[Releases page](https://github.com/ChiFungHillmanChan/setpiece/releases) · 用 DMG 嘅話，跟住 [`docs/INSTALL.md`](docs/INSTALL.md) 做一次性嘅 Gatekeeper + Accessibility 授權步驟。

## 示範片

**情境（Workspaces）** — 將 layout、要開嘅 app 同 Focus mode bundle 埋一齊，撳一下搞掂：

![Setpiece Workspaces — 一鋪過將 layout、apps 同 Focus mode bundle 埋一齊](docs/media/scene-workspaces.png)

**Layout 編輯器** — 拖 seam 就整到任何形狀嘅 tile 排列：

![Setpiece Layouts editor — 拖 seam 整任何形狀嘅 tile 排列](docs/media/scene-layouts.png)

▶ [睇完整 30 秒示範片](docs/media/scene-marketing.mp4)（MP4，13 MB）

## v0.7.6 嘅新功能

**對話框同浮動面板唔會再食咗一格。** Setpiece 以前將一個 app 喺螢幕上擁有嘅每一個窗都當成可以排，入面包括佢嘅偏好設定對話框、儲存 sheet、inspector 同浮動面板。開其中一個就會令成個 layout 重新洗牌，將一個真窗推去最小化嗰堆 — 開個「顯示簡介」就足以搞亂一個三分排版。而家 Setpiece 會讀每個窗嘅 accessibility subrole，跳過唔係俾用家自己擺位嗰啲。呢個判斷用嘅係「排除清單」而唔係「允許清單」：好多 app 根本冇填 subrole，或者填啲自訂嘢，如果淨係認標準嗰隻，就會靜靜雞令成個 app 都排唔到 — 咁比起排多咗一個面板嚴重好多。所以認唔出嘅一律照排。

**啲窗貼得返底邊。** v0.7.4 為咗唔俾 Dock 拖住 layout 走，喺每個螢幕都預留咗 Dock 嘅厚度，因為 macOS 淨係會喺 Dock 而家嗰個螢幕留位，而 Dock 會跟住你個滑鼠走。代價係冇 Dock 嗰個螢幕底部會有一條死位。而家 **設定 → 互動 → Dock 空間** 可以熄咗個預留，啲窗就貼實底邊 — 代價就係冇咗嗰份「重新套用唔會郁」嘅穩定。預設仍然係開，單螢幕嘅 Mac 開唔開都一樣。

**新版寫嘅設定檔唔會再令 Setpiece 開唔到。** 行過新版 Setpiece 之後 `settings.json` 會升級；跟住返去舊版，舊版會唔認個檔案然後喺啟動時直接死咗，亦都冇任何提示話你知點解。而家 Setpiece 讀到「未來版本」嘅檔案會寬鬆處理 — 攞佢識得嘅設定，其餘用預設 — 而且唔會改寫個檔案，所以返去新版嗰陣啲設定仍然完好。

**Setpiece 會問你攞一次 GitHub star。** 當你真正成功套用咗二十次 layout 之後，menu bar 面板會出一行。無論你揀邊樣，佢都唔會再出現。

完整版本歷史見 [`CHANGELOG.md`](CHANGELOG.md).

## v0.7.5 嘅新功能

**macOS 26（Tahoe）設定視窗嘅制返晒嚟。** Layouts 嗰版嘅 **+**、**+ Custom**、刪除、還原做預設同 **Restore Default Presets** 全部唔見咗；Workspaces 嗰版嘅 **New**、**Duplicate**、**Delete** 都係。你仲可以改返啲已經有嘅 layout，但係喺設定入面新增、複製、刪除通通做唔到。原因係 v0.7.2 加嘅成個窗透明效果：嗰層毛玻璃底係一個 AppKit container，而 SwiftUI 個 view 係揼咗入去入面 — 而 hosting controller 淨係喺佢自己就係個窗嘅內容嗰陣先會將 toolbar 交畀個窗，包多咗一層就乜都唔交。而家嗰層毛玻璃改咗做 SwiftUI 嘅背景圖層，所以塊玻璃樣一模一樣，啲制亦都返晒嚟。macOS 14 同 15 一直都冇事。多謝 [@nphxexp-create](https://github.com/nphxexp-create) 報料（[#4](https://github.com/ChiFungHillmanChan/setpiece/issues/4)）。

完整版本歷史見 [`CHANGELOG.md`](CHANGELOG.md)。

## v0.7.4 嘅新功能

**Dock 唔會再拖住你個 layout 走** — 接多過一部 mon 嘅時候，Dock 會跟住你隻滑鼠跳，而 macOS 淨係喺 Dock 當下嗰部 mon 度留返位。Setpiece 就係排入呢個留返嘅範圍，所以你將 Dock 移去另一部 mon 再撳同一個 layout，全部 window 就會照 Dock 個高度郁一次同縮一次。而家 Setpiece 喺每一部 mon 都留返 Dock 嘅厚度，layout 嘅目標位置淨係睇你部部 mon 點擺 — 無論 Dock 遊咗去邊，再撳都唔會郁。代價：冇 Dock 嗰部 mon 都要留返嗰條位。如果你開咗 Dock 自動收埋，就完全冇代價；淨係得一部 mon 嘅話更加完全冇影響。仲有，泊喺 Dock 上面嘅 window 而家都會計入 layout，唔會再當睇唔到。

**menu bar 個 panel 會喺你撳咗嘅 layout 打剔** — 生效嗰個 layout 右邊會有個剔，個名會變粗體，唔使數 window 都知而家行緊邊個 layout。有冇打剔都好，hotkey 嘅鍵位都會對齊。

**由好舊嘅版本更新，會一次過跳到最新** — Setpiece 以前問 GitHub 攞 `releases/latest`，聽落好似係「最新版本」，其實係「按個 tag 指住嗰個 commit 嘅日期排出嚟最近嗰個 release」。如果有個 hotfix 係由舊 commit 度切出嚟，呢個 endpoint 就會交返個已經被取代嘅 release 畀你 — 落後好多版嘅用家會收到舊版，裝完重開又收到下一版，一版一版咁爬。而家 Setpiece 攞成個 release list 返嚟自己揀最高版本，draft 同 prerelease 一律跳過。Tests: 371 → 394。

完整版本歷史見 [`CHANGELOG.md`](CHANGELOG.md)。

## 功能

- **10 個內建 layout preset** — Full、Halves、Thirds、Quads、Main + Side（70/30）、LeftSplit + Right、Left + RightSplit，加埋三個縱向 variant：Main + Side（縱向）、Halves（縱向）、Thirds（縱向）
- **自己畫 layout** — 11 種 grid template（columns / rows / 2×2 / 3×2 / 4 種 L-shape）連 proportion slider；同埋自由 tree-split 嘅自訂排列，撳「+ Custom」由零開始畫任何形狀
- **每個 layout 自訂 hotkey** — 撞 chord 會 block-save（一個 chord 只屬於一個 layout 或者 workspace）
- **Smooth window animation** — duration 100–500 ms 可調，easing 揀 Linear / Ease Out / Spring；native app 60Hz、Electron app 30Hz
- **設定視窗** — Workspaces / Layouts / Hotkeys / Interaction / About（menu bar icon → Settings… 或 ⌘,）
- **撳一下，window 全部入位** — frontmost 入 slot 1，其餘按 z-order 排
- **再撳唔會搞亂** — 已經喺 slot 度嘅 window 再撳同一個 layout 都唔會動，只有未入位嘅先會移
- **Overflow 處理** — 多過 slot count 嘅 window 自動 minimize
- **拖 window 換位** — 揸住 placed window 拖落另一個 placed window，即時換位
- **拖邊同步** — Tile 完之後拖一個 window 嘅邊，隔籬嗰個自動跟住縮放填 gap
- **Electron-aware** — Cursor、VS Code、Slack 等做 ±5px retry 修正
- **Multi-display** — 只 rearrange 滑鼠所在 screen 嘅 window
- **Dock / menu bar aware** — 用 `visibleFrame`，window 永遠唔會滑入去佢哋下面
- **Animation 性能保護** — 7+ 個 window fall back 到 instant placement
- **零外部 dependency** — 純 Foundation、AppKit、SwiftUI、Carbon

## Layout 表

| ID | 名 | Slot |
|---|---|---|
| 1 | Full | 1（100%）|
| 2 | Halves | 2（50/50）|
| 3 | Thirds | 3 個等闊 column |
| 4 | Quads | 2×2 grid |
| 5 | Main + Side | 70% / 30% |
| 6 | LeftSplit + Right | 左邊 column 上下分，右邊全高 |
| 7 | Left + RightSplit | 左邊 column 全高，右邊上下分 |
| 8 | Main + Side（縱向）| 上 row 70%，下 row 30% |
| 9 | Halves（縱向）| 2 個等高 row |
| 10 | Thirds（縱向）| 3 個等高 row |

## 由 source build

### Prerequisites

- macOS 14+
- Xcode 16+（Mac App Store 免費下載）
- Swift 5.9+（Xcode 入面有）

### 用 Xcode build

```bash
git clone https://github.com/ChiFungHillmanChan/setpiece.git
cd setpiece
open SceneApp/SceneApp.xcodeproj
```

Xcode 揀 `SceneApp` scheme → ⌘R。App 以 menu bar extra 形式行（冇 Dock icon）。

### Build distributable DMG

```bash
./scripts/build-dmg.sh 0.7.6    # 出 dist/Scene-0.7.6.dmg（universal + notarized）
```

Build universal（arm64 + x86_64）binary，Developer ID sign，submit 去 Apple notary，pack 入 DMG 連 `Applications` drop shortcut。Apple Silicon 同 Intel Mac 用同一個 DMG。如果想 local iterate DMG layout，set `SKIP_NOTARY=1` 會 skip Apple notary submission，改用 ad-hoc sign。

### 跑 SceneCore 嘅 unit test

Layout / animation / store / hotkey / drag-swap / seam reflow / 自訂 tree / 診斷 / hotkey 衝突全部邏輯都喺 `SceneCore`，係 Swift package，唔使 Xcode：

```bash
swift test
```

433 個 unit test 覆蓋 layout 數學、window-to-slot mapping、animation 狀態機、JSON persistence、hotkey 衝突、drag-to-swap 邏輯、seam reflow、自訂 layout tree round-trip、診斷 writer + sanitizer、update nudge 嘅 semver 比較、edge case。

## 用法

1. 第一次 launch，Setpiece 會問 **Accessibility 授權**。喺 System Settings → Privacy & Security → Accessibility 開咗佢。
2. Click menu bar 嘅 Setpiece icon（`rectangle.3.group`）→ 會見到 10 個 layout preset 同 4 個 workspace。
3. Click 任何 layout preset，或者撳 ⌘⌃1 – ⌘⌃0（⌘⌃0 = 第 10 個）。Workspace 撳 ⌘⌥1 – ⌘⌥4。
4. Quit 用 menu 嘅 **Quit Setpiece**。

### Default hotkey 表

| Shortcut | Layout |
|---|---|
| ⌘⌃1 | Full |
| ⌘⌃2 | Halves |
| ⌘⌃3 | Thirds |
| ⌘⌃4 | Quads |
| ⌘⌃5 | Main + Side |
| ⌘⌃6 | LeftSplit + Right |
| ⌘⌃7 | Left + RightSplit |
| ⌘⌃8 | Main + Side（縱向）|
| ⌘⌃9 | Halves（縱向）|
| ⌘⌃0 | Thirds（縱向）|

Workspace 默認 hotkey：

| Shortcut | Workspace |
|---|---|
| ⌘⌥1 | Coding |
| ⌘⌥2 | Meeting |
| ⌘⌥3 | Reading |
| ⌘⌥4 | Streaming |

所有 layout 同 workspace hotkey 喺 Settings → Hotkeys 入面 re-bind 得；layout **同** workspace 之間嘅 chord 衝突儲存時 block-save。

## 自動化（v0.7+）

Setpiece 提供兩個自動化入口，任何工具都可以叫 Setpiece 做嘢：

### URL scheme

```bash
open "scene://workspace/Coding"               # 用名啟動情境
open "scene://workspace/Friday%20review?force=1"   # 無視 Free Mode
open "scene://layout/Halves"                  # 套用佈局
open "scene://free-mode/toggle"               # 切換 Free Mode
```

Terminal、Raycast script command、Alfred file action、Stream Deck「Open URL」掣、Keyboard Maestro，任何識 URL 嘅工具都可以用。

### Shortcuts.app + Siri（macOS 14.1+）

Setpiece 喺 Shortcuts.app 註冊咗 5 個 actions（喺「Setpiece」分類入面）：

- **Activate Workspace** — 揀一個情境啟動
- **Apply Layout** — 套用佈局喺當前螢幕
- **List Workspaces** — 攞晒情境名（用嚟接落後面其他 actions）
- **Toggle Free Mode**
- **Set Free Mode**（Bool 參數）

呢啲 actions 會跟住 iCloud sync 去 iPhone / iPad / Apple Watch 嘅 Shortcuts，仲可以用 Siri：

- 「Hey Siri, activate Setpiece workspace Coding」
- 「Hey Siri, apply Setpiece layout Halves」
- 「Hey Siri, toggle Setpiece Free Mode」

> AppIntents 要 macOS 14.1+。URL scheme 喺 Setpiece 支援嘅所有 macOS 版本（14.0+）都用得。

### Edge case 行為

| 情況 | 行為 |
|---|---|
| Window 多過 slot | 前 N 個按 z-order 入 slot，其餘 minimize |
| Window 少過 slot | Window 入晒，多餘 slot 留空 |
| 冇 visible window | macOS 通知（或 menu bar icon 閃，如果通知被禁）|
| 中途 revoke permission | Menu bar icon 變灰；hotkey 2 秒內 unregister |
| Electron app | Window 偏離 target 做一次 ±5px 修正 |
| System Settings | Apple 強制最細尺寸 — position 入位但 size 縮唔細 |

## 架構

```
setpiece/
├── Package.swift
├── Sources/SceneCore/          # 純邏輯，唔使 Xcode unit test 得
│   ├── AX/                     # Accessibility API wrapper
│   ├── Animation/              # Clock, FrameInterpolator, AnimationRunner
│   ├── Display/                # screen picker
│   ├── Interaction/            # HotkeyManager, DragSwapController,
│   │                           #   WindowAnimationSink, WindowMoveObserving
│   ├── Layout/                 # Slot, Layout, LayoutEngine, Plan, Geometry,
│   │                           #   LayoutTemplate, CustomLayout, PresetSeeds, LayoutStore
│   ├── Settings/               # AnimationConfig, HotkeyBinding, DragSwapConfig,
│   │                           #   SettingsStore, Cancellable
│   └── Workspace/              # Workspace, WorkspaceTrigger, WorkspaceSeeds,
│                               #   WorkspaceStore, FocusModeReference
├── Tests/SceneCoreTests/       # 433 個 XCTest case
├── SceneApp/                   # Xcode project — menu bar shell + 設定視窗
│   └── SceneApp/
│       ├── Animation/          # WindowAnimator（CVDisplayLink + AX bridge）
│       ├── Interaction/        # AXMoveObserverGroup, AXWindowLookup,
│       │                       #   DragSwapAnimationSink
│       ├── Resources/          # Localizable.xcstrings, InfoPlist.xcstrings
│       ├── Settings/           # SettingsWindowController + 5 個 tab
│       │                       #   (Workspaces / Layouts / Hotkeys / Interaction / About)
│       │                       #   + LayoutEditorView + LayoutPickerView + LayoutThumbnail
│       │                       #   + WorkspaceEditorView + WorkspaceTriggerEditor
│       │                       #   + AppPickerView + HotkeyCaptureView
│       ├── Stores/             # LayoutStoreViewModel, SettingsStoreViewModel,
│       │                       #   WorkspaceStoreViewModel
│       ├── Workspace/          # AppLauncher, FocusController, WorkspaceActivator
│       │   └── Triggers/       #   MonitorTriggerWatcher, TimeTriggerScheduler,
│       │                       #   CalendarTriggerWatcher, TriggerSupervisor
│       ├── SceneAppApp.swift   # @main + MenuBarExtra
│       ├── AppDelegate.swift
│       ├── Coordinator.swift   # orchestration 層
│       ├── MenuBarContentView.swift
│       ├── OnboardingView.swift
│       ├── OnboardingWindowController.swift
│       └── NotificationHelper.swift
└── docs/
    ├── INSTALL.md              # 用戶安裝步驟
    ├── TESTING.md              # 手動 smoke test checklist（V0.1–V0.5）
    └── media/                  # 示範片 + screenshots
```

故意分層：**`SceneCore` 完全 framework-neutral** — 冇 SwiftUI、冇 Combine、冇 ObservableObject。所有 hard logic（AX call、layout 數學、animation 狀態機、store CRUD、drag-to-swap、seam reflow、診斷）住喺度，433 個 unit test 覆蓋。**`SceneApp` 係薄殼**，只負責 SwiftUI binding、AppKit lifecycle，同埋 framework-neutral library 做唔到嘅 AppKit/AX bridge（`WindowAnimator`、`AXMoveObserverGroup`、`AXWindowLookup`、`DragSwapAnimationSink`）。SceneCore 用 closure-based observation 同 SceneApp 通訊（`@MainActor class FooStoreViewModel: ObservableObject` 做 adapter）。

`swift test` 由 command line 跑得，唔使 Xcode；只有最後 `.app` build 先要。

詳細架構 + 進階文檔：[Wiki（繁體中文）](https://github.com/ChiFungHillmanChan/setpiece/wiki/Home-zh-HK)

## 設定持久化

三個 JSON 檔，atomic write 入：

```
~/Library/Application Support/Scene/
├── layouts.json      # 10 個 seed + 你 add 嘅 custom layout + 每個嘅 hotkey
├── settings.json     # animation / drag-swap 設定
└── workspaces.json   # 4 個 workspace seed + 你 add 嘅 custom workspace + active workspace ID
```

刪呢個 folder 就 reset 返出廠 state。

## 路線圖

- **Per-display layouts** — 唔同 monitor apply 唔同 preset。
- **Pattern learning** — 觀察用家手動拖 window 嘅 pattern，建議「下午 2-5pm 通常 Cursor 70 + Chrome 30，要唔要 save 做 preset？」。
- **AI / 自然語言 input** — 打「cursor 左 chrome 右」→ LLM → layout JSON。
- **Per-app rule** — 例如「Slack 永遠入 slot 4」。
- **Launch at Login** UI。
- **Free-form canvas drag** layout editor（EpycZones 嗰種）。

## License

MIT — 睇 [`LICENSE`](LICENSE)。
