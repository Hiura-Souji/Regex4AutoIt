#Region ;**** 由 AutoIt3Wrapper_GUI 建立的指令 ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Icon=regex.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Comment=Regex4AutoIt
#AutoIt3Wrapper_Res_Description=Regex4AutoIt
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_ProductName=Regex4AutoIt
#AutoIt3Wrapper_Res_ProductVersion=2026.10.16
#AutoIt3Wrapper_Res_CompanyName=格雷資訊
#AutoIt3Wrapper_Res_LegalCopyright=grayfree.tw 2026 Unlicense.
#AutoIt3Wrapper_Res_LegalTradeMarks=grayfree.tw
#AutoIt3Wrapper_Res_Language=1028
#AutoIt3Wrapper_Res_requestedExecutionLevel=highestAvailable
#AutoIt3Wrapper_Res_CLASS=gWinUI
#AutoIt3Wrapper_Res_HiDpi=y
#EndRegion ;**** 由 AutoIt3Wrapper_GUI 建立的指令 ****

; ============================================================================
; Regex4AutoIt － AutoIt 正規表示式（PCRE）測試工具
;
; 作者　：格雷資訊 grayfree.tw
; 授權　：Unlicense（公眾領域）
; 介面　：AUI（AutoIt 使用者介面程式庫），彩色預覽與說明使用 WebView2
; 相依　：AUI.au3、_Ini.au3（Afan）、Array.au3、Math.au3
;
; 命令列參數：
;   /nowebview   不使用 WebView2，預覽與說明改用原生文字框
;   /noacrylic   關閉壓克力（毛玻璃）視窗效果
;
; 資料檔（皆位於程式所在資料夾）：
;   Regex4AutoIt.ini           外觀設定、AutoIt3.exe 路徑、上次的 Flag／取代次數
;   Examples.ini               比對／取代範例（不存在時自動建立）
;   Regex4AutoIt_Records.ini   最近使用（30 筆）與收藏（100 筆），內容以 UTF-16 十六進位儲存
; ============================================================================

#NoTrayIcon     ; 不顯示系統匣圖示
#RequireAdmin   ; 請求管理員權限（程式資料夾位於 Program Files 時才能寫入 INI）

#include "AUI.au3"
#include "_Ini.au3"
#include <Array.au3>
#include <Math.au3>

#Region ;===== 常數與全域變數 =====

; ---- 程式資訊與上限 ----
Global Const $APP_NAME = "Regex4AutoIt", $APP_VERSION = "1.0.0"
Global Const $MAX_HISTORY = 30 ; 最近使用紀錄上限
Global Const $MAX_FAVORITES = 100 ; 收藏上限
; 彩色預覽右鍵選單；項目順序對應 OnColorMenu() 的索引 0～5
Global Const $COLOR_MENU_ITEMS = "複製 Discuz! BBCode|複製 HTML|複製 Word 彩色文字|複製 Discuz! BBCode（含說明）|複製 HTML（含說明）|複製 Word 彩色文字（含說明）"

; ---- 檔案路徑 ----
Global $gIni = @ScriptDir & "\Regex4AutoIt.ini"
Global $gExamples = @ScriptDir & "\Examples.ini"
Global $gHistoryFile = @ScriptDir & "\Regex4AutoIt_Records.ini"

; ---- 視窗樣式與 WebView2 ----
Global $gWindowFlags = BitOR($AUI_WIN_FIXED, $AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX)
Global $gCanWeb = False ; 是否可使用 WebView2

; ---- 主視窗控制項 ----
Global $gWnd = 0, $gStatus = 0
Global $gPresets = 0, $gReplacePresets = 0 ; 比對／取代範例下拉選單
Global $gPattern = 0, $gValidation = 0, $gFlag = 0 ; 模式輸入、編譯檢查訊息、Flag 選單
Global $gSource = 0, $gReplacement = 0, $gReplaceFlag = 0 ; 測試文字、取代內容、取代次數
Global $gSyntax = 0, $gSyntaxMenu = 0, $gExportMenu = 0 ; AU3 語法列與其選單
Global $gHistory = 0, $gRecordPrev = 0, $gRecordNext = 0 ; 最近使用與收藏
Global $gOutput = 0, $gColorPreview = 0, $gNativePreview = 0, $gColorMenu = 0
Global $gFileButton = 0, $gFileMenu = 0

; ---- 即時更新狀態 ----
Global $gTimer = 0, $gDirty = True, $gDirtyAt = TimerInit() ; 輸入變動後延遲 300 ms 重新計算
Global $gBusy = False, $gLoading = False, $gAutoRun = False ; $gLoading 為真時忽略控制項事件
Global $gState = "" ; 上次的輸入狀態快照
Global $gLastReplace = False ; 目前是「取代」模式還是「比對」模式
Global $gResultText = "", $gGeneratedCode = ""

; ---- WebView 彩色預覽（非同步執行腳本） ----
Global $gPreviewHtml = "", $gPreviewPending = True
Global $gWebReq = 0, $gWebVersion = 0, $gWebSent = 0, $gWebFails = 0, $gWebClock = TimerInit()

; ---- 語法說明視窗 ----
Global $gHelpWindow = 0, $gHelpWeb = 0, $gHelpText = 0, $gHelpHtml = "", $gHelpPending = False
Global $gHelpReq = 0, $gHelpVersion = 0, $gHelpSent = 0, $gHelpFails = 0, $gHelpClock = TimerInit()

; ---- 範例 ----
Global $gMatchRows[1][2], $gReplaceRows[1][3], $gMatchCount = 0, $gReplaceCount = 0
Global $gEditWindow = 0, $gEditText = 0, $gEditStatus = 0, $gEditOriginal = "", $gEditCloseDialog = 0, $gEditDiscard = False

; ---- 最近使用與收藏 ----
Global $gHistoryCount = 0, $gFavoriteCount = 0
Global $gRecordEntries[1][3], $gRecordEntryCount = 0 ; 全部項目：[標籤, 區段, 索引]，從 1 起算
Global $gRecordMap[1][2], $gRecordMapCount = 0 ; 目前頁面：下拉選單索引 → [區段, 索引]
Global $gRecordPage = 0, $gRecordPageSize = 12

; ---- 外觀設定 ----
Global $gFontName = "Microsoft JhengHei", $gFontPercent = 100, $gEditorPixels = 12
Global $gTheme = 0, $gThemeNames = "SciTE 經典|清晰高對比|海洋藍|森林綠|柔和紫"
Global $gClipColors[16], $gClipBold[16], $gClipItalic[16] ; 複製 AU3 時使用的 SciTE 樣式
Global $gAllFontIds[1], $gAllFontCount = 0, $gFontDiagnostic = ""

; ---- 設定視窗 ----
Global $gSettingsWindow = 0, $gThemeCombo = 0, $gFontInput = 0, $gSettingsSize = 0, $gEditorInput = 0
Global $gAutoItPathInput = 0, $gSettingsSavePending = False, $gAutoItExe = ""

; ---- 測試檔案 ----
Global $gLoadDialog = 0, $gLoadPath = "", $gLoadValues[6], $gSessionPath = "", $gSavingTest = False

#EndRegion

#Region ;===== 程式進入點 =====

_UI_Init()
$gCanWeb = (_UI_WebViewIsRuntimeInstalled() <> 0)
For $i = 1 To $CmdLine[0]
    If StringLower($CmdLine[$i]) = "/nowebview" Then $gCanWeb = False
    If StringLower($CmdLine[$i]) = "/noacrylic" Then $gWindowFlags = BitOR($AUI_WIN_FIXED, $AUI_WIN_NO_MINMAX)
Next
BuildMainWindow()
LoadPresets()
LoadSettings()
LoadRecords()
_UI_WindowShow($gWnd)
$gTimer = _UI_TimerStart($gWnd, 150, "OnTick", True) ; 每 150 ms 檢查輸入變動並更新 WebView
MarkDirty()
_UI_Run()

#EndRegion

#Region ;===== 主畫面建立 =====

; ----------------------------------------------------------------------------
; 建立主視窗、所有控制項與事件綁定。
; 版面為固定座標（960×760），WebView2 不可用時預覽區改用原生文字框。
; ----------------------------------------------------------------------------
Func BuildMainWindow()
    $gWnd = _UI_WindowCreateEx($APP_NAME & " v" & $APP_VERSION & "｜AutoIt 正規表示式測試工具", 0, 0, 960, 760, $gWindowFlags)
    If $gWnd = 0 Then Exit MsgBox(16, $APP_NAME, "無法建立 AUI 主視窗。")
    _UI_WindowCenter($gWnd)
    _UI_WindowSetIcon($gWnd, @ScriptDir & '\edit.ico')

    ; ---- 第 1 列：範例選單 ----
    $gPresets = _UI_Combo($gWnd, 0, "", -1, 16, 56, 390, 32)
    $gReplacePresets = _UI_Combo($gWnd, 0, "", -1, 416, 56, 320, 32)
    Local $bEdit = _UI_Button($gWnd, 0, "編輯範例", $AUI_VAR_DEFAULT, 746, 56, 94, 32)
    Local $bReload = _UI_Button($gWnd, 0, "重載 INI", $AUI_VAR_DEFAULT, 850, 56, 94, 32)

    ; ---- 輸入區：模式、Flag、測試文字、取代內容 ----
    $gPattern = _UI_TextArea($gWnd, 0, "正規表示式｜直接輸入，不加外層引號", "(?i)([a-z]+)\s+(\d+)", 16, 100, 928, 58)
    $gValidation = _UI_Text($gWnd, 0, "", 16, 164, 680, 24)
    $gFlag = _UI_Combo($gWnd, 0, "0 - 是否符合|1 - 首筆擷取|2 - 首筆完整＋群組|3 - 全域一維|4 - 全域群組", 4, 706, 164, 238, 28)
    $gSource = _UI_TextArea($gWnd, 0, "測試文字｜停止輸入後自動更新", "Hello 123" & @CRLF & "World 456", 16, 202, 928, 110)
    $gReplacement = _UI_Input($gWnd, 0, "取代內容｜$1 或 \\1；空字串表示刪除", "$2 - $1", 16, 324, 704, 34)
    $gReplaceFlag = _UI_Input($gWnd, 0, "取代次數｜0＝全部", "0", 730, 324, 214, 34)
    $gSyntax = _UI_Input($gWnd, 0, "AU3 語法｜右鍵複製單行／完整豐富文字", "", 16, 370, 928, 40)
    _UI_EditSetReadOnly($gWnd, $gSyntax, True)
    $gSyntaxMenu = _UI_ContextMenu($gWnd, $gSyntax, "複製單行 AU3（彩色）|複製完整 AU3（彩色）")

    ; ---- 動作按鈕 ----
    Local $bMatch = _UI_Button($gWnd, 0, "比對", $AUI_VAR_PRIMARY, 16, 422, 177, 34)
    Local $bReplace = _UI_Button($gWnd, 0, "取代", $AUI_VAR_DEFAULT, 203, 422, 177, 34)
    Local $bBatch = _UI_Button($gWnd, 0, "逐行比對", $AUI_VAR_DEFAULT, 390, 422, 177, 34)
    Local $bExport = _UI_Button($gWnd, 0, "匯出 AU3 / 執行 AU3", $AUI_VAR_DEFAULT, 577, 422, 177, 34)
    $gExportMenu = _UI_ContextMenu($gWnd, $bExport, "匯出 AU3|執行 AU3")
    Local $bClear = _UI_Button($gWnd, 0, "清除結果", $AUI_VAR_DEFAULT, 764, 422, 180, 34)

    ; ---- 最近使用與收藏（分頁） ----
    $gHistory = _UI_Combo($gWnd, 0, "", -1, 16, 468, 338, 32)
    $gRecordPrev = _UI_Button($gWnd, 0, "◀", $AUI_VAR_DEFAULT, 362, 468, 38, 32)
    $gRecordNext = _UI_Button($gWnd, 0, "▶", $AUI_VAR_DEFAULT, 404, 468, 38, 32)
    Local $bHistory = _UI_Button($gWnd, 0, "載入", $AUI_VAR_DEFAULT, 450, 468, 90, 32)
    Local $bFavorite = _UI_Button($gWnd, 0, "收藏", $AUI_VAR_DEFAULT, 548, 468, 90, 32)
    Local $bDelete = _UI_Button($gWnd, 0, "刪除", $AUI_VAR_DEFAULT, 646, 468, 90, 32)
    Local $bClearHistory = _UI_Button($gWnd, 0, "清除最近紀錄", $AUI_VAR_DEFAULT, 744, 468, 200, 32)

    ; ---- 結果區與彩色預覽（無 WebView2 時改用原生文字框） ----
    $gOutput = _UI_TextArea($gWnd, 0, "執行結果｜右鍵複製", "", 16, 512, 542, 190)
    _UI_EditSetReadOnly($gWnd, $gOutput, True)
    Local $resultMenu = _UI_ContextMenu($gWnd, $gOutput, "複製結果")
    If $gCanWeb Then $gColorPreview = _UI_WebView($gWnd, 0, "about:blank", 570, 512, 374, 190)
    If $gColorPreview = 0 Then
        $gNativePreview = _UI_TextArea($gWnd, 0, "正規表示式文字預覽（無 WebView2）", "", 570, 512, 374, 190)
        _UI_EditSetReadOnly($gWnd, $gNativePreview, True)
    EndIf
    Local $preview = $gColorPreview
    If $preview = 0 Then $preview = $gNativePreview
    $gColorMenu = _UI_ContextMenu($gWnd, $preview, $COLOR_MENU_ITEMS)

    ; ---- 底部狀態列與圖示按鈕 ----
    $gStatus = _UI_Text($gWnd, 0, "", 28, 720, 580, 28)
    $gFileButton = _UI_Button($gWnd, 0, "測試檔案", $AUI_VAR_DEFAULT, 634, 710, 144, 40)
    $gFileMenu = _UI_ContextMenu($gWnd, $gFileButton, "儲存測試 TXT|讀取測試 TXT")
    ; 底部列刻意不設工具提示，避免在 WebView 上方觸發覆蓋層重繪
    Local $bHelp = _UI_IconButton($gWnd, 0, ChrW(0x2754), "", 802, 710, 44, 40)
    Local $bSettings = _UI_IconButton($gWnd, 0, ChrW(0x2699), "", 850, 710, 44, 40)
    Local $bAbout = _UI_IconButton($gWnd, 0, ChrW(0x2755), "", 898, 710, 44, 40)
    _UI_TooltipSetText($gWnd, $bSettings, '設定')
    _UI_TooltipSetText($gWnd, $bHelp, '幫助')
    _UI_TooltipSetText($gWnd, $bAbout, '關於')
    _UI_TooltipClear($gWnd, $gFileButton)
    _UI_TooltipSetText($gWnd, $gPresets, "比對範例，可編輯 Examples.ini；不存在時自動建立")
    _UI_TooltipSetText($gWnd, $gReplacePresets, "取代範例，空取代內容表示刪除")
    _UI_TooltipSetText($gWnd, $gFlag, "Flag 4：每筆 [0] 為完整比對，其後為擷取群組")
    _UI_TooltipSetText($gWnd, $gReplaceFlag, "0～1000000；0 表示全部取代")

    ; ---- 登記需要套用字型設定的控制項 ----
    Local $ids[23] = [$gPresets, $gReplacePresets, $gPattern, $gValidation, $gFlag, $gSource, $gReplacement, $gReplaceFlag, $gSyntax, $gHistory, $gOutput, $gStatus, $gFileButton, $bEdit, $bReload, $bMatch, $bReplace, $bBatch, $bExport, $bClear, $bHistory, $bFavorite, $bDelete]
    For $i = 0 To UBound($ids) - 1
        RegisterFontId($ids[$i])
    Next
    RegisterFontId($bClearHistory)
    RegisterFontId($gRecordPrev)
    RegisterFontId($gRecordNext)
    If $gNativePreview <> 0 Then RegisterFontId($gNativePreview)

    ; ---- 事件綁定 ----
    _UI_OnClick($gWnd, $bEdit, "OnEditExamples")
    _UI_OnClick($gWnd, $bReload, "OnReloadExamples")
    _UI_OnClick($gWnd, $bMatch, "OnMatch")
    _UI_OnClick($gWnd, $bReplace, "OnReplace")
    _UI_OnClick($gWnd, $bBatch, "OnBatch")
    _UI_OnClick($gWnd, $bExport, "OnExportMenu")
    _UI_OnValue($gWnd, $gExportMenu, "OnExportSelected")
    _UI_OnClick($gWnd, $bClear, "OnClear")
    _UI_OnClick($gWnd, $bHistory, "OnLoadHistory")
    _UI_OnClick($gWnd, $gRecordPrev, "OnRecordPageClick")
    _UI_OnClick($gWnd, $gRecordNext, "OnRecordPageClick")
    _UI_OnClick($gWnd, $bFavorite, "OnAddFavorite")
    _UI_OnClick($gWnd, $bDelete, "OnDeleteRecord")
    _UI_OnClick($gWnd, $bClearHistory, "OnClearHistory")
    _UI_OnClick($gWnd, $bSettings, "OnOpenSettings")
    _UI_OnClick($gWnd, $bHelp, "OnHelp")
    _UI_OnClick($gWnd, $bAbout, "OnAbout")
    _UI_OnClick($gWnd, $gFileButton, "OpenFileMenu")
    _UI_OnValue($gWnd, $gFileMenu, "FileMenuSelected")
    _UI_OnValue($gWnd, $resultMenu, "OnCopyResult")
    _UI_OnValue($gWnd, $gSyntaxMenu, "OnSyntaxMenu")
    _UI_OnValue($gWnd, $gColorMenu, "OnColorMenu")
    _UI_OnValue($gWnd, $gPresets, "OnPresetChange")
    _UI_OnValue($gWnd, $gReplacePresets, "OnReplacePresetChange")
    _UI_OnValue($gWnd, $gFlag, "OnFlagChange")
    _UI_OnChange($gWnd, $gPattern, "OnPatternChange")
    _UI_OnChange($gWnd, $gSource, "OnSyntaxChanged")
    _UI_OnChange($gWnd, $gReplacement, "OnReplacementChanged")
    _UI_OnChange($gWnd, $gReplaceFlag, "OnReplaceFlagChange")
    _UI_OnClose($gWnd, "OnExit")
    If $gColorPreview <> 0 Then _UI_WebViewOnTabLoading($gWnd, $gColorPreview, "OnWebLoading")
EndFunc

; ----------------------------------------------------------------------------
; 主視窗關閉：停止計時器、釋放 WebView 非同步請求並儲存設定。
; ----------------------------------------------------------------------------
Func OnExit($wnd)
    If $gTimer > 0 Then _UI_TimerStop($wnd, $gTimer)
    If $gWebReq > 0 And $gColorPreview <> 0 Then _UI_WebViewResultRelease($wnd, $gColorPreview, $gWebReq)
    SaveSettings()
EndFunc

#EndRegion

#Region ;===== 主畫面事件 =====

; ----------------------------------------------------------------------------
; 模式輸入變動：標記需重新計算（實際更新由 OnTick 延遲執行）。
; ----------------------------------------------------------------------------
Func OnPatternChange($id, $value)
    If $gLoading Then Return

    MarkDirty()
EndFunc

; ----------------------------------------------------------------------------
; 測試文字變動：標記需重新計算。
; ----------------------------------------------------------------------------
Func OnSyntaxChanged($id, $value)
    If $gLoading Then Return

    MarkDirty()
EndFunc

; ----------------------------------------------------------------------------
; 取代內容變動：切換為取代模式並標記需重新計算。
; ----------------------------------------------------------------------------
Func OnReplacementChanged($id, $value)
    If $gLoading Then Return
    $gLastReplace = True
    MarkDirty()
EndFunc

; ----------------------------------------------------------------------------
; Flag 下拉選單變動：寫入 INI、切換為比對模式並重新計算。
; ----------------------------------------------------------------------------
Func OnFlagChange($id, $value)
    If $gLoading Then Return
    Local $iFlag = _UI_ComboGetSelected($gWnd, $gFlag)
    If $iFlag >= 0 And $iFlag <= 4 Then _IniWrite($gIni, "Regex", "MatchFlag", String($iFlag), 256)
    $gLastReplace = False
    MarkDirty()
EndFunc

; ----------------------------------------------------------------------------
; 取代次數變動：合法時（0～1000000）寫入 INI，切換為取代模式。
; ----------------------------------------------------------------------------
Func OnReplaceFlagChange($id, $value)
    If $gLoading Then Return
    Local $sCount = StringStripWS(_UI_GetText($gWnd, $gReplaceFlag), 3)
    If StringRegExp($sCount, "^\d{1,7}$") And Number($sCount) <= 1000000 Then _IniWrite($gIni, "Regex", "ReplaceCount", $sCount, 256)
    $gLastReplace = True
    MarkDirty()
EndFunc

; ----------------------------------------------------------------------------
; 選取比對範例：把範例模式填入輸入框，並清除取代範例的選取。
; ----------------------------------------------------------------------------
Func OnPresetChange($id, $value)
    If $gLoading Then Return
    Local $i = _UI_ComboGetSelected($gWnd, $gPresets)
    If $i < 0 Or $i >= $gMatchCount Then Return
    $gLoading = True
    $gLastReplace = False
    SetPatternText($gMatchRows[$i][1])
    _UI_ComboSetSelected($gWnd, $gReplacePresets, -1)
    $gLoading = False
    MarkDirty()
EndFunc

; ----------------------------------------------------------------------------
; 選取取代範例：填入模式與取代內容，保留目前的取代次數。
; ----------------------------------------------------------------------------
Func OnReplacePresetChange($id, $value)
    If $gLoading Then Return
    Local $i = _UI_ComboGetSelected($gWnd, $gReplacePresets)
    If $i < 0 Or $i >= $gReplaceCount Then Return
    $gLoading = True
    $gLastReplace = True
    SetPatternText($gReplaceRows[$i][1])
    _UI_SetText($gWnd, $gReplacement, $gReplaceRows[$i][2])
    ; 切換取代範例時保留上次設定的取代次數。
    _UI_ComboSetSelected($gWnd, $gPresets, -1)
    $gLoading = False
    MarkDirty()
EndFunc

; ----------------------------------------------------------------------------
; 「比對」按鈕：執行 StringRegExp，並更新 AU3 語法列與彩色預覽。
; ----------------------------------------------------------------------------
Func OnMatch($id)
    $gLastReplace = False
    RunResult(False)
    UpdateSyntax(False)
    UpdatePreview()
EndFunc

; ----------------------------------------------------------------------------
; 「取代」按鈕：執行 StringRegExpReplace，並更新 AU3 語法列與彩色預覽。
; ----------------------------------------------------------------------------
Func OnReplace($id)
    $gLastReplace = True
    RunResult(True)
    UpdateSyntax(True)
    UpdatePreview()
EndFunc

; ----------------------------------------------------------------------------
; 「逐行比對」按鈕：將測試文字逐行獨立比對（Flag 0），列出每行是否符合。
; ----------------------------------------------------------------------------
Func OnBatch($id)
    Local $sP = GetPatternText()
    If $sP = "" Then Return
    Local $aLines = StringSplit(StringReplace(_UI_GetText($gWnd, $gSource), @CRLF, @LF), @LF, 1)
    Local $sOut = "逐行批次比對（每一行獨立執行）" & @CRLF, $nPass = 0
    For $i = 1 To $aLines[0]
        Local $v = StringRegExp($aLines[$i], $sP, 0)
        Local $e = @error
        If $e = 2 Then
            $sOut &= "正規表示式編譯失敗，@error=2" & @CRLF
            ExitLoop
        EndIf
        If $v Then $nPass += 1
        $sOut &= "第 " & $i & " 行：" & ($v ? "符合" : "不符合") & "　" & $aLines[$i] & @CRLF
    Next
    $sOut &= "符合 " & $nPass & " / " & $aLines[0] & " 行"
    _UI_SetText($gWnd, $gOutput, $sOut)
    HighlightOutput($sOut)
    RememberPattern()
    $gDirty = False
EndFunc

; ----------------------------------------------------------------------------
; 「清除結果」按鈕：清空結果區。
; ----------------------------------------------------------------------------
Func OnClear($id)
    RenderResult("", 0xFFEEEEEE, "已清除結果")
    $gDirty = False
EndFunc

; ----------------------------------------------------------------------------
; 結果區右鍵「複製結果」：複製最後一次的結果文字。
; ----------------------------------------------------------------------------
Func OnCopyResult($id, $value = 0)
    ClipPut($gResultText)
EndFunc

; ----------------------------------------------------------------------------
; AU3 語法列右鍵選單。
; $value：0＝複製單行（彩色）；1＝複製完整程式（彩色）
; ----------------------------------------------------------------------------
Func OnSyntaxMenu($id, $value)
    CopyAu3Rich(Number($value) = 1)
EndFunc

; ----------------------------------------------------------------------------
; 彩色預覽右鍵選單（項目見 $COLOR_MENU_ITEMS）。
; $value：0／3＝Discuz! BBCode　1／4＝HTML　2／5＝Word 彩色文字；3 以上附加模式解析說明
; ----------------------------------------------------------------------------
Func OnColorMenu($id, $value)
    Local $iChoice = Number($value)
    Local $sInfo = ""
    If $iChoice >= 3 Then $sInfo = @CRLF & @CRLF & BuildPatternExplanation()
    ; 0／3＝Discuz!　1／4＝HTML　2／5＝Word 彩色文字；3 以上附加解析說明
    Switch Mod($iChoice, 3)
        Case 0
            ClipPut(BuildColoredLine(True) & $sInfo)
        Case 1
            Local $sHtml = BuildColoredHTML()
            If $sInfo <> "" Then $sHtml &= "<div style=""margin-top:14px;line-height:1.8;color:#333"">" & _RegexExplanationHTML(StringStripWS($sInfo, 1)) & "</div>"
            ClipPut($sHtml)
        Case 2
            OnCopyWordRich($id, $iChoice >= 3)
    EndSwitch
    _UI_SetText($gWnd, $gStatus, "已執行彩色正規表示式複製選單。")
EndFunc

; ----------------------------------------------------------------------------
; 「匯出 AU3 / 執行 AU3」按鈕：在按鈕下方顯示選單。
; ----------------------------------------------------------------------------
Func OnExportMenu($id)
    _UI_ContextMenuShowAt($gWnd, $gExportMenu, 577, 456)
EndFunc

; ----------------------------------------------------------------------------
; 匯出選單：0＝匯出 AU3 檔；1＝以 AutoIt3.exe 直接執行。
; ----------------------------------------------------------------------------
Func OnExportSelected($id, $value)
    Switch Int($value)
        Case 0
            OnExportCode($id)
        Case 1
            OnRunCode($id)
    EndSwitch
EndFunc

#EndRegion

#Region ;===== 即時更新與執行 =====

; ----------------------------------------------------------------------------
; 標記輸入已變動，並記錄變動時間（供 OnTick 防抖動使用）。
; ----------------------------------------------------------------------------
Func MarkDirty()
    $gDirty = True
    $gDirtyAt = TimerInit()
EndFunc

; ----------------------------------------------------------------------------
; 計時器（150 ms）：偵測輸入變動，停止輸入 300 ms 後自動驗證、產生語法、執行比對，
; 並推動 WebView 的非同步更新。
; ----------------------------------------------------------------------------
Func OnTick($wnd, $timer)
    If $gBusy Or $gLoading Then Return
    ; 以所有輸入組成狀態字串，偵測任何變動
    Local $state = PackText(GetPatternText()) & ":" & PackText(_UI_GetText($gWnd, $gSource)) & ":" & PackText(_UI_GetText($gWnd, $gReplacement)) & ":" & _UI_ComboGetSelected($gWnd, $gFlag) & ":" & _UI_GetText($gWnd, $gReplaceFlag) & ":" & $gLastReplace
    If $state <> $gState Then
        $gState = $state
        MarkDirty()
    EndIf
    ; 停止輸入 300 ms 後才重新計算（防抖動）
    If $gDirty And TimerDiff($gDirtyAt) >= 300 Then
        $gBusy = True
        $gDirty = False
        ValidatePattern()
        UpdateSyntax($gLastReplace)
        UpdatePreview()
        ; 內容過大時不自動執行，避免卡住介面
        If StringLen(_UI_GetText($gWnd, $gSource)) <= 200000 And StringLen(GetPatternText()) <= 10000 Then
            $gAutoRun = True
            RunResult($gLastReplace)
            $gAutoRun = False
        Else
            RenderResult("超過即時更新大小限制，請手動執行。", 0xFFFFCC66, "請手動執行")
        EndIf
        $gBusy = False
    EndIf
    RefreshWebViews()
EndFunc

; ----------------------------------------------------------------------------
; 以空字串試編譯模式，於模式下方顯示「PCRE 編譯通過／失敗位置」。
; 回傳：True＝模式有效
; ----------------------------------------------------------------------------
Func ValidatePattern()
    If GetPatternText() = "" Then
        _UI_SetText($gWnd, $gValidation, "空模式有效，可能產生空比對")
        _UI_SetColor($gWnd, $gValidation, 0, 0xFFFFCC66)
        Return True
    EndIf
    Local $v = StringRegExp("", GetPatternText(), 0), $e = @error, $x = @extended
    _UI_SetText($gWnd, $gValidation, ($e = 2 ? "PCRE 編譯失敗｜位置=" & $x : "PCRE 編譯通過"))
    _UI_SetColor($gWnd, $gValidation, 0, ($e = 2 ? 0xFFFF7777 : 0xFF55E39C))
    Return $e <> 2
EndFunc

; ----------------------------------------------------------------------------
; 執行比對或取代，並把結果顯示於結果區。
; $replace：True＝StringRegExpReplace；False＝StringRegExp（依目前 Flag）
; ----------------------------------------------------------------------------
Func RunResult($replace)
    Local $pattern = GetPatternText(), $source = _UI_GetText($gWnd, $gSource), $v, $e, $x, $time = TimerInit()
    If $replace Then
        Local $count = CountValue()
        If @error Then Return RenderResult("取代次數必須為 0～1000000。", 0xFFFF7777, "設定錯誤")
        $v = StringRegExpReplace($source, $pattern, _UI_GetText($gWnd, $gReplacement), $count)
        $e = @error
        $x = @extended
        If $e Then
            RenderResult("取代失敗｜@error=" & $e & "｜@extended=" & $x, 0xFFFF7777, "取代失敗")
        Else
            RenderResult($v, ($x ? 0xFF55E39C : 0xFFFFCC66), "取代完成｜" & $x & " 處｜" & Round(TimerDiff($time), 2) & " ms")
        EndIf
    Else
        Local $flag = _UI_ComboGetSelected($gWnd, $gFlag)
        $v = StringRegExp($source, $pattern, $flag)
        $e = @error
        $x = @extended
        If $e = 2 Then
            RenderResult("正規表示式錯誤，位置=" & $x, 0xFFFF7777, "模式錯誤")
        ElseIf $e = 1 Then
            RenderResult("沒有符合項目。", 0xFFFFCC66, "沒有符合項目")
        ElseIf $flag = 0 Then
            RenderResult("是否符合：" & $v, ($v ? 0xFF55E39C : 0xFFFFCC66), ($v ? "找到符合項目" : "沒有符合項目"))
        Else
            Local $text = "# Flag " & $flag & @CRLF & ArrayText($v)
            If $flag = 3 Then $text &= @CRLF & "有擷取群組時，陣列元素數不等於比對筆數。"
            RenderResult($text, 0xFF55E39C, "比對完成｜" & Round(TimerDiff($time), 2) & " ms")
        EndIf
    EndIf
    ; 只有手動執行且成功時才寫入最近紀錄
    If Not $gAutoRun And $e = 0 Then RememberPattern()
EndFunc

; ----------------------------------------------------------------------------
; 讀取並驗證取代次數。
; 回傳：0～1000000；不合法時回傳 -1 並設 @error=1
; ----------------------------------------------------------------------------
Func CountValue()
    Local $s = StringStripWS(_UI_GetText($gWnd, $gReplaceFlag), 3)
    If Not StringRegExp($s, "^\d{1,7}$") Or Number($s) > 1000000 Then Return SetError(1, 0, -1)
    Return SetError(0, 0, Number($s))
EndFunc

; ----------------------------------------------------------------------------
; 遞迴將 StringRegExp 回傳的陣列（含 Flag 4 的巢狀陣列）轉為可讀文字。
; $prefix：目前的索引路徑，例如 "[0][1]"
; ----------------------------------------------------------------------------
Func ArrayText($v, $prefix = "")
    Local $text = ""
    If IsArray($v) Then
        For $i = 0 To UBound($v) - 1
            If IsArray($v[$i]) Then $text &= "# 比對 [" & $i & "]：[0] 完整比對，其後為群組" & @CRLF
            $text &= ArrayText($v[$i], $prefix & "[" & $i & "]")
        Next
    Else
        $text = $prefix & " " & String($v) & @CRLF
    EndIf
    Return $text
EndFunc

; ----------------------------------------------------------------------------
; 把文字寫入結果區，並設定整體／逐行顏色與狀態列訊息。
; $color：ARGB 顏色（綠＝成功、黃＝無符合、紅＝錯誤）
; ----------------------------------------------------------------------------
Func RenderResult($text, $color, $status)
    $gResultText = $text
    _UI_BeginUpdate($gWnd)
    _UI_TextAreaClearLineColors($gWnd, $gOutput)
    _UI_SetText($gWnd, $gOutput, $text)
    _UI_SetColor($gWnd, $gOutput, 0xFF242424, $color)
    Local $lines = StringSplit(StringReplace(StringReplace($text, @CRLF, @LF), @CR, @LF), @LF, 1)
    For $i = 1 To _Min($lines[0], 5000)
        Local $c = $color
        ; 成功結果中以 "# " 開頭的標題行改用藍色
        If $color = 0xFF55E39C And StringLeft($lines[$i], 2) = "# " Then $c = 0xFF87BDFF
        _UI_TextAreaSetLineColor($gWnd, $gOutput, $i - 1, $c)
    Next
    _UI_SetText($gWnd, $gStatus, $status)
    _UI_SetColor($gWnd, $gStatus, 0, $color)
    _UI_EndUpdate($gWnd)
EndFunc

; ----------------------------------------------------------------------------
; 逐行比對結果上色：符合＝綠、不符合＝黃、失敗＝紅。
; ----------------------------------------------------------------------------
Func HighlightOutput($text)
    $gResultText = $text
    _UI_TextAreaClearLineColors($gWnd, $gOutput)
    _UI_SetColor($gWnd, $gOutput, 0xFF242424, 0xFFEEEEEE)
    Local $lines = StringSplit(StringReplace($text, @CRLF, @LF), @LF, 1)
    For $i = 1 To _Min($lines[0], 5000)
        Local $c = 0xFFEEEEEE
        If StringInStr($lines[$i], "符合") Then $c = 0xFF55E39C
        If StringInStr($lines[$i], "不符合") Then $c = 0xFFFFCC66
        If StringInStr($lines[$i], "失敗") Then $c = 0xFFFF7777
        _UI_TextAreaSetLineColor($gWnd, $gOutput, $i - 1, $c)
    Next
EndFunc

; ----------------------------------------------------------------------------
; 取得目前的正規表示式（原樣，不加外層引號）。
; ----------------------------------------------------------------------------
Func GetPatternText()
    Return _UI_GetText($gWnd, $gPattern)
EndFunc

; ----------------------------------------------------------------------------
; 設定正規表示式輸入框內容。
; ----------------------------------------------------------------------------
Func SetPatternText($sValue)
    _UI_SetText($gWnd, $gPattern, $sValue)
EndFunc

#EndRegion

#Region ;===== AU3 程式碼產生／匯出／執行 =====

; ----------------------------------------------------------------------------
; 把任意文字轉為 AutoIt 字串運算式：雙引號加倍，CR／LF／Tab 改用 @CR／@LF／@TAB 串接。
; 反斜線維持原樣（AutoIt 字串不處理跳脫）。
; ----------------------------------------------------------------------------
Func Au3TextExpression($s)
    Local $q = Chr(34)
    $s = StringReplace($s, $q, $q & $q)
    $s = StringReplace($s, @CR, $q & " & @CR & " & $q)
    $s = StringReplace($s, @LF, $q & " & @LF & " & $q)
    $s = StringReplace($s, @TAB, $q & " & @TAB & " & $q)
    Return $q & $s & $q
EndFunc

; ----------------------------------------------------------------------------
; 依目前模式產生單行 AU3 呼叫語法，顯示於語法列。
; $bReplace：True＝StringRegExpReplace；False＝StringRegExp
; ----------------------------------------------------------------------------
Func UpdateSyntax($bReplace = True)
    $gLastReplace = $bReplace
    Local $sP = Au3TextExpression(GetPatternText())
    Local $sCode = ""
    If $bReplace Then
        Local $sR = Au3TextExpression(_UI_GetText($gWnd, $gReplacement))
        Local $sN = StringStripWS(_UI_GetText($gWnd, $gReplaceFlag), 3)
        If Not StringRegExp($sN, "^\d+$") Then
            $sCode = "取代次數需輸入非負整數"
        ElseIf Number($sN) = 0 Then
            $sCode = "StringRegExpReplace($sInput, " & $sP & ", " & $sR & ")"
        Else
            $sCode = "StringRegExpReplace($sInput, " & $sP & ", " & $sR & ", " & $sN & ")"
        EndIf
    Else
        $sCode = "StringRegExp($sInput, " & $sP & ", " & _UI_ComboGetSelected($gWnd, $gFlag) & ")"
    EndIf
    ; 主畫面固定顯示單行語法；完整程式由右鍵選單產生。
    $gGeneratedCode = $sCode
    _UI_SetText($gWnd, $gSyntax, $gGeneratedCode)
EndFunc

; ----------------------------------------------------------------------------
; 產生可直接執行的完整 AU3 範例程式（含測試文字與 MsgBox 顯示結果）。
; 回傳：以 Tab 縮排的程式碼字串
; ----------------------------------------------------------------------------
Func BuildFullCode($bReplace)
    Local $sText = _UI_GetText($gWnd, $gSource)
    Local $sPattern = Au3TextExpression(GetPatternText())
    Local $sCode = "Local $text = " & Au3TextExpression($sText) & @CRLF
    If $bReplace Then
        Local $sR = Au3TextExpression(_UI_GetText($gWnd, $gReplacement))
        Local $sN = StringStripWS(_UI_GetText($gWnd, $gReplaceFlag), 3)
        If Not StringRegExp($sN, "^\d+$") Then Return "; 錯誤：取代次數必須是非負整數"
        $sCode &= "Local $val = StringRegExpReplace($text, " & $sPattern & ", " & $sR
        If Number($sN) <> 0 Then $sCode &= ", " & $sN
        $sCode &= ")" & @CRLF
        $sCode &= "Local $iError = @error, $iCount = @extended" & @CRLF
        $sCode &= 'MsgBox(64, "正規表示式取代結果 / 取代次數=" & $iCount, $val & @CRLF & "@error=" & $iError)'
    Else
        Local $iFlag = _UI_ComboGetSelected($gWnd, $gFlag)
        $sCode &= "Local $val = StringRegExp($text, " & $sPattern & ", " & $iFlag & ")" & @CRLF
        $sCode &= "Local $iError = @error, $iExtended = @extended" & @CRLF
        $sCode &= "Local $sResult = String($val)" & @CRLF
        $sCode &= "If IsArray($val) Then" & @CRLF
        $sCode &= '    $sResult = ""' & @CRLF
        $sCode &= "    Local $aGroup" & @CRLF
        $sCode &= "    For $i = 0 To UBound($val) - 1" & @CRLF
        $sCode &= "        If IsArray($val[$i]) Then" & @CRLF
        $sCode &= "            $aGroup = $val[$i]" & @CRLF
        $sCode &= "            For $j = 0 To UBound($aGroup) - 1" & @CRLF
        $sCode &= '                $sResult &= "[" & $i & "][" & $j & "] " & $aGroup[$j] & @CRLF' & @CRLF
        $sCode &= "            Next" & @CRLF
        $sCode &= "        Else" & @CRLF
        $sCode &= '            $sResult &= "[" & $i & "] " & $val[$i] & @CRLF' & @CRLF
        $sCode &= "        EndIf" & @CRLF
        $sCode &= "    Next" & @CRLF
        $sCode &= "EndIf" & @CRLF
        $sCode &= 'MsgBox(64, "正規表示式比對結果", $sResult & @CRLF & "@error=" & $iError & " @extended=" & $iExtended)'
    EndIf
    Return _RegexIndentToTabs($sCode)
EndFunc

; ----------------------------------------------------------------------------
; 將文字重複 $iCount 次（AutoIt 無內建 StringRepeat）。
; ----------------------------------------------------------------------------
Func _RegexRepeatText($sText, $iCount)
    Local $sResult = ""
    For $j = 1 To $iCount
        $sResult &= $sText
    Next
    Return $sResult
EndFunc

; ----------------------------------------------------------------------------
; 把行首每 4 個空白轉為 1 個 Tab（由最深層開始，最多 6 層）。
; ----------------------------------------------------------------------------
Func _RegexIndentToTabs($sCode)
    ; 依序由最深層縮排轉換，避免只取代第一層。
    For $i = 6 To 1 Step -1
        $sCode = StringReplace($sCode, @CRLF & _RegexRepeatText(" ", $i * 4), @CRLF & _RegexRepeatText(@TAB, $i))
    Next
    Return $sCode
EndFunc

; ----------------------------------------------------------------------------
; 匯出完整 AU3 範例到使用者指定的 .au3 檔（UTF-8 BOM）。
; ----------------------------------------------------------------------------
Func OnExportCode($id)
    UpdateSyntax($gLastReplace)
    Local $sPath = FileSaveDialog("匯出 AU3 程式碼", @ScriptDir, "AutoIt 程式碼 (*.au3)", 16, "RegexExample.au3")
    If @error Or $sPath = "" Then Return
    If StringRight(StringLower($sPath), 4) <> ".au3" Then $sPath &= ".au3"
    Local $h = FileOpen($sPath, 2 + 128)
    If $h = -1 Then Return _UI_SetText($gWnd, $gStatus, "無法寫入檔案。")
    FileWrite($h, "#AutoIt3Wrapper_UseX64=n" & @CRLF & BuildFullCode($gLastReplace) & @CRLF)
    FileClose($h)
    _UI_SetText($gWnd, $gStatus, "已匯出可執行 AU3 範例：" & $sPath)
EndFunc

; ----------------------------------------------------------------------------
; 把完整 AU3 範例寫入暫存檔，並以設定中的 AutoIt3.exe 執行。
; ----------------------------------------------------------------------------
Func OnRunCode($id)
    Local $exe = StringStripWS($gAutoItExe, 3)
    If $exe = "" Or Not FileExists($exe) Then
        ShowMessage("尚未設定 AutoIt3.exe", "請先開啟設定，指定有效的 AutoIt3.exe 路徑。")
        Return
    EndIf
    If StringLower(StringRegExpReplace($exe, "^.*[\\/]", "")) <> "autoit3.exe" Then
        ShowMessage("執行檔不正確", "請選擇 AutoIt3.exe，不要選擇其他程式。")
        Return
    EndIf
    Local $file = @TempDir & "\Regex4AutoIt_" & @AutoItPID & "_Preview.au3"
    Local $h = FileOpen($file, 2 + 128)
    If $h = -1 Then
        ShowMessage("寫入失敗", "無法建立暫存 AU3 程式碼。")
        Return
    EndIf
    FileWrite($h, "#AutoIt3Wrapper_UseX64=n" & @CRLF & BuildFullCode($gLastReplace) & @CRLF)
    FileClose($h)
    Local $pid = Run('"' & $exe & '" "' & $file & '"', @ScriptDir)
    If @error Or $pid = 0 Then
        ShowMessage("執行失敗", "無法啟動 AutoIt3.exe，請檢查路徑及檔案權限。")
        Return
    EndIf
    _UI_SetText($gWnd, $gStatus, "已使用 AutoIt3.exe 執行範例（PID：" & $pid & "）")
EndFunc

#EndRegion

#Region ;===== PCRE 語法著色與解析 =====

; ----------------------------------------------------------------------------
; 回傳語法類別對應的顏色。
; $kind：0 一般 1 跳脫 2 群組 3 集合 4 量詞 5 錨點 6 註解 7 錯誤
; $dark：True＝深色背景用色；False＝淺色背景用色
; ----------------------------------------------------------------------------
Func RegexSyntaxColor($kind, $dark = True)
    Switch $kind
        Case 1 ; 跳脫字元／Unicode 屬性／反向參照
            Return ($dark ? "#4EC9B0" : "#16846B")
        Case 2 ; 群組／前瞻後顧／修飾符／控制動詞
            Return ($dark ? "#D9A1F3" : "#8E44AD")
        Case 3 ; 字元集合／POSIX 類別
            Return ($dark ? "#FFE28A" : "#A76B08")
        Case 4 ; 量詞
            Return ($dark ? "#FFBC8C" : "#C05621")
        Case 5 ; 錨點／分支／萬用字元
            Return ($dark ? "#87BDFF" : "#1565C0")
        Case 6 ; 註解 (?#...)
            Return ($dark ? "#6A9955" : "#397A3C")
        Case 7 ; 不完整的跳脫（模式結尾的反斜線）
            Return ($dark ? "#FF7777" : "#C62828")
    EndSwitch
    Return ($dark ? "#D4D4D4" : "#222222")
EndFunc

; ----------------------------------------------------------------------------
; PCRE 詞法掃描器：從 $pos 取出一個語法單元，並以 $kind 回傳語法類別。
; $inClass／$quoted 由呼叫端保存（是否位於 [...] 或 \Q...\E 內）。
; 僅用於著色，不判斷 PCRE 版本是否支援；真正的有效性由 ValidatePattern() 檢查。
; 回傳：語法單元字串
; ----------------------------------------------------------------------------
Func RegexNextToken($s, $pos, ByRef $inClass, ByRef $quoted, ByRef $kind)
    Local $n = StringLen($s), $ch = StringMid($s, $pos, 1), $tail = StringMid($s, $pos)
    Local $a
    $kind = 0
    If $quoted Then
        If StringLeft($tail, 2) = "\E" Then
            $quoted = False
            $kind = 1
            Return "\E"
        EndIf
        Return $ch
    EndIf
    If $ch = "\" Then
        If $pos = $n Then
            $kind = 7
            Return $ch
        EndIf
        If StringLeft($tail, 2) = "\Q" Then $quoted = True
        $a = StringRegExp($tail, '^\\(?:[pP]\{[^}]*\}|[pP]\w|[xX]\{[0-9A-Fa-f]+\}|x[0-9A-Fa-f]{2}|[uU][0-9A-Fa-f]{4,8}|[gk]\{[^}]+\}|k<[^>]+>|k''[^'']+''|[0-9]+|[cC].|.)', 1)
        $kind = 1
        If IsArray($a) Then Return $a[0]
        Return StringLeft($tail, 2)
    EndIf
    If $inClass Then
        If $ch = "]" Then
            $inClass = False
            $kind = 3
            Return $ch
        EndIf
        $a = StringRegExp($tail, '^\[[:.=][^\]]+[.:=]\]', 1)
        If IsArray($a) Then
            $kind = 3
            Return $a[0]
        EndIf
        $kind = 3
        Return $ch
    EndIf
    If $ch = "[" Then
        $inClass = True
        $kind = 3
        Return $ch
    EndIf
    If $ch = "(" Then
        If StringLeft($tail, 3) = "(?#" Then
            Local $endComment = StringInStr($s, ")", 0, 1, $pos + 3)
            $kind = 6
            If $endComment > 0 Then Return StringMid($s, $pos, $endComment - $pos + 1)
            Return $tail
        EndIf
        ; PCRE 控制動詞：(*SKIP)、(*FAIL)、(*MARK:label)、(*LIMIT_MATCH=...) 等
        $a = StringRegExp($tail, '^\(\*[A-Za-z_]+(?:[:=][^)]*)?\)', 1)
        If IsArray($a) Then
            $kind = 2
            Return $a[0]
        EndIf
        ; 行內修飾符、命名擷取、前瞻／後顧、原子群組、分支重設、
        ; 遞迴／子程序呼叫、條件式與 callout
        $a = StringRegExp($tail, '^\(\?(?:[A-Za-z]+(?:-[A-Za-z]+)?[):]|<[^>]+>|P<[^>]+>|P=[^)]+\)|''[^'']+''|<=|<!|=|!|:|>|\||\(|&[^)]+\)|R\)|[0-9+-]+\)|C[0-9]*\)|\*)', 1)
        If IsArray($a) Then
            $kind = 2
            Return $a[0]
        EndIf
        $kind = 2
        Return $ch
    EndIf
    If $ch = ")" Then
        $kind = 2
        Return $ch
    EndIf
    If $ch = "{" Then
        $a = StringRegExp($tail, '^\{[0-9]+(?:,[0-9]*)?\}[?+]?', 1)
        If IsArray($a) Then
            $kind = 4
            Return $a[0]
        EndIf
    EndIf
    If StringInStr("*+?", $ch) Then
        $a = StringRegExp($tail, '^[*+?][?+]?', 1)
        $kind = 4
        If IsArray($a) Then Return $a[0]
    EndIf
    If StringInStr("^$|.", $ch) Then $kind = 5
    Return $ch
EndFunc

; ----------------------------------------------------------------------------
; 把目前模式轉為彩色片段。
; $bDZ：True＝Discuz! [color] BBCode；False＝HTML <span>
; $bDark：是否使用深色背景配色
; ----------------------------------------------------------------------------
Func BuildColoredLine($bDZ = False, $bDark = False)
    Local $s = GetPatternText(), $out = "", $inClass = False, $quoted = False, $kind = 0, $i = 1
    While $i <= StringLen($s)
        Local $tok = RegexNextToken($s, $i, $inClass, $quoted, $kind)
        Local $color = RegexSyntaxColor($kind, $bDark)
        If $bDZ Then
            $out &= "[color=" & $color & "]" & $tok & "[/color]"
        Else
            $out &= '<span style="color:' & $color & '">' & EscapeHTML($tok) & '</span>'
        EndIf
        $i += StringLen($tok)
    WEnd
    Return $out
EndFunc

; ----------------------------------------------------------------------------
; 以 <code> 包裝的彩色模式 HTML（淺色配色，套用設定的字型與字級）。
; ----------------------------------------------------------------------------
Func BuildColoredHTML()
    Return '<code style="font-family:' & EscapeHTML($gFontName) & ',monospace;font-size:' & $gEditorPixels & 'px;white-space:pre-wrap;overflow-wrap:anywhere">' & BuildColoredLine(False) & '</code>'
EndFunc

; ----------------------------------------------------------------------------
; 以 HTML＋純文字格式複製彩色模式，貼到 Word 會保留顏色。
; $withLegend：是否附加模式解析說明
; ----------------------------------------------------------------------------
Func OnCopyWordRich($id, $withLegend = False)
    Local $text = GetPatternText(), $html = BuildColoredHTML()
    If $withLegend Then
        $text &= @CRLF & @CRLF & BuildPatternExplanation()
        $html &= '<pre>' & EscapeHTML(BuildPatternExplanation()) & '</pre>'
    EndIf
    If RichClipboard($text, $html, "") Then _UI_SetText($gWnd, $gStatus, "已複製彩色正規表示式")
EndFunc

; ----------------------------------------------------------------------------
; 產生模式的靜態解析說明：模式修飾符、群組結構與使用到的語法。
; 並非完整的 PCRE 語法樹，複雜結構仍需以實際比對結果確認。
; ----------------------------------------------------------------------------
Func BuildPatternExplanation()
    ; 使用與 PCRE 上色相同的語法類別；跳過字元集合內容，避免把集合內的 * + ? 誤判為量詞。
    ; 逐字掃描；只負責產生說明，不判斷模式是否有效。
    Local $p = GetPatternText(), $n = StringLen($p), $i = 1
    Local $flags = "", $items = "", $groups = "", $count = 0
    Local $hasEscape = False, $hasGroup = False, $hasClass = False, $hasAnchor = False, $hasQuant = False
    Local $inClass = False, $inQuote = False
    While $i <= $n
        Local $c = StringMid($p, $i, 1), $rest = StringMid($p, $i), $tok = ""
        If $inQuote Then
            If StringLeft($rest, 2) = "\E" Then
                $inQuote = False
                $i += 2
            Else
                $i += 1
            EndIf
            ContinueLoop
        EndIf
        If $c = "\" Then
            If StringLeft($rest, 2) = "\Q" Then
                $hasEscape = True
                _RegexAddUniqueLine($items, "\Q...\E：中間的文字視為一般字面文字，不解讀特殊符號。")
                $inQuote = True
                $i += 2
                ContinueLoop
            EndIf
            If StringRegExp($rest, '^\\[pP]\{[^}]+\}') Then
                $tok = _RegexFirstMatch($rest, '^\\[pP]\{[^}]+\}')
                $hasEscape = True
                _RegexAddUniqueLine($items, $tok & "：依 Unicode 屬性比對字元（大寫 P 表示反向）。")
                $i += StringLen($tok)
                ContinueLoop
            EndIf
            If StringRegExp($rest, '^\\(?:k<[^>]+>|k''[^'']+''|g\{[^}]+\}|[1-9][0-9]*)') Then
                $tok = _RegexFirstMatch($rest, '^\\(?:k<[^>]+>|k''[^'']+''|g\{[^}]+\}|[1-9][0-9]*)')
                $hasEscape = True
                _RegexAddUniqueLine($items, $tok & "：反向參照，需與先前擷取的內容相符。")
                $i += StringLen($tok)
                ContinueLoop
            EndIf
            $hasEscape = True
            Local $esc = StringMid($p, $i + 1, 1)
            Switch $esc
                Case "d"
                    _RegexAddUniqueLine($items, "\d：數字字元。")
                Case "D"
                    _RegexAddUniqueLine($items, "\D：非數字字元。")
                Case "s"
                    _RegexAddUniqueLine($items, "\s：空白字元（包括空格、Tab、換行等）。")
                Case "S"
                    _RegexAddUniqueLine($items, "\S：非空白字元。")
                Case "w"
                    _RegexAddUniqueLine($items, "\w：單字字元，實際範圍受 PCRE 模式影響。")
                Case "W"
                    _RegexAddUniqueLine($items, "\W：非單字字元。")
                Case "b"
                    _RegexAddUniqueLine($items, "\b：單字邊界。")
                Case "B"
                    _RegexAddUniqueLine($items, "\B：非單字邊界。")
                Case "A"
                    _RegexAddUniqueLine($items, "\A：整個主題字串的開頭。")
                Case "z"
                    _RegexAddUniqueLine($items, "\z：整個主題字串的結尾。")
                Case "Z"
                    _RegexAddUniqueLine($items, "\Z：字串結尾或最後換行之前。")
                Case "G"
                    _RegexAddUniqueLine($items, "\G：目前比對起點。")
                Case "R"
                    _RegexAddUniqueLine($items, "\R：換行序列。")
                Case "h", "H", "v", "V"
                    _RegexAddUniqueLine($items, "\" & $esc & "：水平或垂直空白類別（大寫為反向）。")
                Case "K"
                    _RegexAddUniqueLine($items, "\K：重設回報的完整符合起點。")
                Case "n", "r", "t", "f", "a", "e"
                    _RegexAddUniqueLine($items, "\" & $esc & "：控制字元跳脫序列。")
                Case Else
                    If $esc <> "" Then _RegexAddUniqueLine($items, "\" & $esc & "：跳脫序列或字面字元，依 PCRE 語法判定。")
            EndSwitch
            $i += 2
            ContinueLoop
        EndIf
        If $inClass Then
            If $c = "]" Then $inClass = False
            $i += 1
            ContinueLoop
        EndIf
        If $c = "[" Then
            $hasClass = True
            Local $class = _RegexFirstMatch($rest, '^\[(?:\\.|\[:[^]]+:\]|[^]\\])*\]')
            If $class <> "" Then
                _RegexAddUniqueLine($items, $class & "：字元集合，符合其中一個字元；^ 開頭表示排除，- 可表示範圍。")
                $i += StringLen($class)
                ContinueLoop
            EndIf
            _RegexAddUniqueLine($items, "[...]：字元集合；其中的特殊符號與外部語意不同。")
            $inClass = True
            $i += 1
            ContinueLoop
        EndIf
        If $c = "(" Then
            $hasGroup = True
            If StringRegExp($rest, '^\(\*[A-Za-z_]+(?::[^)]*)?\)') Then
                $tok = _RegexFirstMatch($rest, '^\(\*[A-Za-z_]+(?::[^)]*)?\)')
                _RegexAddUniqueLine($items, $tok & "：PCRE 控制動詞，可能影響回溯、略過或符合結果。")
                $i += StringLen($tok)
                ContinueLoop
            EndIf
            If StringRegExp($rest, '^\(\?[imsxUJADu-]+(?:\)|:)') Then
                $tok = _RegexFirstMatch($rest, '^\(\?[imsxUJADu-]+(?:\)|:)')
                _RegexAddUniqueLine($flags, $tok & "：模式修飾符；結尾為冒號時只作用於該群組。")
                If StringInStr($tok, "i", 1) Then _RegexAddUniqueLine($flags, "i：不區分大小寫。")
                If StringInStr($tok, "m", 1) Then _RegexAddUniqueLine($flags, "m：^ 與 $ 可作用於各行邊界。")
                If StringInStr($tok, "s", 1) Then _RegexAddUniqueLine($flags, "s：點號可以符合換行字元。")
                If StringInStr($tok, "x", 1) Then _RegexAddUniqueLine($flags, "x：延伸模式，忽略部分排版空白並允許註解。")
                If StringInStr($tok, "U", 1) Then _RegexAddUniqueLine($flags, "U：反轉量詞的預設貪婪行為。")
                If StringInStr($tok, "-", 1) Then _RegexAddUniqueLine($flags, "-：其後列出的選項為停用狀態。")
                $i += StringLen($tok)
                ContinueLoop
            EndIf
            If StringLeft($rest, 3) = "(?#" Then
                _RegexAddUniqueLine($items, "(?#...)：正規表示式內的註解。")
                $tok = _RegexFirstMatch($rest, '^\(\?#[^)]*\)')
                If $tok <> "" Then
                    $i += StringLen($tok)
                    ContinueLoop
                EndIf
            EndIf
            Local $kind = "", $prefix = ""
            If StringLeft($rest, 4) = "(?<=" Then
                $kind = "正向後顧（不消耗字元）"
                $prefix = "(?<="
            ElseIf StringLeft($rest, 4) = "(?<!" Then
                $kind = "負向後顧（不消耗字元）"
                $prefix = "(?<!"
            ElseIf StringLeft($rest, 3) = "(?=" Then
                $kind = "正向前瞻（不消耗字元）"
                $prefix = "(?="
            ElseIf StringLeft($rest, 3) = "(?!" Then
                $kind = "負向前瞻（不消耗字元）"
                $prefix = "(?!"
            ElseIf StringLeft($rest, 3) = "(?:" Then
                $kind = "非擷取群組"
                $prefix = "(?:"
            ElseIf StringLeft($rest, 3) = "(?>" Then
                $kind = "原子群組（限制回溯）"
                $prefix = "(?>"
            ElseIf StringLeft($rest, 3) = "(?|" Then
                $kind = "分支重設群組（不同分支可共用擷取編號）"
                $prefix = "(?|"
            ElseIf StringRegExp($rest, '^\(\?<[^>]+>') Then
                $prefix = _RegexFirstMatch($rest, '^\(\?<[^>]+>')
                $kind = "命名擷取群組"
                $count += 1
            ElseIf StringRegExp($rest, '^\(\?P<[^>]+>') Then
                $prefix = _RegexFirstMatch($rest, '^\(\?P<[^>]+>')
                $kind = "命名擷取群組"
                $count += 1
            ElseIf StringLeft($rest, 2) = "(?" Then
                $kind = "PCRE 特殊群組／條件／遞迴語法（需依完整結構判定）"
                $prefix = "(?"
            Else
                $count += 1
                $kind = "第 " & $count & " 組擷取群組"
                $prefix = "("
            EndIf
            _RegexAddUniqueLine($groups, $prefix & "... ：" & $kind & "。")
            $i += StringLen($prefix)
            ContinueLoop
        EndIf
        If $c = "^" Or $c = "$" Then
            $hasAnchor = True
            If $c = "^" Then _RegexAddUniqueLine($items, "^：字串或行的開頭（依 m 模式而定）。")
            If $c = "$" Then _RegexAddUniqueLine($items, "$：字串或行的結尾（依 m 模式而定）。")
        ElseIf $c = "|" Then
            _RegexAddUniqueLine($items, "|：擇一分支。")
        ElseIf $c = "." Then
            _RegexAddUniqueLine($items, ".：任意字元，是否包括換行取決於 s 模式。")
        ElseIf $c = "+" Or $c = "*" Or $c = "?" Or $c = "{" Then
            $tok = _RegexFirstMatch($rest, '^\{[0-9]+(?:,[0-9]*)?\}[?+]?')
            If $tok = "" Then $tok = _RegexFirstMatch($rest, '^[*+?][?+]?')
            If $tok <> "" Then
                $hasQuant = True
                Local $desc = "量詞，指定前一項目的重複次數"
                Switch StringLeft($tok, 1)
                    Case "+"
                        $desc = "前一項目重複一次以上"
                    Case "*"
                        $desc = "前一項目重複零次以上"
                    Case "?"
                        $desc = "前一項目重複零次或一次"
                EndSwitch
                If StringRight($tok, 1) = "?" And StringLen($tok) > 1 Then $desc &= "；非貪婪模式"
                If StringRight($tok, 1) = "+" And StringLen($tok) > 1 Then $desc &= "；佔有模式（限制回溯）"
                _RegexAddUniqueLine($items, $tok & "：" & $desc & "。")
                $i += StringLen($tok)
                ContinueLoop
            EndIf
        EndIf
        $i += 1
    WEnd
    Local $s = "正規表示式解析說明：" & @CRLF
    $s &= @CRLF & "語法顏色：" & @CRLF
    $s &= "青綠＝跳脫字元　紫色＝群組／修飾符　黃色＝字元集合　橘色＝量詞　藍色＝錨點／分支／萬用字元　綠色＝註解　紅色＝不完整跳脫" & @CRLF
    If $flags <> "" Then $s &= @CRLF & "模式修飾符：" & @CRLF & $flags
    If $groups <> "" Then $s &= @CRLF & "群組結構：" & @CRLF & $groups
    If $items <> "" Then $s &= @CRLF & "目前規則使用的語法：" & @CRLF & $items
    If $flags = "" And $groups = "" And $items = "" Then $s &= @CRLF & "沒有偵測到需要解說的特殊語法。" & @CRLF
    Return $s & @CRLF & "此為靜態語法提示，並非完整 PCRE AST；複雜條件、分支重設及巢狀擷取編號仍需以實際比對結果確認。"
EndFunc

; ----------------------------------------------------------------------------
; 把解析說明純文字轉為 HTML 段落（空行分段、換行轉 <br>）。
; ----------------------------------------------------------------------------
Func _RegexExplanationHTML($sText)
    Local $sSafe = EscapeHTML($sText)
    $sSafe = StringReplace($sSafe, @CRLF & @CRLF, "</p><p style=""margin:10px 0"">")
    $sSafe = StringReplace($sSafe, @CRLF, "<br>")
    Return "<p style=""margin:10px 0"">" & $sSafe & "</p>"
EndFunc

; ----------------------------------------------------------------------------
; 回傳 $pattern 在 $text 的第一個比對結果；沒有則回傳空字串。
; ----------------------------------------------------------------------------
Func _RegexFirstMatch($text, $pattern)
    Local $a = StringRegExp($text, $pattern, 1)
    If IsArray($a) Then Return $a[0]
    Return ""
EndFunc

; ----------------------------------------------------------------------------
; 在多行字串尾端加入一行，已存在的相同行不重複加入。
; ----------------------------------------------------------------------------
Func _RegexAddUniqueLine(ByRef $sLines, $sLine)
    If StringInStr(@CRLF & $sLines, @CRLF & $sLine & @CRLF, 1) Then Return
    $sLines &= $sLine & @CRLF
EndFunc

#EndRegion

#Region ;===== WebView 彩色預覽 =====

; ----------------------------------------------------------------------------
; 重新產生彩色預覽 HTML，交由 RefreshWebViews() 非同步送到 WebView。
; 無 WebView 時直接把模式寫入原生文字框。
; ----------------------------------------------------------------------------
Func UpdatePreview()
    If $gColorPreview = 0 Then
        If $gNativePreview <> 0 Then
            _UI_SetText($gWnd, $gNativePreview, GetPatternText())
            _UI_SetColor($gWnd, $gNativePreview, 0xFF242424, 0xFFDCDCAA)
        EndIf
        Return
    EndIf
    $gWebVersion += 1
    $gPreviewHtml = '<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><style>body{margin:0;padding:10px;background:#1e1e1e;color:#eee;font-family:"Cascadia Code",Consolas,monospace;font-size:' & $gEditorPixels & 'px}code{white-space:pre-wrap;overflow-wrap:anywhere}</style></head><body><code>' & BuildColoredLine(False, True) & '</code></body></html>'
    $gPreviewPending = True
    $gWebFails = 0
EndFunc

; ----------------------------------------------------------------------------
; 由 OnTick 呼叫：推動主視窗預覽與說明視窗的 WebView 非同步更新。
; 每次只送一個請求，以版本號避免舊內容覆蓋新內容；連續失敗 20 次即改用原生文字框。
; ----------------------------------------------------------------------------
Func RefreshWebViews()
    Local $state
    ; ---- 主視窗彩色預覽 ----
    If $gColorPreview <> 0 Then
        ; 上一個非同步請求已完成或逾時 5 秒 → 釋放並判斷是否成功
        If $gWebReq > 0 Then
            $state = _UI_WebViewResultStatus($gWnd, $gColorPreview, $gWebReq)
            If $state <> $AUI_WEB_RESULT_PENDING Or TimerDiff($gWebClock) > 5000 Then
                _UI_WebViewResultRelease($gWnd, $gColorPreview, $gWebReq)
                $gWebReq = 0
                If $state = $AUI_WEB_RESULT_SUCCEEDED And $gWebSent = $gWebVersion Then
                    $gPreviewPending = False
                Else
                    $gWebFails += 1
                EndIf
            EndIf
        EndIf
        ; 有待更新內容且沒有進行中的請求 → 送出新版本
        If $gPreviewPending And $gWebReq = 0 And $gWebFails < 20 Then
            $gWebSent = $gWebVersion
            $gWebClock = TimerInit()
            $gWebReq = _UI_WebViewExecuteScriptAsync($gWnd, $gColorPreview, VersionedScript($gPreviewHtml, $gWebVersion))
            If $gWebReq <= 0 Then
                $gWebReq = 0
                $gWebFails += 1
            EndIf
        EndIf
        ; 連續失敗 20 次 → 改用原生文字預覽
        If $gWebFails >= 20 Then NativePreview()
    EndIf

    ; ---- 說明視窗（同樣的流程） ----
    If $gHelpWindow = 0 Or Not _UI_IsAlive($gHelpWindow) Or $gHelpWeb = 0 Then Return
    If $gHelpReq > 0 Then
        $state = _UI_WebViewResultStatus($gHelpWindow, $gHelpWeb, $gHelpReq)
        If $state <> $AUI_WEB_RESULT_PENDING Or TimerDiff($gHelpClock) > 5000 Then
            _UI_WebViewResultRelease($gHelpWindow, $gHelpWeb, $gHelpReq)
            $gHelpReq = 0
            If $state = $AUI_WEB_RESULT_SUCCEEDED And $gHelpSent = $gHelpVersion Then
                $gHelpPending = False
            Else
                $gHelpFails += 1
            EndIf
        EndIf
    EndIf
    If $gHelpPending And $gHelpReq = 0 And $gHelpFails < 20 Then
        $gHelpSent = $gHelpVersion
        $gHelpClock = TimerInit()
        $gHelpReq = _UI_WebViewExecuteScriptAsync($gHelpWindow, $gHelpWeb, VersionedScript($gHelpHtml, $gHelpVersion))
        If $gHelpReq <= 0 Then
            $gHelpReq = 0
            $gHelpFails += 1
        EndIf
    EndIf
    If $gHelpFails >= 20 Then NativeHelp()
EndFunc

; ----------------------------------------------------------------------------
; 產生注入 WebView 的 JavaScript：以 DOMParser 取代整頁內容（移除 <script>），
; 並綁定說明頁的搜尋框；window.__regexVersion 較新時略過舊版本。
; ----------------------------------------------------------------------------
Func VersionedScript($html, $version)
    Return '(function(){var v=' & Int($version) & ';if((window.__regexVersion||0)>v)return "stale";var d=new DOMParser().parseFromString(' & JsQuote($html) & ',"text/html");d.querySelectorAll("script").forEach(function(s){s.remove();});document.documentElement.innerHTML=d.documentElement.innerHTML;var search=document.getElementById("search");if(search){search.addEventListener("input",function(){var q=this.value.toLowerCase();document.querySelectorAll("tbody tr").forEach(function(r){r.hidden=!r.textContent.toLowerCase().includes(q);});});}window.__regexVersion=v;return v;})()'
EndFunc

; ----------------------------------------------------------------------------
; WebView 載入完成（例如重新整理）時，重新送出目前內容。
; ----------------------------------------------------------------------------
Func OnWebLoading($wnd, $web, $tab, $loading)
    If $loading = 0 Then
        If $wnd = $gWnd Then
            $gPreviewPending = True
            $gWebFails = 0
        Else
            $gHelpPending = True
            $gHelpFails = 0
        EndIf
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; WebView 無法使用時，隱藏 WebView 並改建原生文字框預覽。
; ----------------------------------------------------------------------------
Func NativePreview()
    _UI_SetVisible($gWnd, $gColorPreview, False)
    $gColorPreview = 0
    $gNativePreview = _UI_TextArea($gWnd, 0, "文字預覽", GetPatternText(), 570, 512, 374, 190)
    _UI_EditSetReadOnly($gWnd, $gNativePreview, True)
    Local $menu = _UI_ContextMenu($gWnd, $gNativePreview, $COLOR_MENU_ITEMS)
    _UI_OnValue($gWnd, $menu, "OnColorMenu")
EndFunc

; ----------------------------------------------------------------------------
; 把字串轉為 JavaScript 雙引號字串常值（跳脫 \ " CR LF Tab）。
; ----------------------------------------------------------------------------
Func JsQuote($s)
    $s = StringReplace($s, "\", "\\")
    $s = StringReplace($s, '"', '\"')
    $s = StringReplace($s, @CR, "\r")
    $s = StringReplace($s, @LF, "\n")
    $s = StringReplace($s, @TAB, "\t")
    Return '"' & $s & '"'
EndFunc

; ----------------------------------------------------------------------------
; 跳脫 HTML 特殊字元 & < > "。
; ----------------------------------------------------------------------------
Func EscapeHTML($s)
    $s = StringReplace($s, "&", "&amp;")
    $s = StringReplace($s, "<", "&lt;")
    $s = StringReplace($s, ">", "&gt;")
    $s = StringReplace($s, '"', "&quot;")
    Return $s
EndFunc

#EndRegion

#Region ;===== 語法說明視窗 =====

; ----------------------------------------------------------------------------
; 「？」按鈕：開啟語法說明視窗（有 WebView2 時顯示可搜尋的 HTML 表格）。
; ----------------------------------------------------------------------------
Func OnHelp($id)
    If $gHelpWindow <> 0 And _UI_IsAlive($gHelpWindow) Then
        _UI_WindowShowModal($gHelpWindow, $gWnd)
        Return
    EndIf
    $gHelpWindow = _UI_WindowCreateEx($APP_NAME & "｜語法說明", 0, 0, 940, 720, $gWindowFlags)
    If $gHelpWindow = 0 Then Return
    _UI_WindowCenter($gHelpWindow)
    If $gCanWeb Then $gHelpWeb = _UI_WebView($gHelpWindow, 0, "about:blank", 16, 54, 908, 604)
    If $gHelpWeb = 0 Then NativeHelp()
    Local $text = _UI_Button($gHelpWindow, 0, "複製文字說明", $AUI_VAR_DEFAULT, 16, 670, 200, 32)
    Local $html = _UI_Button($gHelpWindow, 0, "複製 HTML", $AUI_VAR_DEFAULT, 228, 670, 200, 32)
    _UI_OnClick($gHelpWindow, $text, "CopyHelpText")
    _UI_OnClick($gHelpWindow, $html, "CopyHelpHtml")
    _UI_OnClose($gHelpWindow, "OnHelpClosed")
    If $gHelpWeb <> 0 Then
        _UI_WebViewOnTabLoading($gHelpWindow, $gHelpWeb, "OnWebLoading")
        $gHelpHtml = BuildHelpHtml()
        $gHelpVersion += 1
        $gHelpPending = True
        $gHelpFails = 0
    EndIf
    _UI_WindowShowModal($gHelpWindow, $gWnd)
EndFunc

; ----------------------------------------------------------------------------
; 說明視窗改用原生唯讀文字框顯示純文字說明。
; ----------------------------------------------------------------------------
Func NativeHelp()
    If $gHelpWeb <> 0 Then _UI_SetVisible($gHelpWindow, $gHelpWeb, False)
    $gHelpWeb = 0
    If $gHelpText = 0 Then
        $gHelpText = _UI_TextArea($gHelpWindow, 0, "AUI 原生語法說明（無 WebView2）", BuildHelpText(), 16, 54, 908, 604)
        _UI_EditSetReadOnly($gHelpWindow, $gHelpText, True)
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 說明視窗關閉：釋放 WebView 請求並重設相關變數。
; ----------------------------------------------------------------------------
Func OnHelpClosed($wnd)
    If $gHelpReq > 0 And $gHelpWeb <> 0 Then _UI_WebViewResultRelease($wnd, $gHelpWeb, $gHelpReq)
    $gHelpReq = 0
    $gHelpWindow = 0
    $gHelpWeb = 0
    $gHelpText = 0
EndFunc

; ----------------------------------------------------------------------------
; 「複製文字說明」按鈕。
; ----------------------------------------------------------------------------
Func CopyHelpText($id)
    ClipPut(BuildHelpText())
EndFunc

; ----------------------------------------------------------------------------
; 「複製 HTML」按鈕。
; ----------------------------------------------------------------------------
Func CopyHelpHtml($id)
    ClipPut(BuildHelpHtml())
EndFunc

; ----------------------------------------------------------------------------
; 語法說明資料表，純文字與 HTML 說明共用同一份資料。
; 回傳：二維陣列 [語法, 說明]；語法為空字串的列是區段標題。
; ----------------------------------------------------------------------------
Func HelpRows()
    Local $aRows[100][2], $n = 0
    _HelpRow($aRows, $n, "", "比對字元、群組與修飾符") ; 區段標題
    _HelpRow($aRows, $n, "[ ... ]", "比對集合內任一字元，例如 [aeiou]、[a-z]。")
    _HelpRow($aRows, $n, "[^ ... ]", "排除集合；^ 僅在集合開頭表示否定。")
    _HelpRow($aRows, $n, "[[:class:]]", "POSIX 類別放在外層集合，例如 [[:digit:]]。")
    _HelpRow($aRows, $n, "[[:^class:]]", "否定 POSIX 類別。")
    _HelpRow($aRows, $n, "( ... )", "擷取群組，可整組重複。")
    _HelpRow($aRows, $n, "(?i)", "不區分大小寫。")
    _HelpRow($aRows, $n, "(?-i)", "恢復區分大小寫。")
    _HelpRow($aRows, $n, "(?i ... )", "局部模式應寫 (?i:...) 或 ((?i)...)。")
    _HelpRow($aRows, $n, "(?-i ... )", "局部模式應寫 (?-i:...) 或 ((?-i)...)。")
    _HelpRow($aRows, $n, "(?: ... )", "非擷取群組。")
    _HelpRow($aRows, $n, "(?i: ... )", "僅此群組不區分大小寫。")
    _HelpRow($aRows, $n, "(?-i: ... )", "僅此群組區分大小寫。")
    _HelpRow($aRows, $n, "(?m)", "多行錨點；不會讓點號比對換行。")
    _HelpRow($aRows, $n, "(?s)", "DotAll：點號可比對換行。")
    _HelpRow($aRows, $n, "(?x)", "忽略集合外排版空白；# 開始行註解。")
    _HelpRow($aRows, $n, "(?U)", "反轉一般量詞的貪婪／非貪婪行為。")
    _HelpRow($aRows, $n, ".", "任意字元；預設不含換行。")
    _HelpRow($aRows, $n, "|", "選擇左右子模式。")
    _HelpRow($aRows, $n, "\", "跳脫或引入特殊序列。")
    _HelpRow($aRows, $n, "\\", "字面反斜線。")
    _HelpRow($aRows, $n, "\a", "BEL：Chr(7)。")
    _HelpRow($aRows, $n, "\A", "字串絕對開頭。")
    _HelpRow($aRows, $n, "\b", "\w 與 \W／邊緣的單字邊界；集合內為退格。")
    _HelpRow($aRows, $n, "\B", "非單字邊界。")
    _HelpRow($aRows, $n, "\cX", "控制字元，例如 \cM。")
    _HelpRow($aRows, $n, "\d", "數字；UCP 可擴展 Unicode 範圍。")
    _HelpRow($aRows, $n, "\D", "非數字。")
    _HelpRow($aRows, $n, "\e", "ESC：Chr(27)。")
    _HelpRow($aRows, $n, "\E", "結束 \Q 引用。")
    _HelpRow($aRows, $n, "\f", "換頁：Chr(12)。")
    _HelpRow($aRows, $n, "\h", "水平空白。")
    _HelpRow($aRows, $n, "\H", "非水平空白。")
    _HelpRow($aRows, $n, "\n", "LF：Chr(10)。")
    _HelpRow($aRows, $n, "\Q ... \E", "引用元字元為字面內容。")
    _HelpRow($aRows, $n, "\r", "CR：Chr(13)。")
    _HelpRow($aRows, $n, "\s", "空白包含 Tab、LF、VT、FF、CR、空格；UCP 影響範圍。")
    _HelpRow($aRows, $n, "\S", "非空白。")
    _HelpRow($aRows, $n, "\t", "Tab：Chr(9)。")
    _HelpRow($aRows, $n, "\v", "垂直空白，不只 Chr(11)。")
    _HelpRow($aRows, $n, "\V", "非垂直空白。")
    _HelpRow($aRows, $n, "\w", "單字字元；UCP 影響 Unicode 範圍。")
    _HelpRow($aRows, $n, "\W", "非單字字元。")
    _HelpRow($aRows, $n, "\###", "八進位或反向參照可能歧義；建議 \g{1}。")
    _HelpRow($aRows, $n, "\xHH / \x{HHHH}", "十六進位字元，可指定非 ASCII 碼點。")
    _HelpRow($aRows, $n, "\z", "字串絕對結尾。")
    _HelpRow($aRows, $n, "\Z", "字串結尾或最末換行之前。")
    _HelpRow($aRows, $n, "\R", "換行序列，受 BSR 設定影響。")
    _HelpRow($aRows, $n, "(?=...) / (?!...)", "正／負向前瞻。")
    _HelpRow($aRows, $n, "(?<=...) / (?<!...)", "正／負向後顧，依 PCRE 版本支援限制。")
    _HelpRow($aRows, $n, "(*UCP)", "模式最開頭啟用 Unicode 類別支援。")

    _HelpRow($aRows, $n, "", "重複與量詞") ; 區段標題
    _HelpRow($aRows, $n, "{x}", "恰好 x 次。")
    _HelpRow($aRows, $n, "{x,}", "至少 x 次。")
    _HelpRow($aRows, $n, "{0,x}", "至多 x 次，包括零次。")
    _HelpRow($aRows, $n, "{x,y}", "x 到 y 次，包含端點。")
    _HelpRow($aRows, $n, "*", "零次以上。")
    _HelpRow($aRows, $n, "+", "一次以上。")
    _HelpRow($aRows, $n, "?", "零次或一次。")
    _HelpRow($aRows, $n, "?（量詞之後）", "非貪婪，例如 *?。")
    _HelpRow($aRows, $n, "+（量詞之後）", "占有量詞，例如 *+。")

    _HelpRow($aRows, $n, "", "字元類別") ; 區段標題
    _HelpRow($aRows, $n, "[[:alnum:]]", "字母與數字")
    _HelpRow($aRows, $n, "[[:alpha:]]", "字母")
    _HelpRow($aRows, $n, "[[:ascii:]]", "碼點 0～127")
    _HelpRow($aRows, $n, "[[:blank:]]", "空格／Tab；UCP 可擴展")
    _HelpRow($aRows, $n, "[[:cntrl:]]", "控制字元")
    _HelpRow($aRows, $n, "[[:digit:]]", "十進位數字")
    _HelpRow($aRows, $n, "[[:graph:]]", "可列印，不含空格")
    _HelpRow($aRows, $n, "[[:lower:]]", "小寫字母")
    _HelpRow($aRows, $n, "[[:print:]]", "可列印，含空格")
    _HelpRow($aRows, $n, "[[:punct:]]", "標點")
    _HelpRow($aRows, $n, "[[:space:]]", "空白，含 VT")
    _HelpRow($aRows, $n, "[[:upper:]]", "大寫字母")
    _HelpRow($aRows, $n, "[[:word:]]", "單字字元")
    _HelpRow($aRows, $n, "[[:xdigit:]]", "十六進位數字")

    _HelpRow($aRows, $n, "", "AutoIt StringRegExp Flag") ; 區段標題
    _HelpRow($aRows, $n, "0", "是否符合，回傳 1 或 0。")
    _HelpRow($aRows, $n, "1", "首筆擷取；無群組時回傳首筆比對。")
    _HelpRow($aRows, $n, "2", "首筆完整比對及群組，索引 0 為完整比對。")
    _HelpRow($aRows, $n, "3", "全域一維陣列，有群組時輸出擷取內容。")
    _HelpRow($aRows, $n, "4", "全域巢狀陣列，每筆內層 0 為完整比對，其後為群組。")
    ReDim $aRows[$n][2]
    Return $aRows
EndFunc

; ----------------------------------------------------------------------------
; HelpRows() 的輔助函式：在 $aRows 第 $n 列寫入一筆資料後 $n 加 1。
; ----------------------------------------------------------------------------
Func _HelpRow(ByRef $aRows, ByRef $n, $sSyntax, $sDesc)
    $aRows[$n][0] = $sSyntax
    $aRows[$n][1] = $sDesc
    $n += 1
EndFunc

; ----------------------------------------------------------------------------
; 由 HelpRows() 產生純文字語法說明。
; ----------------------------------------------------------------------------
Func BuildHelpText()
    Local $aRows = HelpRows()
    Local $text = $APP_NAME & " v" & $APP_VERSION & "｜正規表示式語法說明" & @CRLF
    For $i = 0 To UBound($aRows) - 1
        If $aRows[$i][0] = "" Then
            $text &= @CRLF & $aRows[$i][1] & @CRLF
        Else
            $text &= $aRows[$i][0] & "：" & $aRows[$i][1] & @CRLF
        EndIf
    Next
    Return $text
EndFunc

; ----------------------------------------------------------------------------
; 由 HelpRows() 產生 HTML 語法說明頁（含搜尋框與網路教學連結）。
; ----------------------------------------------------------------------------
Func BuildHelpHtml()
    Local $aRows = HelpRows()
    Local $html = '<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><title>Regex4AutoIt｜語法說明</title><style>'
    $html &= 'body{font:16px/1.65 "Microsoft JhengHei",sans-serif;background:#f6f8fc;color:#203047;margin:0;padding:24px}'
    $html &= 'header{position:sticky;top:0;background:#f6f8fc;padding:8px 0 16px}'
    $html &= 'h1{margin:0;font-size:24px}'
    $html &= 'h2{color:#23588b;margin:26px 0 12px}'
    $html &= 'input{box-sizing:border-box;width:100%;padding:10px;font-size:16px;border:1px solid #bdc8d6;border-radius:8px}'
    $html &= 'table{border-collapse:collapse;width:100%;background:white}'
    $html &= 'th,td{border:1px solid #d7e0eb;padding:10px;text-align:left;vertical-align:top}'
    $html &= 'th{background:#e8eff8}'
    $html &= 'td:first-child{width:24%}'
    $html &= 'code{font-family:Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere;color:#7e3ba5}'
    $html &= '.notice{padding:12px;border-left:4px solid #e6a23c;background:#fff7e8}'
    $html &= 'a{color:#245f9a}'
    $html &= '</style></head><body>'
    ; 搜尋框的過濾邏輯由 VersionedScript() 注入
    $html &= '<header><h1>Regex4AutoIt 正規表示式語法表</h1><p>實際支援以 AutoIt 執行結果為準。</p>'
    $html &= '<input id="search" placeholder="搜尋語法或說明，例如：\E、群組、空白、digit"></header>'
    $html &= '<div class="notice">POSIX 否定使用 [[:^class:]]；\E 結束 \Q 引用；局部選項使用 (?i:...)／(?-i:...)。UCP 與 PCRE 版本影響字元範圍。</div>'
    Local $bOpen = False
    For $i = 0 To UBound($aRows) - 1
        If $aRows[$i][0] = "" Then
            If $bOpen Then $html &= '</tbody></table></section>'
            $html &= '<section><h2>' & EscapeHTML($aRows[$i][1]) & '</h2><table><thead><tr><th>語法</th><th>說明</th></tr></thead><tbody>'
            $bOpen = True
        Else
            $html &= '<tr><td><code>' & EscapeHTML($aRows[$i][0]) & '</code></td><td>' & EscapeHTML($aRows[$i][1]) & '</td></tr>'
        EndIf
    Next
    If $bOpen Then $html &= '</tbody></table></section>'
    $html &= '<section><h2>網路教學</h2>'
    $html &= '<p><a href="http://deerchao.net/tutorials/regex/regex.htm" target="_blank" rel="noopener">正規表示式 30 分鐘入門</a></p>'
    $html &= '<p><a href="http://www.regexlab.com/zh/regref.htm" target="_blank" rel="noopener">揭開正規表示式的神秘面紗</a></p>'
    $html &= '<p><a href="https://www.autoitscript.com/autoit3/docs/functions/StringRegExp.htm" target="_blank" rel="noopener">AutoIt 官方文件</a></p>'
    $html &= '</section></body></html>'
    Return $html
EndFunc

#EndRegion

#Region ;===== 範例（Examples.ini） =====

; ----------------------------------------------------------------------------
; 內建範例內容；Examples.ini 不存在或格式錯誤時使用。
; 格式：[Match] 名稱=模式；[Replace] 名稱=模式~~~~取代內容
; ----------------------------------------------------------------------------
Func DefaultExamplesIni()
    Return "[Match]" & @CRLF & _
        "符合 a、b、c 任一字元 = [abc]" & @CRLF & _
        "排除 a、b、c = [^abc]" & @CRLF & _
        "擷取群組 = (abc)" & @CRLF & _
        "任意字元 = ." & @CRLF & _
        "單行模式 = (?s)." & @CRLF & _
        "不分大小寫 = (?i)abc" & @CRLF & _
        "忽略空白 = (?x)a b" & @CRLF & _
        "多行模式 = (?m)^abc" & @CRLF & _
        "非擷取群組 = (?:abc)" & @CRLF & _
        "字串開頭 = ^abc" & @CRLF & _
        "字串結尾 = abc$" & @CRLF & _
        "單字邊界 = \bword\b" & @CRLF & _
        "非單字邊界 = \Bend" & @CRLF & _
        "數字 = \d+" & @CRLF & _
        "非數字 = \D+" & @CRLF & _
        "水平空白 = \h+" & @CRLF & _
        "空白 = \s+" & @CRLF & _
        "CRLF = \r\n" & @CRLF & _
        "單字 = \w+" & @CRLF & _
        "非單字 = \W+" & @CRLF & _
        "十六進位 = \x20" & @CRLF & _
        "非換行 = [^\r\n]+" & @CRLF & _
        "超出 U+00FF = [^\x00-\xff]+" & @CRLF & _
        "" & @CRLF & _
        "[Replace]" & @CRLF & _
        "刪除數字 = \d+~~~~" & @CRLF & _
        "刪除非數字 = \D+~~~~" & @CRLF & _
        "刪除水平空白 = \h+~~~~" & @CRLF & _
        "刪除換行 = [\r\n]+~~~~" & @CRLF & _
        "刪除 U+0000~00FF = [\x00-\xff]+~~~~" & @CRLF & _
        "刪除大於 U+00FF = [^\x00-\xff]+~~~~" & @CRLF & _
        "數字換成 AAA = \d+~~~~AAA" & @CRLF & _
        "數字加括號 = (\d+)~~~~($1)" & @CRLF & _
        ""
EndFunc

; ----------------------------------------------------------------------------
; 讀取 Examples.ini（不存在時自動建立），解析後填入兩個範例下拉選單。
; ----------------------------------------------------------------------------
Func LoadPresets()
    Local $text = DefaultExamplesIni()
    If Not FileExists($gExamples) Then
        Local $h = FileOpen($gExamples, 130)
        If $h <> -1 Then
            FileWrite($h, $text)
            FileClose($h)
        EndIf
    EndIf
    If FileExists($gExamples) Then
        Local $h = FileOpen($gExamples, 0)
        If $h <> -1 Then
            $text = FileRead($h)
            FileClose($h)
        EndIf
    EndIf
    Local $error = ParseExamples($text, True)
    If $error <> "" Then
        ParseExamples(DefaultExamplesIni(), True)
        _UI_SetText($gWnd, $gStatus, "INI 格式錯誤，暫用內建範例：" & $error)
    EndIf
    $gLoading = True
    _UI_ComboClear($gWnd, $gPresets)
    _UI_ComboClear($gWnd, $gReplacePresets)
    For $i = 0 To $gMatchCount - 1
        _UI_ComboAddItem($gWnd, $gPresets, $gMatchRows[$i][0])
    Next
    For $i = 0 To $gReplaceCount - 1
        _UI_ComboAddItem($gWnd, $gReplacePresets, $gReplaceRows[$i][0])
    Next
    _UI_ComboSetSelected($gWnd, $gPresets, -1)
    _UI_ComboSetSelected($gWnd, $gReplacePresets, -1)
    $gLoading = False
EndFunc

; ----------------------------------------------------------------------------
; 解析範例 INI 文字並檢查結構：區段、等號、名稱重複、~~~~ 分隔。
; $commit：True 時把結果寫入全域範例陣列
; 回傳：空字串＝成功；否則為錯誤訊息（含行號）
; ----------------------------------------------------------------------------
Func ParseExamples($text, $commit = False)
    Local $m[1][2], $r[1][3], $mc = 0, $rc = 0, $section = "", $seen = "|", $hasM = False, $hasR = False
    Local $lines = StringSplit(StringReplace(StringReplace($text, @CRLF, @LF), @CR, @LF), @LF, 1)
    If $lines[0] > 10000 Then Return "範例檔超過 10000 行"
    For $i = 1 To $lines[0]
        Local $line = StringStripWS($lines[$i], 3)
        If $line = "" Or StringLeft($line, 1) = ";" Or StringLeft($line, 1) = "#" Then ContinueLoop
        If StringLeft($line, 1) = "[" And StringRight($line, 1) = "]" Then
            $section = StringLower(StringMid($line, 2, StringLen($line) - 2))
            If $section = "match" Then $hasM = True
            If $section = "replace" Then $hasR = True
            If $section <> "match" And $section <> "replace" Then Return "第 " & $i & " 行：區段錯誤"
            ContinueLoop
        EndIf
        If $section = "" Then Return "第 " & $i & " 行：請先指定區段"
        Local $eq = StringInStr($line, "=", 1)
        If $eq <= 1 Then Return "第 " & $i & " 行：缺少名稱或等號"
        Local $name = StringStripWS(StringLeft($line, $eq - 1), 3), $value = StringStripWS(StringMid($line, $eq + 1), 3)
        If $name = "" Or StringInStr($name, "|") Then Return "第 " & $i & " 行：名稱錯誤"
        Local $key = "|" & $section & ":" & StringLower($name) & "|"
        If StringInStr($seen, $key, 1) Then Return "第 " & $i & " 行：名稱重複"
        $seen &= $key
        If $section = "match" Then
            $mc += 1
            ReDim $m[$mc][2]
            $m[$mc - 1][0] = $name
            $m[$mc - 1][1] = $value
        Else
            Local $sep = StringInStr($value, "~~~~", 1)
            If $sep = 0 Then Return "第 " & $i & " 行：缺少 ~~~~ 分隔"
            $rc += 1
            ReDim $r[$rc][3]
            $r[$rc - 1][0] = $name
            $r[$rc - 1][1] = StringLeft($value, $sep - 1)
            $r[$rc - 1][2] = StringMid($value, $sep + 4)
        EndIf
    Next
    If Not $hasM Or Not $hasR Then Return "必須包含 [Match] 與 [Replace]"
    If $commit Then
        $gMatchRows = $m
        $gReplaceRows = $r
        $gMatchCount = $mc
        $gReplaceCount = $rc
    EndIf
    Return ""
EndFunc

; ----------------------------------------------------------------------------
; 「重載 INI」按鈕：重新讀取 Examples.ini。
; ----------------------------------------------------------------------------
Func OnReloadExamples($id)
    LoadPresets()
    _UI_SetText($gWnd, $gStatus, "已重載：Match=" & $gMatchCount & " Replace=" & $gReplaceCount)
EndFunc

; ----------------------------------------------------------------------------
; 「編輯範例」按鈕：開啟範例編輯視窗。
; ----------------------------------------------------------------------------
Func OnEditExamples($id)
    If $gEditWindow <> 0 And _UI_IsAlive($gEditWindow) Then
        _UI_WindowShowModal($gEditWindow, $gWnd)
        Return
    EndIf
    $gEditOriginal = DefaultExamplesIni()
    Local $h = FileOpen($gExamples, 0)
    If $h <> -1 Then
        $gEditOriginal = FileRead($h)
        FileClose($h)
    EndIf
    $gEditWindow = _UI_WindowCreateEx($APP_NAME & "｜編輯預設範例", 0, 0, 800, 610, $gWindowFlags)
    If $gEditWindow = 0 Then Return
    _UI_WindowCenter($gEditWindow)
    $gEditDiscard = False
    $gEditText = _UI_TextArea($gEditWindow, 0, "[Match] 名稱=Pattern；[Replace] 名稱=Pattern~~~~取代內容", $gEditOriginal, 16, 58, 768, 438)
    $gEditOriginal = _UI_GetText($gEditWindow, $gEditText)
    _UI_TooltipSetText($gEditWindow, $gEditText, "可直接新增／修改／刪除行；空取代以 ~~~~ 結尾")
    Local $check = _UI_Button($gEditWindow, 0, "檢查格式", $AUI_VAR_DEFAULT, 16, 510, 240, 36)
    Local $save = _UI_Button($gEditWindow, 0, "儲存並重載", $AUI_VAR_PRIMARY, 270, 510, 240, 36)
    Local $close = _UI_Button($gEditWindow, 0, "關閉", $AUI_VAR_DEFAULT, 524, 510, 260, 36)
    $gEditStatus = _UI_Text($gEditWindow, 0, "儲存前備份為 Examples.ini.bak；只檢查 INI 結構。", 16, 562, 768, 28)
    _UI_OnClick($gEditWindow, $check, "CheckExamples")
    _UI_OnClick($gEditWindow, $save, "SaveExamples")
    _UI_OnClick($gEditWindow, $close, "CloseExamples")
    _UI_OnBeforeClose($gEditWindow, "BeforeCloseExamples")
    _UI_OnClose($gEditWindow, "ExamplesClosed")
    _UI_WindowShowModal($gEditWindow, $gWnd)
EndFunc

; ----------------------------------------------------------------------------
; 範例編輯視窗「檢查格式」按鈕。
; ----------------------------------------------------------------------------
Func CheckExamples($id)
    Local $error = ParseExamples(_UI_GetText($gEditWindow, $gEditText), False)
    _UI_SetText($gEditWindow, $gEditStatus, ($error = "" ? "INI 結構通過；PCRE 語意請執行測試" : $error))
EndFunc

; ----------------------------------------------------------------------------
; 範例編輯視窗「儲存並重載」按鈕。
; 先寫入暫存檔，原檔備份為 .bak 後再取代，避免寫入失敗時損毀原檔。
; ----------------------------------------------------------------------------
Func SaveExamples($id)
    Local $text = _UI_GetText($gEditWindow, $gEditText), $error = ParseExamples($text, False)
    If $error <> "" Then Return _UI_SetText($gEditWindow, $gEditStatus, $error)
    Local $temp = $gExamples & ".tmp." & @AutoItPID, $h = FileOpen($temp, 130)
    If $h = -1 Then Return _UI_SetText($gEditWindow, $gEditStatus, "無法建立暫存檔")
    Local $ok = FileWrite($h, $text)
    FileClose($h)
    If Not $ok Then
        FileDelete($temp)
        Return _UI_SetText($gEditWindow, $gEditStatus, "寫入失敗")
    EndIf
    If FileExists($gExamples) Then
        If Not FileCopy($gExamples, $gExamples & ".bak", 1) Then
            FileDelete($temp)
            Return _UI_SetText($gEditWindow, $gEditStatus, "備份失敗；原檔未覆寫")
        EndIf
    EndIf
    If Not FileMove($temp, $gExamples, 1) Then
        FileDelete($temp)
        Return _UI_SetText($gEditWindow, $gEditStatus, "取代檔案失敗")
    EndIf
    $gEditOriginal = $text
    LoadPresets()
    _UI_SetText($gEditWindow, $gEditStatus, "已儲存並重載，原檔已備份")
EndFunc

; ----------------------------------------------------------------------------
; 範例編輯視窗「關閉」按鈕。
; ----------------------------------------------------------------------------
Func CloseExamples($id)
    _UI_WindowClose($gEditWindow)
EndFunc

; ----------------------------------------------------------------------------
; 範例編輯視窗關閉前：有未儲存的修改時跳出確認對話框。
; 回傳：True＝允許關閉
; ----------------------------------------------------------------------------
Func BeforeCloseExamples($wnd, $reason)
    If $gEditDiscard Then Return True
    If _UI_GetText($gEditWindow, $gEditText) = $gEditOriginal Then Return True
    If $gEditCloseDialog <> 0 Then
        If _UI_DialogGetOpen($gEditWindow, $gEditCloseDialog) Then Return False
        $gEditCloseDialog = 0
    EndIf
    $gEditCloseDialog = _UI_Dialog($gEditWindow, "尚未儲存的修改", "要放棄範例修改並關閉嗎？", "取消|放棄修改")
    If $gEditCloseDialog <> 0 Then
        _UI_DialogSetDefaultButton($gEditWindow, $gEditCloseDialog, 0)
        _UI_DialogSetCancelButton($gEditWindow, $gEditCloseDialog, 0)
        _UI_OnValue($gEditWindow, $gEditCloseDialog, "DiscardExamplesConfirmed")
    EndIf
    Return False
EndFunc

; ----------------------------------------------------------------------------
; 確認對話框回應：選「放棄修改」（1）時關閉視窗。
; ----------------------------------------------------------------------------
Func DiscardExamplesConfirmed($id, $value)
    If $id <> $gEditCloseDialog Then Return
    $gEditCloseDialog = 0
    If Number($value) = 1 Then
        $gEditDiscard = True
        _UI_WindowClose($gEditWindow)
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 範例編輯視窗已關閉：重設相關變數。
; ----------------------------------------------------------------------------
Func ExamplesClosed($wnd)
    $gEditWindow = 0
    $gEditText = 0
    $gEditCloseDialog = 0
    $gEditDiscard = False
EndFunc

#EndRegion

#Region ;===== 最近紀錄與收藏（Regex4AutoIt_Records.ini） =====

; ----------------------------------------------------------------------------
; 把文字編碼為 UTF-16 十六進位字串，避免 INI 的換行、等號與字碼頁問題。
; ----------------------------------------------------------------------------
Func PackText($sText)
    Return Hex(StringToBinary($sText, 2))
EndFunc

; ----------------------------------------------------------------------------
; PackText() 的反向轉換；格式不正確時回傳 $sFallback。
; ----------------------------------------------------------------------------
Func UnpackText($sHex, $sFallback)
    If $sHex = "" Then Return $sFallback
    If StringRegExp($sHex, "[^0-9A-Fa-f]") Or Mod(StringLen($sHex), 4) <> 0 Then Return $sFallback
    Return BinaryToString(Binary("0x" & $sHex), 2)
EndFunc

; ----------------------------------------------------------------------------
; 讀取最近使用與收藏的筆數，並重建清單。
; ----------------------------------------------------------------------------
Func LoadRecords()
    $gHistoryCount = Number(_IniRead($gHistoryFile, "Meta", "HistoryCount", "0", 256))
    $gFavoriteCount = Number(_IniRead($gHistoryFile, "Meta", "FavoriteCount", "0", 256))
    If $gHistoryCount > $MAX_HISTORY Then $gHistoryCount = $MAX_HISTORY
    If $gFavoriteCount > $MAX_FAVORITES Then $gFavoriteCount = $MAX_FAVORITES
    RefreshRecords()
EndFunc

; ----------------------------------------------------------------------------
; 重建全部項目清單：收藏在前（★），其後為不重複的最近使用，再顯示目前頁面。
; ----------------------------------------------------------------------------
Func RefreshRecords()
    ; 先整理所有紀錄，再只顯示目前頁面的 12 筆。
    $gRecordEntryCount = 0
    ReDim $gRecordEntries[1][3]
    For $i = 1 To $gFavoriteCount
        Local $s = UnpackText(_IniRead($gHistoryFile, "Favorites", String($i), "", 256), "")
        If $s <> "" Then AddRecordEntry("★ " & StringLeft($s, 64), "Favorites", $i)
    Next
    For $i = 1 To $gHistoryCount
        Local $s = UnpackText(_IniRead($gHistoryFile, "History", String($i), "", 256), "")
        If $s <> "" And Not IsFavorite($s) Then AddRecordEntry("最近 " & StringLeft($s, 62), "History", $i)
    Next
    RenderRecordPage()
EndFunc

; ----------------------------------------------------------------------------
; 在 $gRecordEntries 加入一筆項目（索引從 1 起算）。
; ----------------------------------------------------------------------------
Func AddRecordEntry($sLabel, $sSection, $iIndex)
    $gRecordEntryCount += 1
    ReDim $gRecordEntries[$gRecordEntryCount + 1][3]
    $gRecordEntries[$gRecordEntryCount][0] = $sLabel
    $gRecordEntries[$gRecordEntryCount][1] = $sSection
    $gRecordEntries[$gRecordEntryCount][2] = $iIndex
EndFunc

; ----------------------------------------------------------------------------
; 回傳最後一頁的頁碼（從 0 起算）。
; ----------------------------------------------------------------------------
Func RecordMaxPage()
    If $gRecordEntryCount = 0 Then Return 0
    Return Int(($gRecordEntryCount - 1) / $gRecordPageSize)
EndFunc

; ----------------------------------------------------------------------------
; 把目前頁面的項目（最多 12 筆）放入下拉選單，並更新換頁按鈕狀態與提示。
; ----------------------------------------------------------------------------
Func RenderRecordPage()
    If $gRecordPage > RecordMaxPage() Then $gRecordPage = RecordMaxPage()
    If $gRecordPage < 0 Then $gRecordPage = 0
    _UI_ComboClose($gWnd, $gHistory)
    _UI_ComboClear($gWnd, $gHistory)
    $gRecordMapCount = 0
    ReDim $gRecordMap[1][2]
    Local $iFirst = $gRecordPage * $gRecordPageSize + 1
    Local $iLast = $iFirst + $gRecordPageSize - 1
    If $iLast > $gRecordEntryCount Then $iLast = $gRecordEntryCount
    For $i = $iFirst To $iLast
        _UI_ComboAddItem($gWnd, $gHistory, $gRecordEntries[$i][0])
        $gRecordMapCount += 1
        ReDim $gRecordMap[$gRecordMapCount + 1][2]
        $gRecordMap[$gRecordMapCount][0] = $gRecordEntries[$i][1]
        $gRecordMap[$gRecordMapCount][1] = $gRecordEntries[$i][2]
    Next
    _UI_ComboSetSelected($gWnd, $gHistory, -1)
    Local $sTip = "最近使用與收藏：第 " & ($gRecordPage + 1) & " / " & (RecordMaxPage() + 1) & " 頁；共 " & $gRecordEntryCount & " 筆，每頁最多 " & $gRecordPageSize & " 筆。"
    _UI_TooltipSetText($gWnd, $gHistory, $sTip)
    _UI_TooltipSetText($gWnd, $gRecordPrev, "上一頁｜" & $sTip)
    _UI_TooltipSetText($gWnd, $gRecordNext, "下一頁｜" & $sTip)
    _UI_SetEnabled($gWnd, $gRecordPrev, $gRecordPage > 0)
    _UI_SetEnabled($gWnd, $gRecordNext, $gRecordPage < RecordMaxPage())
EndFunc

; ----------------------------------------------------------------------------
; 「◀」「▶」換頁按鈕。
; ----------------------------------------------------------------------------
Func OnRecordPageClick($id)
    If $id = $gRecordPrev Then
        $gRecordPage -= 1
    ElseIf $id = $gRecordNext Then
        $gRecordPage += 1
    EndIf
    RenderRecordPage()
EndFunc

; ----------------------------------------------------------------------------
; 檢查模式是否已在收藏中。
; ----------------------------------------------------------------------------
Func IsFavorite($s)
    For $i = 1 To $gFavoriteCount
        If UnpackText(_IniRead($gHistoryFile, "Favorites", String($i), "", 256), "") = $s Then Return True
    Next
    Return False
EndFunc

; ----------------------------------------------------------------------------
; 把目前模式加入最近使用（最新的在第 1 筆，最多 $MAX_HISTORY 筆）。
; ----------------------------------------------------------------------------
Func RememberPattern()
    Local $s = GetPatternText()
    If $s = "" Then Return
    ; 與最新一筆相同就不重複記錄
    If $gHistoryCount > 0 Then
        If UnpackText(_IniRead($gHistoryFile, "History", "1", "", 256), "") = $s Then Return
    EndIf
    Local $iEnd = $gHistoryCount + 1
    If $iEnd > $MAX_HISTORY Then $iEnd = $MAX_HISTORY
    ; 舊紀錄往後推一格，最新的放在第 1 筆
    For $i = $iEnd To 2 Step -1
        _IniWrite($gHistoryFile, "History", String($i), _IniRead($gHistoryFile, "History", String($i - 1), "", 256), 256)
    Next
    _IniWrite($gHistoryFile, "History", "1", PackText($s), 256)
    $gHistoryCount = $iEnd
    _IniWrite($gHistoryFile, "Meta", "HistoryCount", String($gHistoryCount), 256)
    RefreshRecords()
EndFunc

; ----------------------------------------------------------------------------
; 「載入」按鈕：載入選取的紀錄，並依目前模式重新比對或取代。
; ----------------------------------------------------------------------------
Func OnLoadHistory($id)
    Local $i = _UI_ComboGetSelected($gWnd, $gHistory)
    If $i < 0 Or $i >= $gRecordMapCount Then Return
    Local $s = UnpackText(_IniRead($gHistoryFile, $gRecordMap[$i + 1][0], String($gRecordMap[$i + 1][1]), "", 256), "")
    If $s = "" Then Return
    SetPatternText($s)
    ValidatePattern()
    UpdatePreview()
    UpdateSyntax($gLastReplace)
    If $gLastReplace Then
        OnReplace(0)
    Else
        OnMatch(0)
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 「收藏」按鈕：把目前模式加入收藏（最多 $MAX_FAVORITES 筆）。
; ----------------------------------------------------------------------------
Func OnAddFavorite($id)
    Local $s = GetPatternText()
    If $s = "" Then Return
    If IsFavorite($s) Then Return _UI_SetText($gWnd, $gStatus, "此規則已在收藏中。")
    If $gFavoriteCount >= $MAX_FAVORITES Then Return _UI_SetText($gWnd, $gStatus, "收藏最多 " & $MAX_FAVORITES & " 筆。")
    $gFavoriteCount += 1
    _IniWrite($gHistoryFile, "Favorites", String($gFavoriteCount), PackText($s), 256)
    _IniWrite($gHistoryFile, "Meta", "FavoriteCount", String($gFavoriteCount), 256)
    RefreshRecords()
    _UI_SetText($gWnd, $gStatus, "已收藏目前的正規表示式。")
EndFunc

; ----------------------------------------------------------------------------
; 「刪除」按鈕：刪除選取的收藏或最近使用紀錄。
; ----------------------------------------------------------------------------
Func OnDeleteRecord($id)
    Local $i = _UI_ComboGetSelected($gWnd, $gHistory)
    If $i < 0 Or $i >= $gRecordMapCount Then Return _UI_SetText($gWnd, $gStatus, "請先從『最近使用與收藏』選取要刪除的項目。")
    Local $sSection = $gRecordMap[$i + 1][0]
    Local $iDelete = $gRecordMap[$i + 1][1]
    Local $iMax = $gHistoryCount
    If $sSection = "Favorites" Then $iMax = $gFavoriteCount
    ; 後面的項目往前補位，最後一格清空
    For $j = $iDelete To $iMax - 1
        _IniWrite($gHistoryFile, $sSection, String($j), _IniRead($gHistoryFile, $sSection, String($j + 1), "", 256), 256)
    Next
    _IniWrite($gHistoryFile, $sSection, String($iMax), "", 256)
    If $sSection = "Favorites" Then
        $gFavoriteCount -= 1
        _IniWrite($gHistoryFile, "Meta", "FavoriteCount", String($gFavoriteCount), 256)
    Else
        $gHistoryCount -= 1
        _IniWrite($gHistoryFile, "Meta", "HistoryCount", String($gHistoryCount), 256)
    EndIf
    RefreshRecords()
    _UI_ComboSetSelected($gWnd, $gHistory, -1)
    _UI_SetText($gWnd, $gStatus, "已刪除選取的" & ($sSection = "Favorites" ? "收藏" : "最近紀錄") & "。")
EndFunc

; ----------------------------------------------------------------------------
; 「清除最近紀錄」按鈕：只清除最近使用，保留收藏。
; ----------------------------------------------------------------------------
Func OnClearHistory($id)
    $gRecordPage = 0
    $gHistoryCount = 0
    _IniWrite($gHistoryFile, "Meta", "HistoryCount", "0", 256)
    RefreshRecords()
    _UI_SetText($gWnd, $gStatus, "已清除最近紀錄；收藏保留。")
EndFunc

#EndRegion

#Region ;===== 設定（Regex4AutoIt.ini） =====

; ----------------------------------------------------------------------------
; 從 Regex4AutoIt.ini 讀取外觀、AutoIt3.exe 路徑、Flag 與取代次數，並限制在合法範圍。
; ----------------------------------------------------------------------------
Func LoadSettings()
    $gFontName = _IniRead($gIni, "Appearance", "FontFamily", "Microsoft JhengHei", 256)
    $gFontPercent = _Max(70, _Min(160, Number(_IniRead($gIni, "Appearance", "FontSize", "100", 256))))
    $gEditorPixels = _Max(12, _Min(36, Number(_IniRead($gIni, "Appearance", "EditorPixels", "12", 256))))
    SetTheme(_Max(0, _Min(4, Number(_IniRead($gIni, "Appearance", "ClipboardTheme", "0", 256)))))
    $gAutoItExe = _IniRead($gIni, "Runtime", "AutoIt3Exe", "", 256)
    ; 舊版設定若未記錄旗標，預設使用 3（全域比對）。
    Local $iSavedFlag = Number(_IniRead($gIni, "Regex", "MatchFlag", "3", 256))
    If $iSavedFlag < 0 Or $iSavedFlag > 4 Then $iSavedFlag = 3
    Local $sSavedCount = _IniRead($gIni, "Regex", "ReplaceCount", "0", 256)
    If Not StringRegExp($sSavedCount, "^\d{1,7}$") Then $sSavedCount = "0"
    If Number($sSavedCount) > 1000000 Then $sSavedCount = "0"
    $gLoading = True
    _UI_ComboSetSelected($gWnd, $gFlag, $iSavedFlag)
    _UI_SetText($gWnd, $gReplaceFlag, $sSavedCount)
    $gLoading = False
    ApplyFontSize()
EndFunc

; ----------------------------------------------------------------------------
; 把外觀設定與 AutoIt3.exe 路徑寫入 INI，並讀回驗證。
; 回傳：True＝全部寫入成功；失敗時 @error=1
; ----------------------------------------------------------------------------
Func SaveSettings()
    Local $rows[4][2] = [["FontFamily", $gFontName], ["FontSize", String($gFontPercent)], ["EditorPixels", String($gEditorPixels)], ["ClipboardTheme", String($gTheme)]]
    Local $ok = True
    For $i = 0 To 3
        _IniWrite($gIni, "Appearance", $rows[$i][0], $rows[$i][1], 256)
        If _IniRead($gIni, "Appearance", $rows[$i][0], "__MISSING__", 256) <> $rows[$i][1] Then $ok = False
    Next
    _IniWrite($gIni, "Runtime", "AutoIt3Exe", $gAutoItExe, 256)
    If _IniRead($gIni, "Runtime", "AutoIt3Exe", "__MISSING__", 256) <> $gAutoItExe Then $ok = False
    Return SetError(($ok ? 0 : 1), 0, $ok)
EndFunc

; ----------------------------------------------------------------------------
; 設定複製 AU3 程式碼時使用的配色（0～4，名稱見 $gThemeNames）。
; ----------------------------------------------------------------------------
Func SetTheme($index)
    $gTheme = _Max(0, _Min(4, Int($index)))
    ; 16 種樣式色：0 預設 1 行註解 2 區塊註解 3 數字 4 函式 5 關鍵字 6 巨集 7 字串
    ;              8 運算子 9 變數 10 Send 鍵 11 前置指令 12 特殊 13 縮寫 14 COM 15 標準 UDF
    Local $themes[5][16] = [ _
        ["000000", "009933", "669900", "AC00A9", "000090", "0000FF", "FF33FF", "9999CC", "FF0000", "AA0000", "FF8800", "F000FF", "A00FF0", "FF0000", "0000FF", "0080FF"], _
        ["202020", "237A29", "237A29", "8F176D", "174D8D", "0000B5", "8F176D", "9C3E00", "B3261E", "7B1515", "666000", "7545A0", "7545A0", "B3261E", "0000B5", "146A75"], _
        ["17324D", "39715A", "39715A", "7955A0", "16558E", "004C99", "7B3DA1", "8A4B1F", "A83932", "963454", "355A6A", "4B50A6", "4B50A6", "A83932", "004C99", "007477"], _
        ["213C2E", "3E7E36", "3E7E36", "835E17", "2B5F76", "166044", "76529A", "90652B", "A93F32", "9B3B53", "5B6331", "67588D", "67588D", "A93F32", "166044", "2B7773"], _
        ["30243F", "587547", "587547", "A2406A", "4C4D91", "6533A1", "A03D7A", "84603B", "AD3D51", "8C3159", "765729", "6C55A0", "6C55A0", "AD3D51", "6533A1", "326C8B"]]
    For $i = 0 To 15
        $gClipColors[$i] = $themes[$gTheme][$i]
        $gClipBold[$i] = ($i = 3 Or $i = 4 Or $i = 5 Or $i = 6 Or $i = 9 Or $i = 15)
        $gClipItalic[$i] = ($i = 1 Or $i = 2)
    Next
EndFunc

; ----------------------------------------------------------------------------
; 登記需要套用字型設定的控制項（不重複）。
; ----------------------------------------------------------------------------
Func RegisterFontId($id)
    If $id <= 0 Then Return $id
    For $i = 1 To $gAllFontCount
        If $gAllFontIds[$i] = $id Then Return $id
    Next
    $gAllFontCount += 1
    ReDim $gAllFontIds[$gAllFontCount + 1]
    $gAllFontIds[$gAllFontCount] = $id
    Return $id
EndFunc

; ----------------------------------------------------------------------------
; 把字型名稱與大小套用到所有已登記的控制項。
; ----------------------------------------------------------------------------
Func ApplyFontSize()
    ; 診斷字串僅供除錯：API 回傳成功不代表畫面已實際套用字型
    $gFontDiagnostic = "API success does NOT verify visual font rendering" & @CRLF
    For $i = 1 To $gAllFontCount
        Local $id = $gAllFontIds[$i], $size = 16 * $gFontPercent / 100
        ; 編輯區使用「預覽區字級」（像素），其餘控制項依百分比縮放
        If $id = $gPattern Or $id = $gSource Or $id = $gReplacement Or $id = $gSyntax Or $id = $gOutput Then $size = $gEditorPixels
        Local $r1 = _UI_SetFont($gWnd, $id, $gFontName, $size), $e1 = @error
        Local $r2 = _UI_SetFontSize($gWnd, $id, $size), $e2 = @error
        $gFontDiagnostic &= "id=" & $id & " font=" & $r1 & "/" & $e1 & " size=" & $r2 & "/" & $e2 & @CRLF
    Next
    UpdatePreview()
    Return 1
EndFunc

; ----------------------------------------------------------------------------
; 「⚙」按鈕：開啟設定視窗（配色、字型、字級、AutoIt3.exe 路徑）。
; ----------------------------------------------------------------------------
Func OnOpenSettings($id)
    If $gSettingsWindow <> 0 And _UI_IsAlive($gSettingsWindow) Then
        _UI_WindowShowModal($gSettingsWindow, $gWnd)
        Return
    EndIf
    $gSettingsWindow = _UI_WindowCreateEx($APP_NAME & "｜設定", 0, 0, 650, 435, $gWindowFlags)
    If $gSettingsWindow = 0 Then Return
    _UI_WindowCenter($gSettingsWindow)
    $gThemeCombo = _UI_Combo($gSettingsWindow, 0, $gThemeNames, $gTheme, 16, 48, 618, 32)
    _UI_TooltipSetText($gSettingsWindow, $gThemeCombo, "AutoIt程式碼的配色風格")
    $gFontInput = _UI_Input($gSettingsWindow, 0, "字型名稱", $gFontName, 16, 100, 618, 32)
    $gSettingsSize = _UI_NumberInput($gSettingsWindow, 0, $gFontPercent, 70, 160, 5, 16, 150, 294, 32)
    $gEditorInput = _UI_NumberInput($gSettingsWindow, 0, $gEditorPixels, 12, 36, 1, 340, 150, 294, 32)
    $gAutoItPathInput = _UI_Input($gSettingsWindow, 0, "AutoIt3.exe 執行檔路徑", $gAutoItExe, 16, 220, 505, 36)
    Local $browse = _UI_Button($gSettingsWindow, 0, "瀏覽…", $AUI_VAR_DEFAULT, 531, 220, 103, 36)
    _UI_TooltipSetText($gSettingsWindow, $gAutoItPathInput, "指定 AutoIt3.exe；執行 AU3 範例時使用")
    _UI_TooltipSetText($gSettingsWindow, $gSettingsSize, "介面字體縮放百分比")
    _UI_TooltipSetText($gSettingsWindow, $gEditorInput, "預覽區字級")
    Local $note = _UI_Text($gSettingsWindow, 0, "設定變更後會自動套用並寫入 INI。", 16, 280, 618, 34)
    _UI_SetWrap($gSettingsWindow, $note, True)
    Local $close = _UI_Button($gSettingsWindow, 0, "關閉設定", $AUI_VAR_DEFAULT, 16, 345, 618, 40)
    _UI_OnValue($gSettingsWindow, $gThemeCombo, "OnSettingsLiveChange")
    _UI_OnChange($gSettingsWindow, $gFontInput, "OnSettingsLiveChange")
    _UI_OnNumberChange($gSettingsWindow, $gSettingsSize, "OnSettingsLiveChange")
    _UI_OnNumberChange($gSettingsWindow, $gEditorInput, "OnSettingsLiveChange")
    _UI_OnChange($gSettingsWindow, $gAutoItPathInput, "OnSettingsLiveChange")
    _UI_OnClick($gSettingsWindow, $browse, "OnBrowseAutoIt")
    _UI_OnClick($gSettingsWindow, $close, "OnSettingsCloseButton")
    _UI_OnClose($gSettingsWindow, "OnSettingsClose")
    _UI_WindowShowModal($gSettingsWindow, $gWnd)
EndFunc

; ----------------------------------------------------------------------------
; 設定值變動：以 _UI_PostTask 延後套用，避免在事件中重複處理。
; ----------------------------------------------------------------------------
Func OnSettingsLiveChange($id, $value)
    If $gSettingsSavePending Then Return
    $gSettingsSavePending = True
    If Not _UI_PostTask("SettingsPosted", 0) Then $gSettingsSavePending = False
EndFunc

; ----------------------------------------------------------------------------
; 實際套用設定：讀取設定視窗的值、套用字型與配色並寫入 INI。
; ----------------------------------------------------------------------------
Func SettingsPosted($data)
    $gSettingsSavePending = False
    If $gSettingsWindow = 0 Or Not _UI_IsAlive($gSettingsWindow) Then Return
    Local $name = StringStripWS(_UI_GetText($gSettingsWindow, $gFontInput), 3)
    Local $size = _UI_NumberInputGetValue($gSettingsWindow, $gSettingsSize), $e1 = @error
    Local $pixels = _UI_NumberInputGetValue($gSettingsWindow, $gEditorInput), $e2 = @error
    If $name = "" Or $e1 Or $e2 Then Return
    $gFontName = $name
    $gFontPercent = Int($size)
    $gEditorPixels = Int($pixels)
    $gAutoItExe = StringStripWS(_UI_GetText($gSettingsWindow, $gAutoItPathInput), 3)
    SetTheme(_UI_ComboGetSelected($gSettingsWindow, $gThemeCombo))
    ApplyFontSize()
    SaveSettings()
    MarkDirty()
EndFunc

; ----------------------------------------------------------------------------
; 「瀏覽…」按鈕：選擇 AutoIt3.exe。
; ----------------------------------------------------------------------------
Func OnBrowseAutoIt($id)
    Local $path = FileOpenDialog("選擇 AutoIt3.exe", @ProgramFilesDir, "執行檔 (AutoIt3.exe)|執行檔 (*.exe)", 1, "AutoIt3.exe")
    If @error Or $path = "" Then Return
    _UI_SetText($gSettingsWindow, $gAutoItPathInput, $path)
    OnSettingsLiveChange($id, 0)
EndFunc

; ----------------------------------------------------------------------------
; 「關閉設定」按鈕：先套用設定再關閉視窗。
; ----------------------------------------------------------------------------
Func OnSettingsCloseButton($id)
    SettingsPosted(0)
    If $gSettingsWindow <> 0 Then _UI_WindowClose($gSettingsWindow)
EndFunc

; ----------------------------------------------------------------------------
; 設定視窗已關閉：重設相關變數。
; ----------------------------------------------------------------------------
Func OnSettingsClose($wnd)
    $gSettingsWindow = 0
    $gAutoItPathInput = 0
    $gSettingsSavePending = False
EndFunc

#EndRegion

#Region ;===== 測試檔案（JSON 格式 .txt） =====

; ----------------------------------------------------------------------------
; 「測試檔案」按鈕：顯示儲存／讀取選單。
; ----------------------------------------------------------------------------
Func OpenFileMenu($id)
    If LoadDialogBusy() Then Return
    _UI_ContextMenuShowAt($gWnd, $gFileMenu, 634, 630)
EndFunc

; ----------------------------------------------------------------------------
; 測試檔案選單：0＝儲存；1＝讀取。
; ----------------------------------------------------------------------------
Func FileMenuSelected($id, $value)
    If LoadDialogBusy() Then Return
    Switch Number($value)
        Case 0
            SaveTest(0)
        Case 1
            LoadTest(0)
    EndSwitch
EndFunc

; ----------------------------------------------------------------------------
; 讀取確認對話框是否仍開啟中（開啟中則忽略重複操作）。
; ----------------------------------------------------------------------------
Func LoadDialogBusy()
    If $gLoadDialog = 0 Then Return False
    If _UI_DialogGetOpen($gWnd, $gLoadDialog) Then Return True
    ClearPendingLoad()
    Return False
EndFunc

; ----------------------------------------------------------------------------
; 把模式、測試文字、取代內容、Flag、取代次數與模式另存為 JSON 格式的 .txt 測試檔。
; ----------------------------------------------------------------------------
Func SaveTest($id)
    If $gSavingTest Then Return
    Local $count = CountValue()
    If @error Then Return ShowMessage("設定錯誤", "取代次數必須為 0～1000000。")
    Local $flag = _UI_ComboGetSelected($gWnd, $gFlag)
    If $flag < 0 Or $flag > 4 Then Return ShowMessage("設定錯誤", "請先選取 Flag。")
    Local $path = FileSaveDialog("另存測試 TXT", @ScriptDir, "測試文字 (*.txt)", 16, "Regex4AutoIt_Test.txt", $gWnd)
    If @error Or $path = "" Then Return
    If StringLower(StringRight($path, 4)) <> ".txt" Then
        $path &= ".txt"
        If FileExists($path) Then Return ShowMessage("檔名已存在", "請重新選取含 .txt 副檔名的完整檔名，再確認覆寫。")
    EndIf
    $gSavingTest = True
    Local $doc = _UI_JsonCreateObject()
    If $doc = 0 Then
        $gSavingTest = False
        Return ShowMessage("儲存失敗", "無法建立測試文件。")
    EndIf
    Local $ok = True
    If Not _UI_JsonSet($doc, "/format", "Regex4AutoIt.Test") Then $ok = False
    If Not _UI_JsonSet($doc, "/version", 1) Then $ok = False
    If Not _UI_JsonSet($doc, "/pattern", GetPatternText()) Then $ok = False
    If Not _UI_JsonSet($doc, "/source", _UI_GetText($gWnd, $gSource)) Then $ok = False
    If Not _UI_JsonSet($doc, "/replacement", _UI_GetText($gWnd, $gReplacement)) Then $ok = False
    If Not _UI_JsonSet($doc, "/flag", Int($flag)) Then $ok = False
    If Not _UI_JsonSet($doc, "/replaceCount", Int($count)) Then $ok = False
    If Not _UI_JsonSet($doc, "/mode", ($gLastReplace ? "replace" : "match")) Then $ok = False
    If $ok Then $ok = (_UI_JsonSaveFile($doc, $path, 2, $AUI_JSON_FILE_UTF8) <> 0)
    _UI_JsonFree($doc)
    $gSavingTest = False
    If $ok Then
        $gSessionPath = $path
        _UI_SetText($gWnd, $gStatus, "已儲存：" & SessionFileName($path))
    Else
        ShowMessage("儲存失敗", "無法寫入測試 TXT。")
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 讀取測試檔、驗證格式後，跳出確認對話框（確認後由 LoadConfirmed 套用）。
; ----------------------------------------------------------------------------
Func LoadTest($id)
    If LoadDialogBusy() Then Return
    Local $path = FileOpenDialog("讀取測試 TXT", @ScriptDir, "測試文字 (*.txt)", 1, "", $gWnd)
    If @error Or $path = "" Then Return
    Local $doc = _UI_JsonLoadFile($path)
    If $doc = 0 Then Return ShowMessage("讀取失敗", "無法解析測試 TXT。")
    If Not ValidateTestDoc($doc) Then
        _UI_JsonFree($doc)
        Return ShowMessage("格式錯誤", "這不是有效的測試 TXT；目前內容未更改。")
    EndIf
    Local $pattern = _UI_JsonGetString($doc, "pattern"), $e1 = @error
    Local $source = _UI_JsonGetString($doc, "source"), $e2 = @error
    Local $replacement = _UI_JsonGetString($doc, "replacement"), $e3 = @error
    Local $flag = _UI_JsonGetInt64($doc, "flag"), $e4 = @error
    Local $count = _UI_JsonGetInt64($doc, "replaceCount"), $e5 = @error
    Local $mode = _UI_JsonGetString($doc, "mode"), $e6 = @error
    _UI_JsonFree($doc)
    If $e1 Or $e2 Or $e3 Or $e4 Or $e5 Or $e6 Then Return ShowMessage("讀取失敗", "欄位讀取失敗；目前內容未更改。")
    $gLoadValues[0] = $pattern
    $gLoadValues[1] = $source
    $gLoadValues[2] = $replacement
    $gLoadValues[3] = $flag
    $gLoadValues[4] = $count
    $gLoadValues[5] = $mode
    $gLoadPath = $path
    $gLoadDialog = _UI_Dialog($gWnd, "讀取測試檔案", "以「" & SessionFileName($path) & "」取代目前測試？" & @CRLF & "尚未儲存的內容會被取代。", "取消|讀取")
    If $gLoadDialog = 0 Then
        ClearPendingLoad()
        Return ShowMessage("讀取失敗", "無法建立確認對話框。")
    EndIf
    _UI_DialogSetDefaultButton($gWnd, $gLoadDialog, 0)
    _UI_DialogSetCancelButton($gWnd, $gLoadDialog, 0)
    If Not _UI_OnValue($gWnd, $gLoadDialog, "LoadConfirmed") Then
        _UI_DialogClose($gWnd, $gLoadDialog)
        ClearPendingLoad()
        ShowMessage("讀取失敗", "無法綁定確認事件。")
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 驗證測試檔 JSON 結構：欄位型別、格式名稱、版本與數值範圍。
; 回傳：True＝格式正確
; ----------------------------------------------------------------------------
Func ValidateTestDoc($doc)
    If _UI_JsonType($doc) <> $AUI_JSON_OBJECT Then Return False
    Local $strings[5] = ["format", "pattern", "source", "replacement", "mode"]
    For $i = 0 To 4
        If _UI_JsonType($doc, $strings[$i]) <> $AUI_JSON_STRING Then Return False
    Next
    Local $ints[3] = ["version", "flag", "replaceCount"]
    For $i = 0 To 2
        If _UI_JsonType($doc, $ints[$i]) <> $AUI_JSON_INT Then Return False
    Next
    ; "RegexAUI.Test" 為舊版格式名稱，保留相容
    Local $format = _UI_JsonGetString($doc, "format")
    If $format <> "RegexAUI.Test" And $format <> "Regex4AutoIt.Test" Then Return False
    If _UI_JsonGetInt64($doc, "version") <> 1 Then Return False
    Local $flag = _UI_JsonGetInt64($doc, "flag"), $ef = @error
    Local $count = _UI_JsonGetInt64($doc, "replaceCount"), $ec = @error
    Local $mode = _UI_JsonGetString($doc, "mode")
    If $ef Or $ec Or $flag < 0 Or $flag > 4 Or $count < 0 Or $count > 1000000 Then Return False
    Return $mode = "match" Or $mode = "replace"
EndFunc

; ----------------------------------------------------------------------------
; 讀取確認對話框回應：選「讀取」（1）時把測試檔內容套用到畫面。
; ----------------------------------------------------------------------------
Func LoadConfirmed($id, $value)
    If $id <> $gLoadDialog Then Return
    If Number($value) <> 1 Then
        ClearPendingLoad()
        Return _UI_SetText($gWnd, $gStatus, "已取消讀取")
    EndIf
    $gLoading = True
    SetPatternText($gLoadValues[0])
    _UI_SetText($gWnd, $gSource, $gLoadValues[1])
    _UI_SetText($gWnd, $gReplacement, $gLoadValues[2])
    _UI_SetText($gWnd, $gReplaceFlag, String($gLoadValues[4]))
    _UI_ComboSetSelected($gWnd, $gFlag, $gLoadValues[3])
    _IniWrite($gIni, "Regex", "MatchFlag", String($gLoadValues[3]), 256)
    _IniWrite($gIni, "Regex", "ReplaceCount", String($gLoadValues[4]), 256)
    _UI_ComboSetSelected($gWnd, $gPresets, -1)
    _UI_ComboSetSelected($gWnd, $gReplacePresets, -1)
    $gLastReplace = ($gLoadValues[5] = "replace")
    $gLoading = False
    $gSessionPath = $gLoadPath
    Local $name = SessionFileName($gLoadPath)
    ClearPendingLoad()
    MarkDirty()
    _UI_SetText($gWnd, $gStatus, "已讀取：" & $name)
EndFunc

; ----------------------------------------------------------------------------
; 清除待讀取的測試檔暫存資料。
; ----------------------------------------------------------------------------
Func ClearPendingLoad()
    $gLoadDialog = 0
    $gLoadPath = ""
    For $i = 0 To 5
        $gLoadValues[$i] = ""
    Next
EndFunc

; ----------------------------------------------------------------------------
; 從完整路徑取出檔名。
; ----------------------------------------------------------------------------
Func SessionFileName($path)
    Return StringRegExpReplace($path, "^.*[\\/]", "")
EndFunc

#EndRegion

#Region ;===== 對話框與關於 =====

; ----------------------------------------------------------------------------
; 顯示只有「確定」按鈕的 AUI 對話框；建立失敗時改顯示於狀態列。
; $owner：擁有者視窗，預設為主視窗
; ----------------------------------------------------------------------------
Func ShowMessage($title, $body, $owner = 0)
    If $owner = 0 Then $owner = $gWnd
    Local $dialog = _UI_Dialog($owner, $title, $body, "確定")
    If $dialog <> 0 Then
        _UI_DialogSetDefaultButton($owner, $dialog, 0)
        _UI_DialogSetCancelButton($owner, $dialog, 0)
    Else
        _UI_SetText($gWnd, $gStatus, $title & "：" & $body)
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 「！」按鈕：顯示關於資訊（版本、AUI 與 AutoIt 版本）。
; ----------------------------------------------------------------------------
Func OnAbout($id)
    ShowMessage("關於 " & $APP_NAME, $APP_NAME & " v" & $APP_VERSION & @CRLF & @CRLF & _
            "grayfree 2026 Unlicense." & @CRLF & _
            "https://www.grayfree.tw/" & @CRLF & @CRLF & _
            "ＡＩ　　　 ：Perplexity" & @CRLF & _
            "ＡＵＩ 版本：" & _UI_Version() & @CRLF & _
            "ＡＵ３ 版本：" & @AutoItVersion)
EndFunc

#EndRegion

#Region ;===== 剪貼簿（純文字＋HTML＋RTF） =====

; ----------------------------------------------------------------------------
; 以純文字＋HTML＋RTF 格式複製 AU3 程式碼，貼到 Word／論壇編輯器時保留配色。
; $full：True＝完整範例程式；False＝單行語法
; ----------------------------------------------------------------------------
Func CopyAu3Rich($full)
    UpdateSyntax($gLastReplace)
    Local $code = $gGeneratedCode
    If $full Then $code = BuildFullCode($gLastReplace)
    Local $rich = Au3RichFormats($code)
    If RichClipboard($code, $rich[0], $rich[1]) Then
        Local $names = StringSplit($gThemeNames, "|", 1)
        _UI_SetText($gWnd, $gStatus, "已複製" & ($full ? "完整" : "單行") & " AU3｜" & $names[$gTheme + 1] & "｜無背景")
    Else
        ShowMessage("複製失敗", "剪貼簿可能被其他程式占用。")
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 簡易 AutoIt 詞法上色，同時產生 HTML 與 RTF。
; 回傳：陣列 [0]＝HTML（<pre>）、[1]＝RTF
; ----------------------------------------------------------------------------
Func Au3RichFormats($code)
    Local $html = '<pre style="font-family:Consolas,monospace;font-size:12pt;white-space:pre;tab-size:4">'
    Local $rtf = '{\rtf1\ansi\deff0{\fonttbl{\f0 Consolas;}}{\colortbl;'
    For $i = 0 To 15
        Local $c = $gClipColors[$i]
        $rtf &= '\red' & Dec(StringLeft($c, 2)) & '\green' & Dec(StringMid($c, 3, 2)) & '\blue' & Dec(StringRight($c, 2)) & ';'
    Next
    $rtf &= '}\f0\fs24\uc1 '
    Local $i = 1, $n = StringLen($code), $ch, $token, $style, $j, $q, $m, $word, $block = False
    Local $keywords = '|and|byref|case|const|continuecase|continueloop|default|dim|do|else|elseif|endfunc|endif|endselect|endswitch|endwith|enum|exit|exitloop|false|for|func|global|if|in|local|next|not|null|or|redim|return|select|static|step|switch|then|to|true|until|wend|while|with|'
    Local $builtins = '|stringregexp|stringregexpreplace|string|stringlen|stringreplace|stringmid|stringleft|stringright|stringformat|ubound|isarray|msgbox|consolewrite|seterror|setextended|chr|chrw|number|int|round|timerinit|timerdiff|fileopen|fileclose|fileread|filewrite|clipput|'
    While $i <= $n
        $ch = StringMid($code, $i, 1)
        $token = $ch
        $style = 0
        If $ch = @CR And StringMid($code, $i + 1, 1) = @LF Then
            $token = @CRLF
        ElseIf $block Then
            $j = $i
            While $j <= $n And StringMid($code, $j, 1) <> @CR And StringMid($code, $j, 1) <> @LF
                $j += 1
            WEnd
            If $j > $i Then
                $token = StringMid($code, $i, $j - $i)
                $style = 2
                If StringRegExp(StringStripWS($token, 1), "(?i)^#(?:ce|comments-end)\b") Then $block = False
            EndIf
        ElseIf $ch = '"' Or $ch = "'" Then
            $q = $ch
            $j = $i + 1
            While $j <= $n
                If StringMid($code, $j, 1) = $q Then
                    If StringMid($code, $j + 1, 1) = $q Then
                        $j += 2
                        ContinueLoop
                    EndIf
                    $j += 1
                    ExitLoop
                EndIf
                $j += 1
            WEnd
            $token = StringMid($code, $i, $j - $i)
            $style = 7
        ElseIf $ch = ';' Then
            $j = $i
            While $j <= $n And StringMid($code, $j, 1) <> @CR And StringMid($code, $j, 1) <> @LF
                $j += 1
            WEnd
            $token = StringMid($code, $i, $j - $i)
            $style = 1
        ElseIf $ch = '$' Or $ch = '@' Or $ch = '#' Then
            Local $lead = "^[\$@][A-Za-z_][A-Za-z_0-9]*"
            If $ch = '#' Then $lead = "^#[A-Za-z_][A-Za-z_0-9-]*"
            $m = StringRegExp(StringMid($code, $i), $lead, 2)
            If IsArray($m) Then $token = $m[0]
            If $ch = '$' Then $style = 9
            If $ch = '@' Then $style = 6
            If $ch = '#' Then
                $style = 11
                If StringLower($token) = '#cs' Or StringLower($token) = '#comments-start' Then $block = True
            EndIf
        ElseIf StringRegExp($ch, "[0-9]") Then
            $m = StringRegExp(StringMid($code, $i), "^(?:0[xX][0-9A-Fa-f]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)", 2)
            If IsArray($m) Then $token = $m[0]
            $style = 3
        ElseIf StringRegExp($ch, "[A-Za-z_]") Then
            $m = StringRegExp(StringMid($code, $i), "^[A-Za-z_][A-Za-z_0-9]*", 2)
            If IsArray($m) Then $token = $m[0]
            $word = StringLower($token)
            If StringInStr($keywords, '|' & $word & '|', 1) Then
                $style = 5
            ElseIf StringInStr($builtins, '|' & $word & '|', 1) Then
                $style = 4
            ElseIf StringLeft($token, 1) = '_' Then
                $style = 15
            EndIf
        ElseIf StringInStr('+-*/&=<>[](),^', $ch, 1) Then
            $style = 8
        EndIf
        Local $css = 'color:#' & $gClipColors[$style]
        If $gClipBold[$style] Then $css &= ';font-weight:bold'
        If $gClipItalic[$style] Then $css &= ';font-style:italic'
        $html &= '<span style="' & $css & '">' & EscapeHTML($token) & '</span>'
        $rtf &= '\cf' & ($style + 1) & ($gClipBold[$style] ? '\b' : '\b0') & ($gClipItalic[$style] ? '\i' : '\i0') & ' ' & RtfEscape($token)
        $i += StringLen($token)
    WEnd
    Local $result[2] = [$html & '</pre>', $rtf & '}']
    Return $result
EndFunc

; ----------------------------------------------------------------------------
; 跳脫 RTF 特殊字元；非 ASCII 字元轉為 \uN? 形式。
; ----------------------------------------------------------------------------
Func RtfEscape($text)
    Local $out = "", $i = 1, $n = StringLen($text), $ch, $u
    While $i <= $n
        $ch = StringMid($text, $i, 1)
        Switch $ch
            Case '\', '{', '}'
                $out &= '\' & $ch
            Case @CR
                If StringMid($text, $i + 1, 1) = @LF Then $i += 1
                $out &= '\par ' & @CRLF
            Case @LF
                $out &= '\par ' & @CRLF
            Case @TAB
                $out &= '\tab '
            Case Else
                $u = AscW($ch)
                If $u >= 32 And $u <= 126 Then
                    $out &= $ch
                Else
                    If $u > 32767 Then $u -= 65536
                    $out &= '\u' & $u & '?'
                EndIf
        EndSwitch
        $i += 1
    WEnd
    Return $out
EndFunc

; ----------------------------------------------------------------------------
; 組成 Windows 剪貼簿 CF_HTML 格式（含 StartHTML／StartFragment 等位移標頭）。
; 回傳：UTF-8 Binary
; ----------------------------------------------------------------------------
Func CfHtmlBytes($fragment)
    Local $prefix = '<html><body><!--StartFragment-->', $suffix = '<!--EndFragment--></body></html>'
    ; 先用 0 佔位計算標頭長度，再填入實際位元組位移（UTF-8）
    Local $header = "Version:1.0" & @CRLF & "StartHTML:0000000000" & @CRLF & "EndHTML:0000000000" & @CRLF & "StartFragment:0000000000" & @CRLF & "EndFragment:0000000000" & @CRLF
    Local $sh = BinaryLen(StringToBinary($header, 4)), $sf = $sh + BinaryLen(StringToBinary($prefix, 4)), $ef = $sf + BinaryLen(StringToBinary($fragment, 4)), $eh = $ef + BinaryLen(StringToBinary($suffix, 4))
    $header = "Version:1.0" & @CRLF & "StartHTML:" & StringFormat("%010d", $sh) & @CRLF & "EndHTML:" & StringFormat("%010d", $eh) & @CRLF & "StartFragment:" & StringFormat("%010d", $sf) & @CRLF & "EndFragment:" & StringFormat("%010d", $ef) & @CRLF
    Return StringToBinary($header & $prefix & $fragment & $suffix, 4)
EndFunc

; ----------------------------------------------------------------------------
; 配置可移動的全域記憶體並寫入資料（供 SetClipboardData 使用）。
; $zeros：結尾補 0 的位元組數（字串結束字元）
; 回傳：記憶體代碼；失敗回傳 0
; ----------------------------------------------------------------------------
Func ClipMemory($bytes, $zeros)
    Local $call = DllCall("kernel32.dll", "handle", "GlobalAlloc", "uint", 0x42, "ulong_ptr", BinaryLen($bytes) + $zeros)
    If @error Or Not IsArray($call) Then Return 0
    Local $mem = $call[0]
    If $mem = 0 Then Return 0
    $call = DllCall("kernel32.dll", "ptr", "GlobalLock", "handle", $mem)
    If @error Or Not IsArray($call) Then
        DllCall("kernel32.dll", "handle", "GlobalFree", "handle", $mem)
        Return 0
    EndIf
    If $call[0] = 0 Then
        DllCall("kernel32.dll", "handle", "GlobalFree", "handle", $mem)
        Return 0
    EndIf
    Local $data = DllStructCreate("byte[" & (BinaryLen($bytes) + $zeros) & "]", $call[0])
    DllStructSetData($data, 1, $bytes)
    DllCall("kernel32.dll", "bool", "GlobalUnlock", "handle", $mem)
    Return $mem
EndFunc

; ----------------------------------------------------------------------------
; 一次寫入多種剪貼簿格式：純文字、HTML Format、RTF（$rtf 為空則省略）。
; 回傳：True＝成功
; ----------------------------------------------------------------------------
Func RichClipboard($plain, $html, $rtf)
    Local $call = DllCall("user32.dll", "uint", "RegisterClipboardFormatW", "wstr", "HTML Format")
    If @error Or Not IsArray($call) Then Return False
    Local $htmlId = $call[0], $rtfId = 0
    If $htmlId = 0 Then Return False
    If $rtf <> "" Then
        $call = DllCall("user32.dll", "uint", "RegisterClipboardFormatW", "wstr", "Rich Text Format")
        If @error Or Not IsArray($call) Then Return False
        $rtfId = $call[0]
        If $rtfId = 0 Then Return False
    EndIf
    ; 依序放入：純文字（CF_UNICODETEXT=13）、HTML Format、RTF（可省略）
    Local $mem[3] = [ClipMemory(StringToBinary($plain, 2), 2), ClipMemory(CfHtmlBytes($html), 1), 0], $fmt[3] = [13, $htmlId, $rtfId], $count = 2, $failed = False, $opened = False
    If $rtfId Then
        $count = 3
        $mem[2] = ClipMemory(StringToBinary($rtf, 1), 1)
    EndIf
    For $i = 0 To $count - 1
        If $mem[$i] = 0 Then $failed = True
    Next
    ; 剪貼簿可能被其他程式占用，最多重試 5 次
    If Not $failed Then
        For $i = 1 To 5
            $call = DllCall("user32.dll", "bool", "OpenClipboard", "hwnd", $gWnd)
            If Not @error And IsArray($call) Then
                If $call[0] Then
                    $opened = True
                    ExitLoop
                EndIf
            EndIf
            Sleep(10)
        Next
    EndIf
    If Not $opened Then $failed = True
    If $opened Then
        $call = DllCall("user32.dll", "bool", "EmptyClipboard")
        If @error Or Not IsArray($call) Then
            $failed = True
        ElseIf Not $call[0] Then
            $failed = True
        EndIf
        If Not $failed Then
            For $i = 0 To $count - 1
                $call = DllCall("user32.dll", "handle", "SetClipboardData", "uint", $fmt[$i], "handle", $mem[$i])
                If @error Or Not IsArray($call) Then
                    $failed = True
                ElseIf $call[0] Then
                    $mem[$i] = 0
                Else
                    $failed = True
                EndIf
            Next
        EndIf
        DllCall("user32.dll", "bool", "CloseClipboard")
    EndIf
    ; SetClipboardData 成功後記憶體歸系統所有；未交出的才需自行釋放
    For $i = 0 To $count - 1
        If $mem[$i] Then DllCall("kernel32.dll", "handle", "GlobalFree", "handle", $mem[$i])
    Next
    Return Not $failed
EndFunc

#EndRegion
