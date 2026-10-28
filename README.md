# Regex4AutoIt

**AutoIt 正規表示式（PCRE）測試工具**：即時比對／取代、語法著色與解析說明，並可一鍵產生可執行的 AU3 程式碼。

以 [AUI](#第三方元件) 介面程式庫製作，彩色預覽與語法說明使用 WebView2；沒有 WebView2 時會自動改用原生文字框。

![AutoIt](https://img.shields.io/badge/AutoIt-3.3.16%2B-blue) ![Platform](https://img.shields.io/badge/platform-Windows-lightgrey) ![License](https://img.shields.io/badge/license-Unlicense-green)

---

<img width="1200" height="950" alt="2026-10-29_021440" src="https://github.com/user-attachments/assets/970b450d-db13-4bf9-87f6-c98c4acc9bd9" />


## 功能

| 功能 | 說明 |
|---|---|
| **即時測試** | 停止輸入 300 ms 後自動驗證模式、執行比對或取代，並顯示耗時 |
| **編譯檢查** | 模式下方即時顯示「PCRE 編譯通過」或失敗位置 |
| **五種 Flag** | 支援 `StringRegExp` 的 Flag 0～4，Flag 4 的巢狀陣列會逐層列出 |
| **取代** | `StringRegExpReplace`，可指定取代次數（0＝全部），顯示實際取代數量 |
| **逐行比對** | 測試文字每一行獨立比對，列出符合／不符合與統計 |
| **語法著色** | 跳脫、群組、字元集合、量詞、錨點、註解各有顏色；支援 `\Q...\E`、POSIX 類別、控制動詞等 |
| **模式解析** | 自動說明模式中用到的修飾符、群組結構與語法 |
| **AU3 程式碼** | 自動產生單行呼叫語法；可匯出完整 `.au3` 範例或直接以 AutoIt3.exe 執行 |
| **彩色複製** | 模式可複製為 Discuz! BBCode／HTML／Word 彩色文字；AU3 程式碼以 5 種配色複製（HTML＋RTF） |
| **範例庫** | 內建常用比對與取代範例，可在程式內編輯 `Examples.ini` |
| **紀錄與收藏** | 自動保存最近 30 筆模式，可收藏 100 筆，分頁瀏覽 |
| **測試檔案** | 把整組測試（模式、文字、取代、Flag…）存成檔案，之後再讀回 |
| **語法說明** | 內建可搜尋的 PCRE 語法表，可複製文字或 HTML |

## 系統需求

- Windows 10／11
- [AutoIt](https://www.autoitscript.com/site/autoit/downloads/) 3.3.16.1 以上（從原始碼執行或編譯時需要）
- [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/)（選用；Windows 11 已內建）

## 快速開始

### 直接使用

到 [Releases](../../releases) 下載編譯好的 `Regex4AutoIt.exe`，放在任意資料夾執行即可。

> 程式會在**同一個資料夾**寫入設定與紀錄檔，請放在有寫入權限的位置。

### 從原始碼執行

```
git clone https://github.com/Hiura-Souji/Regex4AutoIt.git
cd Regex4AutoIt
"C:\Program Files (x86)\AutoIt3\AutoIt3.exe" Regex4AutoIt.au3
```

或在 SciTE 開啟 `Regex4AutoIt.au3` 後按 <kbd>F5</kbd>。

### 編譯

在 SciTE 按 <kbd>F7</kbd>（或 <kbd>Ctrl</kbd>+<kbd>F7</kbd> 開啟 AutoIt3Wrapper）。檔頭的 `#AutoIt3Wrapper_*` 指令已設定圖示、版本資訊與 32 位元輸出。

### 命令列參數

| 參數 | 作用 |
|---|---|
| `/nowebview` | 不使用 WebView2，預覽與說明改用原生文字框 |
| `/noacrylic` | 關閉壓克力（毛玻璃）視窗效果 |

## 使用說明

### 1. 比對

1. 在「正規表示式」欄位**直接輸入模式**，不需要加外層引號，也不需要把 `"` 加倍。
2. 在「測試文字」欄位貼上要測試的內容。
3. 選擇 Flag，結果會自動出現在左下方。

| Flag | 回傳內容 |
|---|---|
| 0 | 是否符合（1／0） |
| 1 | 首筆比對的擷取群組陣列 |
| 2 | 首筆比對：`[0]` 完整比對，其後為群組 |
| 3 | 全域比對：所有擷取群組攤平成一維陣列 |
| 4 | 全域比對：每筆一個陣列，`[0]` 完整比對，其後為群組 |

### 2. 取代

在「取代內容」輸入取代字串（`$1` 或 `\1` 參照群組，空字串表示刪除），按「取代」或修改取代欄位即會切換為取代模式。「取代次數」填 0 表示全部取代。

### 3. 產生 AU3 程式碼

「AU3 語法」欄位會即時顯示對應的呼叫，例如：

```autoit
StringRegExp($sInput, "(?i)([a-z]+)\s+(\d+)", 4)
```

- 右鍵選單：複製單行或完整程式（含配色，可直接貼到 Word 或論壇）
- 「匯出 AU3 / 執行 AU3」：匯出完整範例檔，或用設定中的 AutoIt3.exe 直接執行並以 MsgBox 顯示結果

匯出的完整範例：

```autoit
Local $text = "Hello 123" & @CRLF & "World 456"
Local $val = StringRegExp($text, "(?i)([a-z]+)\s+(\d+)", 4)
Local $iError = @error, $iExtended = @extended
...
MsgBox(64, "正規表示式比對結果", $sResult & @CRLF & "@error=" & $iError & " @extended=" & $iExtended)
```

### 4. 彩色預覽與複製

右下方的預覽區以深色背景顯示上色後的模式，右鍵可複製為：

- **Discuz! BBCode**（`[color=#...]`，需論壇允許 color 標籤）
- **HTML**（可貼入 WordPress「自訂 HTML」區塊）
- **Word 彩色文字**（同時放入 HTML 與純文字格式）

以上三種都有「含說明」版本，會附上自動產生的模式解析。

### 5. 範例庫（`Examples.ini`）

按「編輯範例」可直接在程式內修改，儲存前會檢查格式並備份為 `Examples.ini.bak`。

```ini
[Match]
; 名稱 = 模式
數字 = \d+
單字邊界 = \bword\b

[Replace]
; 名稱 = 模式~~~~取代內容（~~~~ 後面留空表示刪除）
刪除數字 = \d+~~~~
數字加括號 = (\d+)~~~~($1)
```

- 必須同時有 `[Match]` 與 `[Replace]` 區段
- 同一區段內名稱不可重複，名稱不可包含 `|`
- `;` 或 `#` 開頭為註解

### 6. 最近使用與收藏

手動執行成功的模式會自動加入「最近使用」（最多 30 筆，與上一筆相同時不重複記錄）。按「收藏」可永久保留（最多 100 筆）。清單每頁 12 筆，以 ◀ ▶ 換頁。

### 7. 測試檔案

「測試檔案」按鈕可把目前整組測試存成 `.txt`（內容為 JSON），方便保存或分享：

```json
{
  "format": "Regex4AutoIt.Test",
  "version": 1,
  "pattern": "(?i)([a-z]+)\\s+(\\d+)",
  "source": "Hello 123\r\nWorld 456",
  "replacement": "$2 - $1",
  "flag": 4,
  "replaceCount": 0,
  "mode": "match"
}
```

讀取時會先驗證格式並跳出確認，不會直接覆蓋目前內容。舊版的 `"RegexAUI.Test"` 格式仍可讀取。

### 8. 設定

按 ⚙ 開啟設定，變更會立即套用並寫入 INI：

- AutoIt 程式碼的複製配色（SciTE 經典、清晰高對比、海洋藍、森林綠、柔和紫）
- 介面字型與縮放比例（70%～160%）
- 編輯區／預覽區字級（12～36 px）
- AutoIt3.exe 路徑（「執行 AU3」使用）

## 資料檔

所有資料檔都放在程式所在的資料夾：

| 檔案 | 內容 |
|---|---|
| `Regex4AutoIt.ini` | 外觀設定、AutoIt3.exe 路徑、上次使用的 Flag 與取代次數 |
| `Examples.ini` | 比對／取代範例；不存在時自動以內建範例建立 |
| `Regex4AutoIt_Records.ini` | 最近使用與收藏；模式以 UTF-16 十六進位儲存，避免換行與 `=` 破壞 INI |

## 專案結構

```
Regex4AutoIt/
├─ Regex4AutoIt.au3   主程式
├─ AUI.au3            AUI 介面程式庫（第三方，含內嵌執行階段）
├─ _Ini.au3           INI 讀寫函式庫（第三方）
├─ edit.ico           程式圖示
├─ README.md
└─ LICENSE
```

### 程式架構

`Regex4AutoIt.au3` 以 `#Region` 依功能分區，每個函式前都有中文說明：

| 區段 | 內容 |
|---|---|
| 常數與全域變數 | 程式資訊、檔案路徑、各視窗控制項與狀態 |
| 程式進入點 | 初始化 AUI、解析命令列、建立視窗、進入事件迴圈 |
| 主畫面建立／事件 | `BuildMainWindow()` 與所有按鈕、選單、輸入事件 |
| 即時更新與執行 | `OnTick()` 計時器（防抖動）、`RunResult()` 執行比對／取代 |
| AU3 程式碼產生 | 單行語法、完整範例、匯出與執行 |
| PCRE 語法著色與解析 | `RegexNextToken()` 詞法掃描器、上色、`BuildPatternExplanation()` |
| WebView 彩色預覽 | 非同步注入 HTML、版本控制、失敗時退回原生文字框 |
| 語法說明視窗 | `HelpRows()` 資料表同時產生純文字與 HTML 說明 |
| 範例／紀錄／設定／測試檔案 | 各資料檔的讀寫與對應視窗 |
| 剪貼簿 | 以 Win32 API 同時寫入純文字、CF_HTML 與 RTF |

**即時更新流程**

```
輸入變動 → MarkDirty() ─┐
                         ▼
OnTick()（每 150 ms）── 停止輸入 ≥ 300 ms？
                         │ 是
                         ├─ ValidatePattern()   編譯檢查
                         ├─ UpdateSyntax()      產生 AU3 語法
                         ├─ UpdatePreview()     產生彩色 HTML
                         └─ RunResult()         執行並顯示結果
                         ▼
RefreshWebViews()  ── 非同步把最新 HTML 送進 WebView（失敗 20 次改用原生文字框）
```

## 第三方元件

| 檔案 | 說明 |
|---|---|
| `AUI.au3` | AUI（AutoIt 使用者介面程式庫）0.9.5 測試版，授權依原作者規定 |
| `_Ini.au3` | INI 讀寫函式庫 v1.2.3.0，作者 Afan（[autoitx.com](http://www.autoitx.com)），解決內建 IniRead 的編碼與 32767 字元限制 |
| `Array.au3`、`Math.au3` | AutoIt 標準 UDF |

## 授權

本程式（`Regex4AutoIt.au3`）以 [Unlicense](LICENSE) 釋出於公眾領域，可自由使用、修改與散布。第三方元件依各自的授權條款。

---

**格雷資訊** · [grayfree.tw](https://www.grayfree.tw/)
