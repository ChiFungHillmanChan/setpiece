# 貢獻 Setpiece

感謝你看到這裡。Setpiece 由一個人在香港（UTC+8）維護，沒有資助，利用餘暇開發。以下所有內容都源自這個事
實 — 我們真心歡迎貢獻，但所有工作只能以一位 reviewer 的速度消化，所以這份指南存在的目的，就是不想浪費
你的心力。

> English version: [CONTRIBUTING.md](CONTRIBUTING.md)。本專案的工作語言是英文 — issue 與 PR 用英文撰
> 寫較為理想，但用中文我一樣看得懂，請不要因此而不出聲。
>
> 本文件與其他貢獻者文件使用**繁體書面語**。App 介面內的 `zh-HK` 字串則另有規定，使用**粵語**，詳見下
> 文〈翻譯〉一節。

**一句話總結：** 修正 bug 可以直接開 PR。新增功能、改動 UI、或是涉及寫入磁碟的資料，請先開 issue，待回
覆後再動手寫程式碼。

## 不必寫程式碼也能幫忙

有用的貢獻不只有 patch：

- **準確地回報 bug。** 一份能夠重現的多螢幕 bug report，價值高於大部分 patch — 這類缺陷最難獨力找出
  來，因為需要相應的硬體才碰得到。
- **改善翻譯。** Setpiece 提供英文、繁體中文（香港）與繁體中文（台灣）。母語使用者的修正永遠歡迎，修好一
  句不通順的字串已經是很好的第一次貢獻。
- **協助回覆其他人的 issue。** 其中一半是「該怎麼做⋯⋯」，你可能已經知道答案。
- **幫忙把它告訴別人。** 一顆 star、一篇文章、一段影片，或是跟身邊仍在用手拖拉視窗的同事提一句。對一個
  免費的 menu bar app 來說，被人發現才是最難的一關。

## 回報 bug

**請先搜尋現有 issue，包括已關閉的** — 其中記錄了數個已知的 macOS 行為，並以「並非 Setpiece 的 bug」為理由
關閉。

接著開一個 issue，內容包含：

- **Setpiece 版本** — 在 Settings → About 可以找到。
- **macOS 版本與晶片**（Apple Silicon 或 Intel）。
- **你的螢幕配置** — 有幾部顯示器、如何排列、縮放比例，以及當時游標位於哪一部。相當大比例的 layout bug
  其實是多螢幕的問題，而這一行資訊通常就是讓它得以重現的關鍵。
- **是哪一個 layout 或 workspace**、你預期的結果，以及實際發生的情況。
- **一段螢幕錄影**，如果問題與視窗如何移動有關。視窗的 geometry 幾乎無法用文字準確描述，五秒鐘的影片就
  能終結所有猜測。
- **診斷紀錄（Diagnostics export）**，如果問題涉及 workspace 啟動、觸發條件或更新程式。前往 Settings →
  About → 開啟 **Enable diagnostic logging** → 重現該問題 → 按 **Export Diagnostics for Bug Report**。
  在你主動附上之前，這些資料不會離開你的 Mac。

**安全性問題請勿開公開 issue。** 請依照 [SECURITY.md](SECURITY.md) 所述的私密通報管道處理。

## 提出功能需求

**請先閱讀 [README](README.md#roadmap) 的 Roadmap。** 已列為 deferred 的項目均已知悉並有記錄，重複提出
並不會讓它們提前實作。

好的需求先說明使用情境，而非你心中預設的做法 —「我希望回到公司接上外接螢幕後，編輯器與終端機會自動左
右對調」比「請加一個左右對調的按鈕」提供的資訊多得多。有時把使用情境講清楚之後，會發現現有功能已經做
得到。

Setpiece 婉拒需求的比例不低，背後的取捨值得先說明：它希望維持為一個小巧、把 layout 與 workspace 做好的
menu bar app。沒有外掛系統、沒有帳戶、沒有雲端同步、沒有遙測，也沒有外部相依套件。

## Pull request

**先開 issue，再送 PR。** 具體而言：

**可以直接送 PR：** 錯字、文件修正、翻譯修正、為既有行為補上測試，以及一望即知的小型 bug 修正。

**請先開 issue 並取得回覆後再動手：**

- 新增功能或新增設定項目，
- 改動任何 UI 或任何使用者可見的字串，
- 改動寫入磁碟的 JSON 結構（`layouts.json`、`settings.json`、`workspaces.json`），
- 新增 workspace 觸發類型、URL route 或 App Intent，
- 改動預設快捷鍵或預設 layout 種子（preset seed）。

這並非為了設關卡。Schema 一旦改動，就必須為已經存有資料的使用者提供遷移路徑；每新增一句字串就等於三個
locale 的工作量；而你花了整個週末的成果最後被婉拒，對雙方都不好受。先開一個五行的 issue 就能避免。

**未經討論就送出，多半會被婉拒：** 引入外部相依套件、加入 build 階段的程式碼產生步驟、整個專案的格式重
排、一次橫跨大量檔案的重構，以及違反下列架構界線的改動。

## 開發環境

**需求：** macOS 14+、Xcode 16+、Swift 5.9+（隨 Xcode 提供）。沒有套件管理步驟 — Setpiece 刻意維持零外部
相依套件。

```bash
git clone https://github.com/ChiFungHillmanChan/setpiece.git
cd setpiece

swift build      # 編譯 SceneCore，即 framework-neutral 的邏輯 library
swift test       # 執行 SceneCore 的完整單元測試，不需要 Xcode

# 建置 App 本身
xcodebuild -project SceneApp/SceneApp.xcodeproj -scheme SceneApp \
  -configuration Debug CODE_SIGNING_REQUIRED=NO build
```

或者開啟 `SceneApp/SceneApp.xcodeproj`，選擇 `SceneApp` scheme 並按 ⌘R。App 以 menu bar extra 形式執
行，沒有 Dock 圖示。

以下兩件事若沒有人事先提醒，會讓你白白損失一小時：

**乾淨環境下出現 `errSecInternalComponent`。** 在 `xcodebuild` 加上 `CODE_SIGNING_REQUIRED=NO` 即可。
這是正常現象，不是你的 checkout 有問題。

**每次重新建置後，Accessibility 權限都會失效。** macOS 將 AX 授權綁定在執行檔的程式碼簽章雜湊
（cdhash）上，因此每次本機建置對 TCC 而言都是另一個 App。System Settings 中的開關**看起來仍然是開啟
的**，但 `AXIsProcessTrusted()` 會回傳 false — Setpiece 的行為會像是完全沒有權限。解決方式二擇一：

```bash
tccutil reset Accessibility com.hillman.SceneApp    # 然後重新啟動並重新授權
```

或是在 **System Settings → Privacy & Security → Accessibility** 中將 Setpiece 關閉再開啟。

## PR 必須遵守的架構規則

以下是承重結構。違反其中任何一條的 patch，即使功能正常也會被退回，因此動手之前值得先讀一遍。

**SceneCore 維持 framework-neutral。** `Sources/SceneCore/` 之下不得出現 `import SwiftUI`、
`import Combine` 或 `ObservableObject`。Store 以 closure 提供觀察機制（`onChange { … } -> Cancellable`）；
SwiftUI 的轉接層放在 `SceneApp/SceneApp/Stores/`。正是這條界線，讓 `swift test` 不需要 Xcode 也能執行。

**零外部相依套件。** `Package.swift` 與 App target 皆是如此。

**`TilingFrame.forScreen(_:)` 是 tiling 的唯一權威。** 切勿將原始的 `screen.visibleFrame` 傳入
`Slot.absoluteRect(in:)` 或 `LayoutEngine.plan`。`visibleFrame` 只會在 Dock 當下所處的那一部顯示器保留
Dock 的空間，而 Dock 會隨著游標在顯示器之間移動 — 因此同一個 layout 在同一個螢幕套用兩次，落點可能相
差約 70pt。`screen.frame` 只適用於一件事：判斷某個視窗屬於哪一部顯示器。

**單位矩形（unit rect）採用左上角原點。** 每個 `Slot.rect` 都以 y=0 為畫面頂端撰寫，與 SwiftUI 的繪製
端一致。`slot.absoluteRect(in:)` 只會翻轉一次到 AppKit 的左下角座標系；`LayoutReflow` 則是反向對映。若
你新增任何座標轉換，必須與這兩者一致，否則不對稱的 layout 會上下顛倒。

**權限檢查屬於協調層（orchestration）。** `LayoutEngine` 永遠不會看到 `.noPermission`；由 `Coordinator`
接住 `.permissionDenied` 並重新開啟導引畫面。

**`plan()` 是純函式。** 副作用只存在於 `apply()`、`WindowAnimator` 與 `WorkspaceActivator`。正因為它保
持純粹，layout 的數學運算才得以測試。

想了解完整脈絡，請看 [README](README.md#architecture) 的 Architecture 一節。

## 測試

送出 PR 之前，`swift test` 必須全數通過。CI 會在每個 PR 上執行它，並額外建置整個 SceneApp，因此測試失敗
一樣會被攔下。

- **邏輯寫在 SceneCore，並附上測試。** Layout 數學、store、快捷鍵衝突、動畫狀態、持久化、觸發器 — 全部
  都能在不啟動 App 的情況下測試，新增的邏輯預期要有相應覆蓋。
- **修正 bug 時，請先寫一個會失敗的測試。** 一個重現該 bug 的測試，加上讓它轉綠的修正，是 bugfix PR 最
  容易審閱的形式。
- **AppKit / SwiftUI 這一層沒有單元測試。** 若你改動了這一層，請在
  [`docs/TESTING.md`](docs/TESTING.md) 新增或更新一個情境，並在 PR 描述中說明你實際執行過。

## 翻譯

所有使用者可見的字串都位於 `SceneApp/SceneApp/Resources/Localizable.xcstrings`（Xcode String Catalog），
共三個 locale：`en`、`zh-HK`、`zh-TW`。切勿在 view 中寫死顯示字串。

**字串插值有嚴格寫法。** 請使用 `String(format: String(localized: "key"), arg)` — 不要使用
`String(localized: "key \(arg)")`。動態 key 會讓 catalog 查找靜默失敗，最後把原始 key 直接顯示給使用
者。含插值的 catalog 值必須帶有 `%@`（整數則為 `%lld`）。

**App 介面的 `zh-HK` 使用粵語，而非書面語。** 請使用 撳（而非 按）、嘅（而非 的）、係（而非 是）、
咁（而非 這樣）、喺（而非 在）、啲（而非 些）、你哋（而非 你們）、冇（而非 沒有）。`zh-TW` 則使用標準
書面中文。請注意：這條規則只適用於 App 內的介面字串；本專案的文件（包括這一份）一律使用繁體書面語。

如果你新增了字串但不擅長中文，只提供 `en` 即可，並在 PR 中說明 — 中文可於審閱階段補上。這遠勝於提交一
份無人能夠背書的機器翻譯。

## Commit message

採用 Conventional Commits，與現有紀錄一致：

```
feat(layout): sticky slot re-apply
fix(update): offer the newest release, not GitHub's "latest"
refactor(layout): Placement carries explicit slotIndex
docs(readme): v0.7.0 — Automation surface
i18n: add 6 automation notification keys (en / zh-HK / zh-TW)
ci: add SceneCore and SceneApp build checks on PRs
```

目前使用的 scope 包括 `layout`、`workspace`、`settings`、`menubar`、`interaction`、`intents`、
`automation`、`update`、`readme`。請使用祈使語氣，一個 commit 只做一件事。`release:` commit 僅限維護者
使用 — 請勿在 PR 中改動 `MARKETING_VERSION` 或 `CHANGELOG.md`。

## AI 協助的貢獻

可以使用，本專案自身亦然。條件在於成果，而不在於工具：

- **你是作者。** 你送出的每一行都應該理解，並且能在審閱時說明為何這樣寫。連自己的 PR 都無法解釋的，一
  律關閉，無論它是怎麼產生的。
- **請實際建置並在真實的 Mac 上執行。** 一旦涉及 Accessibility API 與真實視窗，能夠編譯並不等於能夠運
  作。請在 PR 中說明你實際驗證過哪些情況。
- **遵守上述架構規則。** 生成的 Swift 預設會傾向使用 SwiftUI 與第三方套件，這兩者在本專案都是錯的。
- **請勿提交生成的 bug report。** 一份描述著沒有人實際觀察到的症狀的 issue，需要耗費真實的時間追查。請
  回報你親眼所見的情況。
- **Diff 只保留該任務所需的內容。** 未經要求的重構、格式重排，以及在未改動檔案中大幅改寫註解，都會讓
  patch 無法審閱。

## 請勿提交的內容

以下已由 `.gitignore` 涵蓋，請勿強制加入版本控制：

- `.DS_Store`、`/build/`、`/dist/`、`.build/`、`.swiftpm/`、`Package.resolved`
- AI 與 agent 工作階段產物：`docs/superpowers/`、`.superpowers/`、`.claude/`、`.cursor/`、`CLAUDE.md`、
  `AGENTS.md`、`GEMINI.md`
- `.env`、簽章身分（signing identity）、佈建描述檔，或任何包含 Developer ID 的檔案

## PR 檢查清單

- [ ] 已連結對應的 issue，除非屬於錯字、文件、翻譯或一望即知的小型修正。
- [ ] `swift test` 在本機通過。
- [ ] App 能夠建置，且你已在真實的 Mac 上執行過。
- [ ] 新增的邏輯附有 SceneCore 測試；UI 改動附有 `docs/TESTING.md` 情境。
- [ ] 新增的使用者可見字串已寫入 String Catalog，而非寫死在程式碼中。
- [ ] 沒有新增外部相依套件。
- [ ] Diff 僅包含此項改動所需的內容。

## 授權

向 Setpiece 提交貢獻，即表示你同意你的貢獻以本專案的 [MIT License](LICENSE) 授權。本專案沒有 CLA，也不要
求著作權轉讓 — 著作權仍然屬於你，授權條款只是讓本專案得以發布它。

## 行為準則

參與本專案受 [行為準則](CODE_OF_CONDUCT.zh-HK.md) 規範。
