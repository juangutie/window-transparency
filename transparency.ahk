#Requires AutoHotkey v1.1.33+
#SingleInstance Force
#InstallMouseHook
#Persistent

global DEFAULT_TRANSPARENCY := 0.95 * 255  ; default alpha value [0, 255]
global TRANSPARENCY_DELTA := 0.01 * 255  ; how much to change transparency with each scroll
global CHECK_INPUT_FREQUENCY := 20  ; milliseconds between each input check
global RIGHT_CLICK_DELAY := 1000  ; milliseconds before restoring right click
global FILE_EXPLORER_TIMEOUT := 1000  ; maximum milliseconds to wait for file explorer to open

global SELECT_WINDOW_OPTION := "&Select a Window"
global HOTKEY_ALT_T_OPTION := "&Alt+T to Toggle Transparency"
global HOTKEY_WIN_E_OPTION := "&Win+E to Open Transparent File Explorer"
global HOTKEY_SCROLL_WHEEL_OPTION := "&Scroll Wheel to Adjust Transparency"
global PREVIEW_TRANSPARENCY_OPTION := "&Preview Transparency on Hover"
global SELECT_WINDOW_TOOLTIP := "select a window..."

global ACTIVE_WINDOW := "A"
global TASKBAR_WINDOW := "ahk_class Shell_TrayWnd"

global transparency := DEFAULT_TRANSPARENCY
global transparencyFallback := transparency
global hotkeyScrollWheelOn := true
global previewTransparencyOn := false
global scrollDetected := false

; Automatically make taskbar transparent when script loads
turnOnTransparency(TASKBAR_WINDOW)

; Right click tray icon to see options
Menu, Tray, Icon, %A_ScriptDir%\window.ico
Menu, Tray, NoStandard
Menu, Tray, Add, %SELECT_WINDOW_OPTION%, windowSelection
Menu, Tray, Add, %HOTKEY_ALT_T_OPTION%, toggleHotkeyAltT
Menu, Tray, Add, %HOTKEY_WIN_E_OPTION%, toggleHotkeyWinE
Menu, Tray, Add, %HOTKEY_SCROLL_WHEEL_OPTION%, toggleHotkeyScrollWheel
Menu, Tray, Add, %PREVIEW_TRANSPARENCY_OPTION%, togglePreviewTransparency
Menu, Tray, Add
Menu, Tray, Standard
Menu, Tray, Check, %HOTKEY_ALT_T_OPTION%
Menu, Tray, Check, %HOTKEY_WIN_E_OPTION%
Menu, Tray, Check, %HOTKEY_SCROLL_WHEEL_OPTION%
Menu, Tray, UnCheck, %PREVIEW_TRANSPARENCY_OPTION%
Menu, Tray, Disable, %PREVIEW_TRANSPARENCY_OPTION%

; Left click tray icon to select a window to make transparent
Menu, Tray, Default, %SELECT_WINDOW_OPTION%
Menu, Tray, Click, 1
Hotkey, RButton, doNothing, Off

; Scroll up/down during window selection to adjust transparency value
Hotkey, WheelUp, increaseTransparencyValue, Off
Hotkey, WheelDown, decreaseTransparencyValue, Off

; Press Alt+T to toggle transparency of active window
Hotkey, $!t, toggleTransparency

; Press Windows+E to open a transparent file explorer
Hotkey, $#e, openFileExplorer
return

windowSelection() {
    transparencyFallback := transparency

    if (hotkeyScrollWheelOn)
    {
        Hotkey, WheelUp, On 
        Hotkey, WheelDown, On
    }

    Hotkey, RButton, On
    SetTimer, checkForInput, %CHECK_INPUT_FREQUENCY%
}

checkForInput() {
    static showTransparencyTooltip := false
    static savedWindowUnderMouse := ""
    static savedWindowOriginalTransparencyValue := ""

    leftClick := GetKeyState("LButton") == 1
    rightClick := GetKeyState("RButton", "P") == 1
    escapeKey := GetKeyState("Escape") == 1

    saveChanges := leftClick
    cancelChanges := escapeKey || rightClick
    endWindowSelection := saveChanges || cancelChanges

    if (endWindowSelection)
    {
        if (saveChanges)
        {
            if (!previewTransparencyOn)
                changeOrToggleTransparency(windowUnderMouse())
        }

        if (cancelChanges)
        {
            transparency := transparencyFallback

            if (previewTransparencyOn)
                if (savedWindowUnderMouse != "")
                    WinSet
                        , Transparent
                        , %savedWindowOriginalTransparencyValue%
                        , %savedWindowUnderMouse%
        }

        SetTimer, checkForInput, Off
        SetTimer, enableRightClick, -%RIGHT_CLICK_DELAY%
        Hotkey, WheelUp, Off
        Hotkey, WheelDown, Off
        scrollDetected := false
        showTransparencyTooltip := false
        savedWindowUnderMouse := ""
        savedWindowOriginalTransparencyValue := ""
        Tooltip
        return
    }

    if (scrollDetected)
    {
        showTransparencyTooltip := true

        if (previewTransparencyOn)
        {
            if (savedWindowOriginalTransparencyValue != Round(transparency))
                turnOnTransparency(savedWindowUnderMouse)
            else
                turnOffTransparency(savedWindowUnderMouse)
        }
    }

    if (showTransparencyTooltip)
    {
        if (Round(transparency) == Round(DEFAULT_TRANSPARENCY))
            Tooltip, % Round(100*transparency/255) . "% (default)"
        else
            Tooltip, % Round(100*transparency/255) . "%"
    }
    else
    {
        Tooltip, %SELECT_WINDOW_TOOLTIP%
    }

    if (previewTransparencyOn)
    {
        currentWindowUnderMouse := windowUnderMouse()
        if (currentWindowUnderMouse != savedWindowUnderMouse)
        {
            if (savedWindowUnderMouse != "")
            {
                WinSet
                    , Transparent
                    , %savedWindowOriginalTransparencyValue%
                    , %savedWindowUnderMouse%
            }

            savedWindowUnderMouse := currentWindowUnderMouse
            WinGet
                , savedWindowOriginalTransparencyValue
                , Transparent
                , %currentWindowUnderMouse%

            changeOrToggleTransparency(currentWindowUnderMouse)
        }
    }

    scrollDetected := false
}

turnOffTransparency(window := "A") {
    WinSet, Transparent, Off, %window%
}

turnOnTransparency(window := "A") {
    if (Round(transparency) < 255)
        WinSet, Transparent, % Round(transparency), %window%
    else
        turnOffTransparency(window)
}

toggleTransparency(window := "A") {
    WinGet, currentTransparency, Transparent, %window%
    if (currentTransparency == "")
        turnOnTransparency(window)
    else
        turnOffTransparency(window)
}

changeOrToggleTransparency(window := "A") {
    WinGet, currentTransparency, Transparent, %window%
    if (currentTransparency == "")
        currentTransparency := 255

    if (currentTransparency != Round(transparency))
        turnOnTransparency(window)
    else
        turnOffTransparency(window)
}

increaseTransparencyValue() {
    transparency := Min(255, transparency + TRANSPARENCY_DELTA)
    scrollDetected := true
}

decreaseTransparencyValue() {
    transparency := Max(0, transparency - TRANSPARENCY_DELTA)
    scrollDetected := true
}

openFileExplorer() {
    WinGetTitle, initialWindowTitle, A
    WinGet, initialWindow, ID, A
    Send, #e

    if (initialWindowTitle == "This PC")
    {
        WinWaitNotActive, %initialWindow%,, % FILE_EXPLORER_TIMEOUT/1000
        if (ErrorLevel == 1)
            return
    }

    WinWaitActive, % "This PC",, % FILE_EXPLORER_TIMEOUT/1000
    if (ErrorLevel == 1)
        return

    turnOnTransparency(ACTIVE_WINDOW)
}

enableRightClick() {
    Hotkey, RButton, Off
}

toggleHotkeyAltT() {
    Hotkey, $!t, Toggle
    Menu, Tray, ToggleCheck, %HOTKEY_ALT_T_OPTION%
}

toggleHotkeyWinE() {
    Hotkey, $#e, Toggle
    Menu, Tray, ToggleCheck, %HOTKEY_WIN_E_OPTION%
}

toggleHotkeyScrollWheel() {
    hotkeyScrollWheelOn := !hotkeyScrollWheelOn
    Menu, Tray, ToggleCheck, %HOTKEY_SCROLL_WHEEL_OPTION%
}

togglePreviewTransparency() {
    previewTransparencyOn := !previewTransparencyOn
    Menu, Tray, ToggleCheck, %PREVIEW_TRANSPARENCY_OPTION%
}

windowUnderMouse() {
    MouseGetPos,,, windowId
    return "ahk_id " . windowId
}

doNothing() {
    return
}