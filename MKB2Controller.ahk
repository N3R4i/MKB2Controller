;	Created by N3R4i
;	Modified: 2025-01-11
;
;	Description:
;		This is a highly customizable AutoHotkey script with a user friendly GUI that allows the user to control a virtual controller with mouse and keyboard.
;		Main usage is for emulators and games that don't have mouse&keyboard support. Supports both XInput and DirectInput. Requires ViGEmBus for the virtual controller.
;
;	Based on Helgef's and CemuUser8's mouse2joystick (https://github.com/CemuUser8/mouse2joystick_custom_CEMU)
;
;	Acknowledgements:
;			Helgef - Original mouse2joystic
;			CemuUser8 - mouse2joystick Custom CEMU version https://github.com/CemuUser8/mouse2joystick_custom_CEMU
;			Nefarius Software Solutions e.U. - ViGEmBus https://github.com/nefarius/ViGEmBus
;			evilC - AHK-ViGEm-Bus.ahk/ViGEmWrapper.dll https://github.com/evilC/AHK-ViGEm-Bus
;
version := "1.2.1"
#NoEnv						; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input				; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%	; Ensures a consistent starting directory.
#Include ViGEm-Bus.ahk		; Created by evilC. Modified by N3R4i to have unified button syntax between PS4/XBox
#Include SelfDeletingTimer.ahk	;https://autohotkey.com/boards/viewtopic.php?t=13010
; Settings
#MaxHotkeysPerInterval 210
#HotkeyInterval 1000
#InstallMouseHook
#SingleInstance Force
CoordMode,Mouse,Screen
SetMouseDelay,-1
SetBatchLines,-1

; On exit
OnExit("exitFunc")

IF (A_PtrSize < 8) {
	MsgBox,16,Now Requires 64bit, This program requires 64bit. If you are getting this error you must be running the script directly and have 32bit AutoHotkey installed.`n`nPlease change your AutoHotkey installation to the 64bit Unicode version 
	ExitApp
}

toggle:=1													; On/off parameter for the hotkey.	Toggle 0 means controller is on. The placement of this variable is disturbing.

; If no settings file, create, When changing this, remember to make corresponding changes after the setSettingsToDefault label (error handling) ; Currently at bottom of script
IfNotExist, settings.ini
{
	defaultSettings=
(
[General]
usevXBox=1
gameExe=
autoActivateGame=0
controllerSwitchKey=F1
exitKey=#q
hideCursor=1
[Mouse]
r=80
interval=1
minmove=0.37
acceleration=0
invertedX=0
invertedY=0
MouseStick=1
[Keyboard-Movement]
upKey=w
leftKey=a
downKey=s
rightKey=d
movementSmoothing=1
movementIncrement=0.9
walkModifierKey=LAlt
walkToggleMode=0
increaseWalkKey=NumpadAdd
decreaseWalkKey=NumpadSub
walkSpeed=0.50
invertedLX=0
invertedLY=0
MovementStick=0
[Keybinds]
joystickButtonKeyList=e,Escape,r,f,XButton1,LButton,RButton,MButton,,Tab,,q,Home,End,Left,Right
[Bloodborne]
joystickButtonKeyListBB=,,,,,,
)
	FileAppend,%defaultSettings%,settings.ini
	IF (ErrorLevel) {
		Msgbox,% 6+16,Error writing to file., There was a problem creating settings.ini
		, make sure you have permission to write to file at %A_ScriptDir%. If the problem persists`, try to run as administrator or change the script directory. Press retry to try again`, continue to set all settings to default or cancel to exit application.
		IfMsgBox Retry
			reload
		Else IfMsgBox Continue
			Goto, setSettingsToDefault	; Currently at bottom of script
		Else 
			ExitApp
	}
	firstRun := True ; Moved out of ini File.
}

; Read settings.
IniRead,allSections,settings.ini
IF (!allSections || allSections="ERROR") { ; Do not think this is ever set to ERROR.
	MsgBox, % 1+16, Error reading settings file, There was an error reading the settings.ini`nPress OK to reset settings to default.
	IfMsgBox Ok
		Gosub IniWriteDefault
	Else
		ExitApp
}
Loop,Parse,allSections,`n
{
	IniRead,pairs,settings.ini,%A_LoopField%
	Loop,Parse,pairs,`n
	{
		StringSplit,keyValue,A_LoopField,=
		%keyValue1%:=keyValue2
	}
}
readSettingsSkippedDueToError:	; This comes from setSettingsToDefault If there was an error.

pi:=atan(1)*4													; Approx pi.

; Constants and such. Some values are commented out because they have been stored in the settings.ini file instead, but are kept because they have comments.
moveStickHalf := False
KeyList := []
KeyListByNum := []
KeyListByNumBB := []	;Bloodborne key list
Global controller := []	;controller[1]=vXBox | controller[2]=vDS4
yminus:=0
yplus:=0
xminus:=0
xplus:=0

ihSimple := InputHook()	;for non-main keybinds
ihSimple.KeyOpt("{All}", "ES")

; Hotkey(s).
IF (controllerSwitchKey)
	Hotkey,%controllerSwitchKey%,controllerSwitch, on
IF (exitKey)
	Hotkey,%exitKey%,exitFunc, on

Mouse2Controller := True
IF (Mouse2Controller) {
	Gosub, initViGEmInterface
	Gosub, Mouse2ControllerHotkeys
}

; Icon
Menu,Tray,Tip, MKB2Controller
Menu,Tray,NoStandard


IF (!A_IsCompiled) { ; If it is compiled it should just use the EXE Icon
	IF (A_OSVersion < "10.0.15063") ; It appears that the Icon has changed number on the newest versions of Windows.
		useIcon := 26
	Else IF (A_OSVersion >= "10.0.16299")
		useIcon := 28
	Else
		useIcon := 27
	Try
		Menu,Tray,Icon,ddores.dll, %useIcon% 
}
;Menu,Settings,openSettings
Menu,Tray,Add,Settings,openSettings
Menu,Tray,Add,
Menu,Tray,Add,Reset to default, IniWriteDefault
Menu,Tray,Add
Menu,Tray,Add,About,aboutMenu
Menu,Tray,Add,Help,helpMenu
Menu,Tray,Add
Menu,Tray,Add,Reload,reloadMenu
Menu,Tray,Add,Exit,exitFunc
Menu,Tray,Default, Settings

IF interval is not Integer
	interval := 1

pmX:=invertedX ? -1:1							; Sign for inverting axis
pmY:=invertedY ? -1:1
invLX:=invertedLX ? -1:1
invLY:=invertedLY ? -1:1
snapToFullTilt:=0.005						; This needs to be improved.

; Spam user with useless info, first time script runs.
IF (firstRun)
	MsgBox,64,Welcome,Settings are accessed via Tray icon -> Settings.

Return
; End autoexec.

reloadMenu:
	Reload
Return

aboutMenu:
	Msgbox,32,About, Created by N3R4i`n`nBased on Heglef's & CemuUser8's mouse2joystick`n`nVersion:`n%version%
Return

helpMenu:
	Msgbox,% 4 + 32 ,, If you need help with MKB2Controller, seek me out on GitHub.`n`nOpen link in browser?`nhttps://github.com/N3R4i/MKB2Controller
	IfMsgBox Yes
		Run, https://github.com/N3R4i/MKB2Controller
Return

initViGEmInterface:
	Global vXBox := usevXBox
	If (vXBox) {
		Global ControllerIndex:=1	;switch to vXBox
		If (vXBox AND !vXBoxExists) {	;if vXBox doesn't exist yet, create one
			controller[1] := new ViGEmXb360()
			vXBoxExists:=1
		}
	}
	If (!vXBox) {
		Global ControllerIndex:=2	;switch to vDS4
		If (!vXBox AND !vDS4Exists) {	;if vDS4 doesn't exist yet, create one
			controller[2] := new ViGEmDS4()
			vDS4Exists:=1
		}
	}
Return

; Hotkey labels
; This switches on/off the controller.
controllerSwitch:
	IF (toggle) { ; Starting controller
		IF (autoActivateGame) {
			WinActivate,ahk_exe %gameExe%
			WinWaitActive, ahk_exe %gameExe%,,2
			IF (ErrorLevel) {	
				MsgBox,16,Error, %gameExe% not activated.
				Return
			}
			WinGetPos,gameX,gameY,gameW,gameH,ahk_exe %gameExe%	; Get game screen position and dimensions
			WinGet, gameID, ID, ahk_exe %gameExe%
		}
		Else {
			gameX:=0
			gameY:=0
			gameW:=A_ScreenWidth
			gameH:=A_ScreenHeight
		}
		
		; Controller origin is center of game screen or screen If autoActivateGame:=0.
		OX:=Round(gameX+gameW/2)	;Needs to be rounded, because if the game window size is odd, this would result in a fraction, but mouse can only move to a whole pixel position, and the 0.5 deviation would cause stick drift
		OY:=Round(gameY+gameH/2)
		IF (!OX OR !OY) {
			OX := 500
			OY := 500
		}

		; Move mouse to controller origin
		MouseMove,OX,OY
		
		IF (hideCursor)
			show_Mouse(False)
		If MouseStick!=2
			SetTimer,MouseToController,%interval%
		If movementSmoothing:=1	;always use this method for movement
			SetTimer,MovementTimer,1

	}
	Else {	; Shutting down controller
		setStick(0,0)														; Stick in equilibrium.
		SetTimer,MouseToController,Off
		SetTimer,MovementTimer,Off
		
		IF (hideCursor)
			show_Mouse()				; No need to show cursor if not hidden.
		Gui, Controller:Hide
	
	}
	toggle:=!toggle
Return

; Hotkeys Mouse2Controller
#IF (!toggle && Mouse2Controller)
#IF
Mouse2ControllerHotkeys:
	Hotkey, IF, (!toggle && Mouse2Controller)
		SetStick(0,0)
		
		Hotkey,LCtrl, maskLCtrl, on	;needed so input focus is not lost when modifier+singlekey combinations are used
		Hotkey,LAlt, maskLAlt, on
		Hotkey,LShift, maskLShift, on
		
		IF (walkModifierKey)
			HotKey,%walkModifierKey%,toggleHalf, On
		IF (decreaseWalkKey)
			HotKey,%decreaseWalkKey%,decreaseWalk, On
		IF (increaseWalkKey)
			HotKey,%increaseWalkKey%,increaseWalk, On
		
		Hotkey,%upKey%, overwriteUp, on 
		Hotkey,%upKey% Up, overwriteUpup, on
		Hotkey,%leftKey%, overwriteLeft, on 
		Hotkey,%leftKey% Up, overwriteLeftup, on
		Hotkey,%downKey%, overwriteDown, on 
		Hotkey,%downKey% Up, overwriteDownup, on
		Hotkey,%rightKey%, overwriteRight, on
		Hotkey,%rightKey% Up, overwriteRightup, on

	KeyListByNumBB := []	;Feed joystickButtonKeyListBB keys into KeyListByNumBB[#] and turn on hotkeys
	Loop, Parse, joystickButtonKeyListBB, `,
	{
		If !A_LoopField
			continue
		KeyListByNumBB[A_Index] := A_LoopField
		Hotkey, % (KeyListByNumBB[A_Index]), actionBB%A_Index%, on
		Hotkey, % (KeyListByNumBB[A_Index]) " Up", actionBB%A_Index%Up, on	;this is a better way to prevent the hotkey getting spammed
	}
	
	KeyListByNum := []	;joystickButtonKeyList keys have to be fed into KeyListByNum[#] here
	Loop, Parse, joystickButtonKeyList, `,
	{
	keyName := A_LoopField
	If !keyName
		continue
	KeyListByNum[A_Index] := keyName
	}
	Global overrideButton, currentButton
	overrideButton := []
	KeyList := []
	Loop, Parse, joystickButtonKeyList, `,
	{
		useButton := A_Index
		Loop, Parse, A_LoopField, |
		{	
			keyName=%A_LoopField%	;added * is not necessary
			
			IF (!keyName)
				Continue
			; keyName:=detectModifiers(keyName)
			detectModifiers(keyName, useButton)
			If currentButton
				KeyList[keyName] := useButton
			Hotkey,%keyName%, pressJoyButton, on
			Hotkey,%keyName% Up, releaseJoyButton, on
		}
	}
	Hotkey, IF
Return

detectModifiers(ByRef keyName, ByRef useButton) {
	If InStr(keyName, "LCtrl+") and InStr(keyName, "LAlt+") and InStr(keyName, "LShift+") {
		keyName:=RegexReplace(keyName,"LCtrl\+LAlt\+LShift\+")
		overrideButton[keyName . 7]:=useButton
		currentButton:=0
	} Else If InStr(keyName, "LAlt+") and InStr(keyName, "LShift+") {
		keyName:=RegexReplace(keyName,"LAlt\+LShift\+")
		overrideButton[keyName . 6]:=useButton
		currentButton:=0
	} Else If InStr(keyName, "LCtrl+") and InStr(keyName, "LShift+") {
		keyName:=RegexReplace(keyName,"LCtrl\+LShift\+")
		overrideButton[keyName . 5]:=useButton
		currentButton:=0
	} Else If InStr(keyName, "LCtrl+") and InStr(keyName, "LAlt+") {
		keyName:=RegexReplace(keyName,"LCtrl\+LAlt\+")
		overrideButton[keyName . 4]:=useButton
		currentButton:=0
	} Else If InStr(keyName, "LShift+") {
		keyName:=RegexReplace(keyName,"LShift\+")
		overrideButton[keyName . 3]:=useButton
		currentButton:=0
	} Else If InStr(keyName, "LAlt+") {
		keyName:=RegexReplace(keyName,"LAlt\+")
		overrideButton[keyName . 2]:=useButton
		currentButton:=0
	} Else If InStr(keyName, "LCtrl+") {
		keyName:=RegexReplace(keyName,"LCtrl\+")
		overrideButton[keyName . 1]:=useButton
		currentButton:=0
	} Else {
		overrideButton[keyName . 0]:=useButton
		currentButton:=1
	}
}

; movementDisable(Index) {
	; Switch Index {
		; Case 1:
			; If GetKeyState("LCtrl","P")
				; Return 1
		; Case 2:
			; If GetKeyState("LAlt","P")
				; Return 1
		; Case 3:
			; If GetKeyState("LShift","P")
				; Return 1
		; Case 4:
			; If GetKeyState("LCtrl","P") and GetKeyState("LAlt","P")
				; Return 1
		; Case 5:
			; If GetKeyState("LCtrl","P") and GetKeyState("LShift","P")
				; Return 1
		; Case 6:
			; If GetKeyState("LAlt","P") and GetKeyState("LShift","P")
				; Return 1
		; Case 7:
			; If GetKeyState("LCtrl","P") and GetKeyState("LAlt","P") and GetKeyState("LShift","P")
				; Return 1
		; }
	; Return 0
; }

maskLCtrl:
Return
maskLAlt:
Return
maskLShift:
Return

Moving() {	;check movement key state
	Global
	If GetKeyState(upKey, "P") OR GetKeyState(downKey, "P") OR GetKeyState(leftKey, "P") OR GetKeyState(rightKey, "P")	{
		return 1
	} Else {
		return 0
	}
}

actionBB1:	;Dodge+Backstep
If !alreadyactionBB1 {
	If !InStr(KeyListByNumBB[1], "wheel")
		alreadyactionBB1:=1
	If (vSprinting=1)	{	;if ○ is held release it
		controller[ControllerIndex].Buttons.B.SetState(false)
		sleep 30
	}
	controller[ControllerIndex].Buttons.B.SetState(true)
	sleep 30
	controller[ControllerIndex].Buttons.B.SetState(false)
	sleep 30
	If (vSprinting=1)	{	;keep sprinting
		controller[ControllerIndex].Buttons.B.SetState(true)
	}
}
return
actionBB1Up:
	alreadyactionBB1:=0
Return

actionBB2:	;Dodge
If !alreadyactionBB2 {
	If !InStr(KeyListByNumBB[2], "wheel")
		alreadyactionBB2:=1
	If (vSprinting=1) {	;if ○ is held release it
		controller[ControllerIndex].Buttons.B.SetState(false)
		sleep 30
	}
	IF Moving() {
		controller[ControllerIndex].Buttons.B.SetState(true)
		sleep 30
		controller[ControllerIndex].Buttons.B.SetState(false)
		sleep 30
	} Else {	;if not moving, force roll forward
		setStickLeft("N/A",1)
		sleep 30
		controller[ControllerIndex].Buttons.B.SetState(true)
		sleep 30
		controller[ControllerIndex].Buttons.B.SetState(false)
		sleep 30
		setStickLeft("N/A",0)
	}
	If (vSprinting=1) {	;keep sprinting
		controller[ControllerIndex].Buttons.B.SetState(true)
	}
}
return
actionBB2Up:
	alreadyactionBB2:=0
Return

actionBB3:	;Backstep
If !alreadyactionBB3 {
	If !InStr(KeyListByNumBB[3], "wheel")
		alreadyactionBB3:=1
	If movementSmoothing
		Critical On
	If (vSprinting=1) {	;if ○ is held release it
		controller[ControllerIndex].Buttons.B.SetState(false)
		sleep 30
	}
	IF Moving() {
		setStickLeft(0,0)	;stop moving
			sleep 30
		controller[ControllerIndex].Buttons.B.SetState(true)
			sleep 30
		controller[ControllerIndex].Buttons.B.SetState(false)
			sleep 30
		KeepStickHowItWas()	;keep moving after backstep
	} Else {
		controller[ControllerIndex].Buttons.B.SetState(true)
		sleep 30
		controller[ControllerIndex].Buttons.B.SetState(false)
		sleep 30
	}
	If (vSprinting=1) {	;keep sprinting
		controller[ControllerIndex].Buttons.B.SetState(true)
	}
	If movementSmoothing
		Critical Off
}
return
actionBB3Up:
	alreadyactionBB3:=0
Return

actionBB4:	;Sprint
	While GetKeyState(KeyListByNumBB[4], "P") {
		IF Moving() {
			controller[ControllerIndex].Buttons.B.SetState(true)	;start sprinting
			vSprinting:=1	;to know O button state
			sleep 500	;don't release it too early to prevent rolling
			If !InStr(KeyListByNumBB[4], "wheel")
				Keywait % (KeyListByNumBB[4])
			controller[ControllerIndex].Buttons.B.SetState(false)
			vSprinting:=0
			Return
		}
		sleep 100	;prevents hotkey spam
	}
return
actionBB4Up:
Return

actionBB5:	;Jump
If !alreadyactionBB5 {
	If !InStr(KeyListByNumBB[5], "wheel")
		alreadyactionBB5:=1
	controller[ControllerIndex].Buttons.LS.SetState(true)
	sleep 30
	controller[ControllerIndex].Buttons.LS.SetState(false)
}
return
actionBB5Up:
	alreadyactionBB5:=0
Return

actionBB6:	;Jump attack
If !alreadyactionBB6 {
	If !InStr(KeyListByNumBB[6], "wheel")
		alreadyactionBB6:=1
	If movementSmoothing
		Critical On
	IF Moving() {
		setStickLeft(0,0)
		sleep 30
		KeepStickHowItWas()
	} Else {
		setStickLeft("N/A",1)
	}
	sleep 30
	controller[ControllerIndex].Axes.RT.SetState(100)
	sleep 30
	controller[ControllerIndex].Axes.RT.SetState(0)
	sleep 30
	setStickLeft("N/A",0)
	KeepStickHowItWas()
	If movementSmoothing
		Critical Off
}
return
actionBB6Up:
	alreadyactionBB6:=0
Return

actionBB7:	;Save&Quit
short:=30
long:=100
	controller[ControllerIndex].Buttons.Start.SetState(true)	;start
	sleep %short%
	controller[ControllerIndex].Buttons.Start.SetState(false)
	sleep %long%
	controller[ControllerIndex].Dpad.SetState("Left")	;D-Left
	sleep %short%
	controller[ControllerIndex].Dpad.SetState("None")
	sleep %long%
	controller[ControllerIndex].Buttons.A.SetState(True)	;X
	sleep %short%
	controller[ControllerIndex].Buttons.A.SetState(False)
	sleep %long%
	controller[ControllerIndex].Dpad.SetState("Up")	;D-Up
	sleep %short%
	controller[ControllerIndex].Dpad.SetState("None")
	sleep %long%
	controller[ControllerIndex].Buttons.A.SetState(True)	;X
	sleep %short%
	controller[ControllerIndex].Buttons.A.SetState(False)
	sleep %long%
	controller[ControllerIndex].Dpad.SetState("Left")	;D-Left
	sleep %short%
	controller[ControllerIndex].Dpad.SetState("None")
	sleep 400
	controller[ControllerIndex].Buttons.A.SetState(True)	;X
	sleep %short%
	controller[ControllerIndex].Buttons.A.SetState(False)
return
actionBB7Up:
Return

; Labels for pressing and releasing joystick buttons.
pressJoyButton:
	keyName:=A_ThisHotkey
	joyButtonNumber := KeyList[keyName] ; joyButtonNumber:=A_Index
	
	If GetKeyState("LCtrl","P") and GetKeyState("LAlt","P") and GetKeyState("LShift","P") {
		If overrideButton[keyName . 7]
			joyButtonNumber:=overrideButton[keyName . 7]
	} Else If GetKeyState("LAlt","P") and GetKeyState("LShift","P") {
		If overrideButton[keyName . 6]
			joyButtonNumber:=overrideButton[keyName . 6]
	} Else If GetKeyState("LCtrl","P") and GetKeyState("LShift","P") {
		If overrideButton[keyName . 5]
			joyButtonNumber:=overrideButton[keyName . 5]
	} Else If GetKeyState("LCtrl","P") and GetKeyState("LAlt","P") {
		If overrideButton[keyName . 4]
			joyButtonNumber:=overrideButton[keyName . 4]
	} Else If GetKeyState("LShift","P") {
		If overrideButton[keyName . 3]
			joyButtonNumber:=overrideButton[keyName . 3]
	} Else If GetKeyState("LAlt","P") {
		If overrideButton[keyName . 2]
			joyButtonNumber:=overrideButton[keyName . 2]
	} Else If GetKeyState("LCtrl","P") {
		If overrideButton[keyName . 1]
			joyButtonNumber:=overrideButton[keyName . 1]
	}	
	
	If InStr(keyName, "wheel")
		new SelfDeletingTimer(100, "Gavlan", joyButtonNumber)
	Switch joyButtonNumber
		{
		Case 1:
			controller[ControllerIndex].Buttons.A.SetState(true)
		Case 2:
			controller[ControllerIndex].Buttons.B.SetState(true)
			vSprinting:=1	;to know O button state
		Case 3:
			controller[ControllerIndex].Buttons.X.SetState(true)
		Case 4:
			controller[ControllerIndex].Buttons.Y.SetState(true)
		Case 5:
			controller[ControllerIndex].Buttons.LB.SetState(true)
		Case 6:
			controller[ControllerIndex].Buttons.RB.SetState(true)
		Case 7:
			controller[ControllerIndex].Axes.LT.SetState(100)
		Case 8:
			controller[ControllerIndex].Axes.RT.SetState(100)
		Case 9:
			controller[ControllerIndex].Buttons.Back.SetState(true)
		Case 10:
			controller[ControllerIndex].Buttons.Start.SetState(true)
		Case 11:
			controller[ControllerIndex].Buttons.LS.SetState(true)
		Case 12:
			controller[ControllerIndex].Buttons.RS.SetState(true)
		Case 13:
			controller[ControllerIndex].Dpad.SetState("Up")
		Case 14:
			controller[ControllerIndex].Dpad.SetState("Down")
		Case 15:
			controller[ControllerIndex].Dpad.SetState("Left")
		Case 16:
			controller[ControllerIndex].Dpad.SetState("Right")
		}
Return

releaseJoyButton:
	keyName:=RegExReplace(A_ThisHotkey," Up$")
	joyButtonNumber := KeyList[keyName] ; joyButtonNumber:=A_Index
	
Loop 8 {	;this ensures that buttons don't get stuck
	If !overrideButton[keyName . A_Index-1]
		Continue
	joyButtonNumber:=overrideButton[keyName . A_Index-1]
	Switch joyButtonNumber
		{
		Case 1:
			controller[ControllerIndex].Buttons.A.SetState(false)
		Case 2:
			controller[ControllerIndex].Buttons.B.SetState(false)
			vSprinting:=0	;to know O button state
		Case 3:
			controller[ControllerIndex].Buttons.X.SetState(false)
		Case 4:
			controller[ControllerIndex].Buttons.Y.SetState(false)
		Case 5:
			controller[ControllerIndex].Buttons.LB.SetState(false)
		Case 6:
			controller[ControllerIndex].Buttons.RB.SetState(false)
		Case 7:
			controller[ControllerIndex].Axes.LT.SetState(0)
		Case 8:
			controller[ControllerIndex].Axes.RT.SetState(0)
		Case 9:
			controller[ControllerIndex].Buttons.Back.SetState(false)
		Case 10:
			controller[ControllerIndex].Buttons.Start.SetState(false)
		Case 11:
			controller[ControllerIndex].Buttons.LS.SetState(false)
		Case 12:
			controller[ControllerIndex].Buttons.RS.SetState(false)
		Case 13:
			controller[ControllerIndex].Dpad.SetState("None")
		Case 14:
			controller[ControllerIndex].Dpad.SetState("None")
		Case 15:
			controller[ControllerIndex].Dpad.SetState("None")
		Case 16:
			controller[ControllerIndex].Dpad.SetState("None")
		}
}
Return

Gavlan(keyNum) {	;Gavlan Wheel? Gavlan Deal
	Switch keyNum
		{
		Case 1:
			controller[ControllerIndex].Buttons.A.SetState(false)
		Case 2:
			controller[ControllerIndex].Buttons.B.SetState(false)
			vSprinting:=0	;to know O button state
		Case 3:
			controller[ControllerIndex].Buttons.X.SetState(false)
		Case 4:
			controller[ControllerIndex].Buttons.Y.SetState(false)
		Case 5:
			controller[ControllerIndex].Buttons.LB.SetState(false)
		Case 6:
			controller[ControllerIndex].Buttons.RB.SetState(false)
		Case 7:
			controller[ControllerIndex].Axes.LT.SetState(0)
		Case 8:
			controller[ControllerIndex].Axes.RT.SetState(0)
		Case 9:
			controller[ControllerIndex].Buttons.Back.SetState(false)
		Case 10:
			controller[ControllerIndex].Buttons.Start.SetState(false)
		Case 11:
			controller[ControllerIndex].Buttons.LS.SetState(false)
		Case 12:
			controller[ControllerIndex].Buttons.RS.SetState(false)
		Case 13:
			controller[ControllerIndex].Dpad.SetState("None")
		Case 14:
			controller[ControllerIndex].Dpad.SetState("None")
		Case 15:
			controller[ControllerIndex].Dpad.SetState("None")
		Case 16:
			controller[ControllerIndex].Dpad.SetState("None")
		}
	Return
}

toggleHalf:	;allow toggle or hold
	Global walkToggleMode
	If walkToggleMode {
		moveStickHalf := !moveStickHalf
		KeepStickHowItWas()
	} Else {
		moveStickHalf := 1
		KeepStickHowItWas()
		Keywait % walkModifierKey
		moveStickHalf := 0
		KeepStickHowItWas()
	}
Return

decreaseWalk:
	walkSpeed -= 0.05
	IF (walkSpeed < 0)
		walkSpeed := 0
	KeepStickHowItWas()
	IniWrite, % walkSpeed:= Round(walkSpeed, 2), settings.ini, Keyboard-Movement, walkSpeed
	GUI, Main:Default
	GUIControl,,opwalkSpeedTxt, % Round(walkSpeed * 100) "%"
Return

increaseWalk:
	walkSpeed += 0.05
	IF (walkSpeed > 1)
		walkSpeed := 1
	KeepStickHowItWas()
	IniWrite, % walkSpeed := Round(walkSpeed, 2), settings.ini, Keyboard-Movement, walkSpeed
	GUI, Main:Default
	GUIControl,,opwalkSpeedTxt, % Round(walkSpeed * 100) "%"
Return

KeepStickHowItWas() {
	Global moveStickHalf, walkSpeed, upKey, leftKey, downKey, rightKey
	IF (GetKeyState(downKey, "P"))
		setStickLeft("N/A",-1)
	IF (GetKeyState(rightKey, "P"))
		setStickLeft(1,"N/A")
	IF (GetKeyState(leftKey, "P"))
		setStickLeft(-1,"N/A")
	IF (GetKeyState(upKey, "P"))
		setStickLeft("N/A",1)
}

MovementTimer:
; Loop 7 {
	; If overrideButton[leftKey . A_Index] and movementDisable(A_Index)
		; Return
	; If overrideButton[rightKey . A_Index] and movementDisable(A_Index)
		; Return
	; If overrideButton[downKey . A_Index] and movementDisable(A_Index)
		; Return
	; If overrideButton[upKey . A_Index] and movementDisable(A_Index)
		; Return
; }
	If (GetKeyState(leftKey,"P")) {
		xminus+=movementIncrement
		If (xminus>1)
			xminus:=1
	} Else {
		xminus-=movementIncrement
		If (xminus<0)
			xminus:=0
	}
	If (GetKeyState(rightKey,"P")) {
		xplus+=movementIncrement
		If (xplus>1)
			xplus:=1
	} Else {
		xplus-=movementIncrement
		If (xplus<0)
			xplus:=0
	}
	If (GetKeyState(downKey,"P")) {
		yminus+=movementIncrement
		If (yminus>1)
			yminus:=1
	} Else {
		yminus-=movementIncrement
		If (yminus<0)
			yminus:=0
	}
	If (GetKeyState(upKey,"P")) {
		yplus+=movementIncrement
		If (yplus>1)
			yplus:=1
	} Else {
		yplus-=movementIncrement
		If (yplus<0)
			yplus:=0
	}
	If GetKeyState(leftKey,"P") or GetKeyState(rightKey,"P") or GetKeyState(downKey,"P") or GetKeyState(upKey,"P") {
		AlreadyAtZero:=0
		setStickLeft(-1*xminus+xplus,-1*yminus+yplus)
	} Else If !AlreadyAtZero {
		setStickLeft(0,0)
		AlreadyAtZero:=1
	}
Return

overwriteUp:
If !movementSmoothing {
	directionY:=1
	If !alreadyUp {
		setStickLeft(directionX,directionY)
		alreadyUp:=1
	}
}
Return
overwriteUpup:
If !movementSmoothing {
	IF (GetKeyState(downKey, "P")) {
		directionY:=-1
	} Else {
		directionY:=0
	}
	setStickLeft(directionX,directionY)
	alreadyUp:=0
}
Return

overwriteLeft:
If !movementSmoothing {
	directionX:=-1
	If !alreadyLeft {
		setStickLeft(directionX,directionY)
		alreadyLeft:=1
	}
}
Return
overwriteLeftup:
If !movementSmoothing {
	IF (GetKeyState(rightKey, "P")) {
		directionX:=1
	} Else {
		directionX:=0
	}
	setStickLeft(directionX,directionY)
	alreadyLeft:=0
}
Return

overwriteRight:
If !movementSmoothing {
	directionX:=1
	If !alreadyRight {
		setStickLeft(directionX,directionY)
		alreadyRight:=1
	}
}
Return
overwriteRightup:
If !movementSmoothing {
	IF (GetKeyState(leftKey, "P")) {
		directionX:=-1
	} Else {
		directionX:=0
	}
	setStickLeft(directionX,directionY)
	alreadyRight:=0
}
Return

overwriteDown:
If !movementSmoothing {
	directionY:=-1
	If !alreadyDown {
		setStickLeft(directionX,directionY)
		alreadyDown:=1
	}
}
Return
overwriteDownup:
If !movementSmoothing {
	IF (GetKeyState(upKey, "P")) {
		directionY:=1
	} Else {
		directionY:=0
	}
	setStickLeft(directionX,directionY)
	alreadyDown:=0
}
Return

; Labels

MouseToController:
	Critical, On
	Mouse2Controller(r,OX,OY)
	Critical, Off
Return

; Functions

Mouse2Controller(r,OX,OY) {
	; r is the radius of the outer circle.
	; OX is the x coord of circle center.
	; OY is the y coord of circle center.
	MouseGetPos,X,Y
	X-=OX										;Move to controller coord system.
	Y-=OY
	RR:=sqrt(X**2+Y**2)
	IF (RR>r) {								;Check If outside controller circle.
		X:=round(X*r/RR)
		Y:=round(Y*r/RR)
		RR:=sqrt(X**2+Y**2)
		DllCall("SetCursorPos", "int", X+OX, "int", Y+OY)	;Calculate point on controller circle, move back to screen/window coords, and move mouse. N3R4i: Changed from MouseMove to DllCall. This fixes real mouse button input being sent instead of the assigned hotkey, and also fixes the mouse not working after turning off the script
	}
	
	; Calculate angle
	phi:=getAngle(X,Y)
	DllCall("SetCursorPos", "int", OX, "int", OY)	;adding one more MouseMove here makes the cursor jump back to the center more consistently, which reduces the occasional camera stutter
	
	IF (RR>0) {	;Check if mouse moved
		action(phi,RR/r)
	}
	Else If Moving() AND (MouseStick=MovementStick) {
	} Else {
		setStick(0,0)	;Stick back to neutral
	}
	DllCall("SetCursorPos", "int", OX, "int", OY)
}

action(phi,tilt) {	
	; This is for Mouse2Controller.
	; phi ∈ [0,2*pi] defines in which direction the stick is tilted.
	; tilt ∈ (0,1] defines the amount of tilt. 0 is no tilt, 1 is full tilt.
	; When this is called it is already established that the deadzone is left, or the inner radius.
	; pmX/pmY is used for inverting axis.
	; snapToFullTilt is used to ensure full tilt is possible, this needs to be improved, should be dependent on the sensitivity.
	Global pmX,pmY,pi,snapToFullTilt

	; Adjust tilt
	tilt:=tilt>1 ? 1:tilt
	IF (snapToFullTilt!=-1)
		tilt:=1-tilt<=snapToFullTilt ? 1:tilt
	
	; Two cases with forward+right
	; Tilt is forward and slightly right.
	lb:=3*pi/2										; lb is lower bound
	ub:=7*pi/4										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt*scale(phi,ub,lb)
		y:=pmY*tilt
		setStick(x,y)
		Return
	}
	; Tilt is slightly forward and right.
	lb:=7*pi/4										; lb is lower bound
	ub:=2*pi						; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt
		y:=pmY*tilt*scale(phi,lb,ub)
		setStick(x,y)
		Return
	}
	
	; Two cases with right+downward
	; Tilt is right and slightly downward.
	lb:=0											; lb is lower bound
	ub:=pi/4										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt
		y:=-pmY*tilt*scale(phi,ub,lb)
		setStick(x,y)
		Return
	}
	; Tilt is downward and slightly right.
	lb:=pi/4										; lb is lower bound
	ub:=pi/2										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt*scale(phi,lb,ub)
		y:=-pmY*tilt
		setStick(x,y)
		Return
	}
	
	; Two cases with downward+left
	; Tilt is downward and slightly left.
	lb:=pi/2										; lb is lower bound
	ub:=3*pi/4										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt*scale(phi,ub,lb)
		y:=-pmY*tilt
		setStick(x,y)
		Return
	}
	; Tilt is left and slightly downward.
	lb:=3*pi/4										; lb is lower bound
	ub:=pi											; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt
		y:=-pmY*tilt*scale(phi,lb,ub)
		setStick(x,y)
		Return
	}
	
	; Two cases with forward+left
	; Tilt is left and slightly forward.
	lb:=pi											; lb is lower bound
	ub:=5*pi/4										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt
		y:=pmY*tilt*scale(phi,ub,lb)
		setStick(x,y)
		Return
	}
	; Tilt is forward and slightly left.
	lb:=5*pi/4										; lb is lower bound
	ub:=3*pi/2										; ub is upper bound
	IF (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt*scale(phi,lb,ub)
		y:=pmY*tilt
		setStick(x,y)
		Return
	}
	; This should not happen:
	setStick(0,0)
	MsgBox,16,Error, Error at phi=%phi%. Please report.
	Return
}

scale(phi,lb,ub) {
	; let phi->f(phi) then, f(ub)=0 and f(lb)=1
	Return (phi-ub)/(lb-ub)
}

isNumber(var) { ;function for checking if var is a number, can be used with arguments
	If var is number
		return true
	else
		return false
}

sign(var) {	;function for reading var's sign
	return (var>0)-(var<0)
}

setStick(x,y) {
	; Set joystick x-axis to 100*x % and y-axis to 100*y %
	; Input is x,y ∈ (-1,1) where 1 would mean full tilt in one direction, and -1 in the other, while zero would mean no tilt at all. Using this interval makes it easy to invert the axis
	; (mainly this was choosen beacause the author didn't know the correct interval to use in CvJoyInterface)
	; the input is not really compatible with the CvJoyInterface. Hence this transformation:
	Global minmove	;stick offset value
	Global acceleration	;mouse acceleration amount (0,1)
	magnitude:=Sqrt(x**2+y**2)	;calculate magnitude
	IF (magnitude<>0) {			;prevent division by 0
		o:=Abs(x)/magnitude		;calculate circle correction
		p:=Abs(y)/magnitude
	}
	multx:=(Abs(x)+1)**acceleration	;mouse acceleration
	multy:=(Abs(y)+1)**acceleration
	x:=(sign(x)*minmove)+x*multx	;apply deadzone compensation with linear offset and mouse acceleration
	y:=(sign(y)*minmove)+y*multy
	
	x:=x+0.004	;for some reason in Bloodborne there's more deadzone to the left/up
	y:=y-0.004	
		
	IF Abs(x)>1 {	;cap x between -1,1
		x:=sign(x)
	}
	IF Abs(y)>1 {	;cap y between -1,1
		y:=sign(y)
	}
	IF (magnitude>0) { ;apply circle correction if magnitude has a value
		x:=x*o	
		y:=y*p
		}
	
	x:=(x+1)*50									; This maps x,y (-1,1) -> (0,100)
	y:=(y+1)*50
	If (MouseStick) {
		IF x is number
			controller[ControllerIndex].Axes.RX.SetState(x)
		IF y is number
			controller[ControllerIndex].Axes.RY.SetState(y)
	} Else {
		IF x is number
			controller[ControllerIndex].Axes.LX.SetState(x)
		IF y is number
			controller[ControllerIndex].Axes.LY.SetState(y)
	}
}

setStickLeft(x,y) {	;easier to use a separate function for left stick, as a lot of the right stick improvements could easily break it
	; Set joystick x-axis to 100*x % and y-axis to 100*y %
	; Input is x,y ∈ (-1,1) where 1 would mean full tilt in one direction, and -1 in the other, while zero would mean no tilt at all. Using this interval makes it easy to invert the axis
	; (mainly this was choosen beacause the author didn't know the correct interval to use in CvJoyInterface)
	; the input is not really compatible with the CvJoyInterface. Hence this transformation:	
	Global invLX, invLY, movementSmoothing, upKey, downKey, leftKey, rightKey, moveStickHalf, walkSpeed
	
	IF (moveStickHalf) {
		x:=x*walkSpeed
		y:=y*walkSpeed
	}
	
	If movementSmoothing {
		magnitude:=Sqrt(x**2+y**2)	;calculate magnitude
		IF (magnitude<>0) {			;prevent division by 0
			o:=Abs(x)/magnitude		;calculate circle correction
			p:=Abs(y)/magnitude
		}
		IF (magnitude>0) { ;apply circle correction if magnitude has a value
			x:=x*o	
			y:=y*p
		}
	}
	
	x:=x*invLX
	y:=y*invLY
	
	x:=(x+1)*50									; This maps x,y (-1,1) -> (0,100)
	y:=(y+1)*50
	
	If (MovementStick) {
		IF x is number
			controller[ControllerIndex].Axes.RX.SetState(x)
		IF y is number
			controller[ControllerIndex].Axes.RY.SetState(y)
	} Else {
		IF x is number
			controller[ControllerIndex].Axes.LX.SetState(x)
		IF y is number
			controller[ControllerIndex].Axes.LY.SetState(y)
	}
}

; Shared functions
getAngle(x,y) {
	Global pi
	IF (x=0)
		Return 3*pi/2-(y>0)*pi
	phi:=atan(y/x)
	IF (x<0 && y>0)
		Return phi+pi
	IF (x<0 && y<=0)
		Return phi+pi
	IF (x>0 && y<0)
		Return phi+2*pi
	Return phi
}

exitFunc() {
	Global
	IF (Mouse2Controller)	{
		setStick(0,0)
	}
	
	show_Mouse() ; DllCall("User32.dll\ShowCursor", "Int", 1)
	;DllCall("SystemParametersInfo", UInt, 0x71, UInt, 0, UInt, OrigMouseSpeed, UInt, 0)  ; Restore the original speed.
	ExitApp
}

;
; End Script.
; Start settings.
;
openSettings:
If !toggle			; This is probably best.
	Return

tree := "
(
General
Mouse
Keyboard-Movement
Keybinds
Bloodborne
)"
GUI, Main:New, -MinimizeBox, % "MKB2Controller Settings  -  " . version
GUI, Add, Text,, Options:
GUI, Add, TreeView, xm w140 h325 r16 gTreeClick Section
GUI, Add, Button,xs w68 gMainOk, Ok
GUI, Add, Button,x+4 w68 gMainSave Default, Apply
GUI, Add, Tab2, +Buttons -Theme -Wrap vTabControl ys w320 h0 Section, General|Mouse|Keyboard-Movement|Keybinds|Bloodborne
GUIControlGet, S, Pos, TabControl ; Store the coords of this section for future use.
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, General
	GUI, Add, GroupBox, x%SX% y%SY% w320 h65 Section, Output Mode
	GUI, Add, Radio, %  "xp+10 yp+20 Group vopusevXBox Checked" . usevXBox, XInput (virtual XBox 360 controller)
	GUI, Add, Radio, %  "xp yp+20 Checked" . !usevXBox, DirectInput (virtual DualShock 4 controller)

	GUI, Add, GroupBox, x%SX% yp+35 w320 h50,Executable Name (e.g. game.exe)
	GUI, Add, Edit, xp+10 yp+20 vopgameExe w170, %gameExe% 
	;GUI, Add, Text, x+m yp+3, (e.g. game.exe)
	
	GUI, Add, GroupBox, x%SX% yp+37 w320 h45,Auto Switch
	GUI, Add, Radio, % "xp+10 yp+20 Group vopautoActivateGame Checked" autoActivateGame, Yes
	GUI, Add, Radio, % "x+m Checked" !autoActivateGame, No
	GUI, Add, Text, x+m, Switch to game when toggling controller?
	
	GUI, Add, GroupBox, x%SX% yp+37 w320 h50 Section, Toggle Controller On/Off
	GUI, Add, Hotkey, xs+10 yp+20 w50 Limit190 vopcontrollerSwitchKey, % StrReplace(controllerSwitchKey, "#")
	GUI, Add, CheckBox, % "x+m yp+3 vopcontrollerSwitchKeyWin Checked" InStr(controllerSwitchKey, "#"), Use Windows key?
	
	GUI, Add, GroupBox, x%SX% yp+37 w320 h50 Section, Quit Application
	GUI, Add, Hotkey, xs+10 yp+20 w50 Limit190 vopexitKey, % StrReplace(exitKey, "#")
	GUI, Add, CheckBox, % "x+m yp+3 vopexitKeyWin Checked" InStr(exitKey, "#"), Use Windows key?
	
	GUI, Add, GroupBox, x%SX% yp+37 w320 h45,Hide Cursor
	GUI, Add, CheckBox, % "xp+10 yp+20 vophideCursor Checked" . hideCursor, Hide cursor when controller toggled on?
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Mouse
	GUI, Add, GroupBox, x%SX% y%SY% w320 h50 Section, Resistance
	GUI, Add, Edit, xs+10 yp+20 w50 vopr gNumberCheck, %r%
	GUI, Add, Text, x+4 yp+3, Lower values correspond to higher sensitivity 
	
	GUI, Add, GroupBox, xs yp+30 w320 h50, Mouse Check Interval (ms)
	GUI, Add, Edit, xs+10 yp+20 w50 vopinterval Number, %interval%
	GUI, Add, Text, x+4 yp+3, Recommended: 1
	
	GUI, Add, GroupBox, xs yp+30 w320 h50, Deadzone Compensation (stick offset)
	GUI, Add, Edit, xs+10 yp+20 w50 vopminmove gNumberCheck, %minmove%
	GUI, Add, Text, x+4 yp+3, Range (0 - 1)

	GUI, Add, GroupBox, xs yp+30 w320 h50, Mouse Acceleration
	GUI, Add, Edit, xs+10 yp+20 w50 vopacceleration gNumberCheck, %acceleration%
	GUI, Add, Text, x+4 yp+3, (Set to 0 to turn off)
	
	GUI, Add, GroupBox, xs yp+30 w320 h40 Section,Invert X-Axis
	GUI, Add, Radio, % "xp+10 yp+20 Group vopinvertedX Checked" . invertedX, Yes
	GUI, Add, Radio, % "x+m Checked" . !invertedX, No
	
	GUI, Add, GroupBox, xs yp+30 w320 h40 Section,Invert Y-Axis
	GUI, Add, Radio, % "xp+10 yp+20 Group vopinvertedY Checked" . invertedY, Yes
	GUI, Add, Radio, % "x+m Checked" . !invertedY, No
	
	GUI, Add, GroupBox, xs yp+30 w320 h45 Section, Mouse to stick:
	GUI, Add, Radio, %  "xp+10 yp+20 Group vopMouseStick Checked" . !MouseStick, Left Stick
	GUI, Add, Radio, %  "x+m Checked" . MouseStick, Right Stick
	GUI, Add, Radio, %  "x+m Checked" . MouseStick-1, None
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Keyboard-Movement
	GUI, Add, GroupBox, x%SX% y%SY% w250 h120 Section, Keyboard Movement
	GUI, Add, Text, xs+10 yp+25 Right w35, Up:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopupKey, %upKey%
	GUI, Add, Text, xs+10 yp+25 Right w35, Left:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopleftKey, %leftKey%
	GUI, Add, Text, xs+10 yp+25 Right w35, Down:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopdownKey, %downKey%
	GUI, Add, Text, xs+10 yp+25 Right w35, Right:
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 voprightKey, %rightKey%
	
	; Gui, Add, CheckBox, % "xs+110 ys+22 vopmovementSmoothing Checked" . movementSmoothing, Movement Smoothing
	; GUI, Add, Text, xp yp+20, Smoothing Increment `nRecommended 0.25-0.9
	GUI, Add, Text, xs+110 ys+22, Movement `nSmoothing Increment `nRecommended 0.25-0.9 `nSet to 1 to disable
	GUI, Add, Edit, xp yp+55 w50 vopmovementIncrement gNumberCheck, %movementIncrement%

	GUI, Add, GroupBox, xs w320 h80, Walk Modifier
	GUI, Add, Button, xs+10 yp+20 w70 Center -TabStop gsetWalkModKey vopwalkModifierKey, %walkModifierKey%	;better to have this as a button
	Gui, Add, CheckBox, % "x+5 yp+4 vopwalkToggleMode Checked" . walkToggleMode, Toggle mode
	GUI, Add, Text, xp+90 yp-1 Right w15, + :
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopincreaseWalkKey, %increaseWalkKey%
	GUI, Add, Text, x+0 yp+3 Right w15, - :
	GUI, Add, Hotkey, x+2 yp-3 w50 Limit190 vopdecreaseWalkKey, %decreaseWalkKey%
	GUI, Add, Text, xs+10 yp+30 Right w80, Walking Speed:
	GUI, Add, Slider, x+2 yp w180 Range0-100 TickInterval10 Thick12 vopwalkSpeed gWalkSpeedChange AltSubmit, % walkSpeed*100
	GUI, Font, Bold 
	GUI, Add, Text, x+1 yp+8 w40 vopwalkSpeedTxt, % Round(walkSpeed*100) "%"
	GUI, Font

	GUI, Add, GroupBox, xs yp+28 w320 h40 Section,Invert X-Axis
	GUI, Add, Radio, % "xp+10 yp+20 Group vopinvertedLX Checked" . invertedLX, Yes
	GUI, Add, Radio, % "x+m Checked" . !invertedLX, No
	
	GUI, Add, GroupBox, xs yp+30 w320 h40 Section,Invert Y-Axis
	GUI, Add, Radio, % "xp+10 yp+20 Group vopinvertedLY Checked" . invertedLY, Yes
	GUI, Add, Radio, % "x+m Checked" . !invertedLY, No

	GUI, Add, GroupBox, xs yp+30 w320 h45 Section, Movement to stick:
	GUI, Add, Radio, %  "xp+10 yp+20 Group vopMovementStick Checked" . !MovementStick, Left Stick
	GUI, Add, Radio, %  "x+m Checked" . MovementStick, Right Stick
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Keybinds
	GUI, Add, GroupBox, x%SX% y%SY% w340 h83 Section, Active KeyList
	GUI, Add, Edit, xs+10 yp+20 w320 vopjoystickButtonKeyList, %joystickButtonKeyList%
	GUI, Add, Button, xs+9 yp+34 w322 gKeyListHelper, KeyList Helper
	
	GUI, Add, GroupBox, x%SX% yp+40 w340 h50, Saved KeyList Manager
	IniRead,allSavedLists,SavedKeyLists.ini
	allSavedLists := StrReplace(allSavedLists, "`n", "|")
	GUI, Add, ComboBox, xs+10 yp+20 w110 vopSaveListName, %allSavedLists%
	GUI, Add, Button, x+m w60 gLoadSavedList, Load
	GUI, Add, Button, x+m w60 gSaveSavedList, Save
	GUI, Add, Button, x+m w60 gDeleteSavedList, Delete
;------------------------------------------------------------------------------------------------------------------------------------------
GUI, Tab, Bloodborne
	GUI, Add, GroupBox, x%SX% y%SY% w340 h80 Section, Active KeyList
	GUI, Add, Edit, xs+10 yp+20 w320 vopjoystickButtonKeyListBB, %joystickButtonKeyListBB%
	GUI, Add, Button, xs+10 yp+30 w320 gKeyListHelperBB, BloodBorne Bonus Buttons [B⁴]
;------------------------------------------------------------------------------------------------------------------------------------------

GUI, Add, StatusBar
BuildTree("Main", tree)
Gui, Main: Show
Return	

TreeClick:
	IF (A_GUIEvent = "S") {
		useSection := selectionPath(A_EventInfo)
		SB_SetText(useSection)
		GUIControl, Choose, TabControl, %useSection%
	}
Return

WalkSpeedChange:
	GUIControlGet,tmpSpeed,,opwalkSpeed
	GUIControl,,opwalkSpeedTxt, %tmpSpeed%`%
Return

MainGUIClose:
	GUI, Main:Destroy
Return

mainOk:
	Gui, Main:Hide
mainSave:
	Gui, Main:Submit, NoHide
	opmovementSmoothing:=1	;ensure that this is always 1
	If opwalkModifierKey	;this is needed because this key assignment uses a button
		walkModifierKey:=opwalkModifierKey
	Else
		opwalkModifierKey:=walkModifierKey
	Gosub, SubmitAll
	; Get old hotkeys.
	; Disable old hotkeys
	IF (controllerSwitchKey)
		Hotkey,%controllerSwitchKey%,controllerSwitch, off
	IF (exitKey)
		Hotkey,%exitKey%,exitFunc, off
		
	; Joystick buttons
	Hotkey, If, (!toggle && Mouse2Controller)
	IF (walkModifierKey)
		HotKey,%walkModifierKey%,toggleHalf, Off
	IF (decreaseWalkKey)
		HotKey,%decreaseWalkKey%,decreaseWalk, Off
	IF (increaseWalkKey)
		HotKey,%increaseWalkKey%,increaseWalk, Off

	Hotkey,LCtrl, maskLCtrl, off	;needed so input focus is not lost when modifier+singlekey combinations are used
	Hotkey,LAlt, maskLAlt, off
	Hotkey,LShift, maskLShift, off

	Hotkey,%upKey%, overwriteUp, off
	Hotkey,%upKey% Up, overwriteUpup, off
	Hotkey,%leftKey%, overwriteLeft, off
	Hotkey,%leftKey% Up, overwriteLeftup, off
	Hotkey,%downKey%, overwriteDown, off
	Hotkey,%downKey% Up, overwriteDownup, off
	Hotkey,%rightKey%, overwriteRight, off
	Hotkey,%rightKey% Up, overwriteRightup, off

	Loop, Parse, joystickButtonKeyListBB, `,
	{
		If !A_LoopField
			continue
		Hotkey, % (KeyListByNumBB[A_Index]), actionBB%A_Index%, off
		Hotkey, % (KeyListByNumBB[A_Index]) " Up", actionBB%A_Index%Up, off
	}

	Loop, Parse, joystickButtonKeyList, `,
	{
		useButton := A_Index
		Loop, Parse, A_LoopField, |
		{		
			keyName=%A_LoopField%	;added * is not necessary
			IF (!keyName)
				Continue
			detectModifiers(keyName, useButton)
			KeyList[keyName] := useButton
			Hotkey,%keyName%, pressJoyButton, off
			Hotkey,%keyName% Up, releaseJoyButton, off
		}
	}
	Hotkey, If

	; Read settings.
	
	IniRead,allSections,settings.ini
	
	Loop,Parse,allSections,`n
	{
		IniRead,pairs,settings.ini,%A_LoopField%
		Loop,Parse,pairs,`n
		{
			StringSplit,keyValue,A_LoopField,=
			%keyValue1%:=keyValue2
		}
	}

	IF (Mouse2Controller) {
		GoSub, initViGEmInterface
		GoSub, Mouse2ControllerHotkeys
	}
	pmX:=invertedX ? -1:1											; Sign for inverting axis
	pmY:=invertedY ? -1:1
	invLX:=invertedLX ? -1:1
	invLY:=invertedLY ? -1:1
	Global MouseStick
	Global MovementStick

	; Enable new hotkeys
	IF (controllerSwitchKey)
		Hotkey,%controllerSwitchKey%,controllerSwitch, on
	IF (exitKey)
		Hotkey,%exitKey%,exitFunc, on
Return

IniWriteDefault:
defaultusevXBox=1
defaultgameExe=
defaultautoActivateGame=0
defaultcontrollerSwitchKey=F1
defaultexitKey=#q
defaulthideCursor=1
defaultr=80
defaultinterval=1
defaultminmove=0.37
defaultacceleration=0
defaultinvertedX=0
defaultinvertedY=0
defaultMouseStick=1
defaultupKey=w
defaultleftKey=a
defaultdownKey=s
defaultrightKey=d
defaultmovementSmoothing=1
defaultmovementIncrement=0.9
defaultwalkModifierKey=LAlt
defaultwalkToggleMode=0
defaultincreaseWalkKey=NumpadAdd
defaultdecreaseWalkKey=NumpadSub
defaultwalkSpeed=0.50
defaultinvertedLX=0
defaultinvertedLY=0
defaultMovementStick=0
defaultjoystickButtonKeyList=e,Escape,r,f,XButton1,LButton,RButton,MButton,,Tab,,q,Home,End,Left,Right
defaultjoystickButtonKeyListBB=,,,,,,
	IniWrite, % defaultusevXBox, settings.ini, General, usevXBox
	IniWrite, % defaultgameExe, settings.ini, General, gameExe
	IniWrite, % defaultautoActivateGame, settings.ini, General, autoActivateGame
	IniWrite, % defaultcontrollerSwitchKey, settings.ini, General, controllerSwitchKey
	IniWrite, % defaultexitKey, settings.ini, General, exitKey
	IniWrite, % defaulthideCursor, settings.ini, General, hideCursor
	;Write Mouse
	IniWrite, % defaultr, settings.ini, Mouse, r
	IniWrite, % defaultinterval, settings.ini, Mouse, interval
	IniWrite, % defaultminmove, settings.ini, Mouse, minmove
	IniWrite, % defaultacceleration, settings.ini, Mouse, acceleration
	IniWrite, % defaultinvertedX, settings.ini, Mouse, invertedX
	IniWrite, % defaultinvertedY, settings.ini, Mouse, invertedY
	IniWrite, % defaultMouseStick, settings.ini, Mouse, MouseStick
	;Write Keyboard-Movement
	IniWrite, % defaultupKey, settings.ini, Keyboard-Movement, upKey
	IniWrite, % defaultleftKey, settings.ini, Keyboard-Movement, leftKey
	IniWrite, % defaultdownKey, settings.ini, Keyboard-Movement, downKey
	IniWrite, % defaultrightKey, settings.ini, Keyboard-Movement, rightKey
	IniWrite, % defaultmovementSmoothing, settings.ini, Keyboard-Movement, movementSmoothing
	IniWrite, % defaultmovementIncrement, settings.ini, Keyboard-Movement, movementIncrement
	IniWrite, % defaultwalkModifierKey, settings.ini, Keyboard-Movement, walkModifierKey
	IniWrite, % defaultwalkToggleMode, settings.ini, Keyboard-Movement, walkToggleMode	
	IniWrite, % defaultincreaseWalkKey, settings.ini, Keyboard-Movement, increaseWalkKey
	IniWrite, % defaultdecreaseWalkKey, settings.ini, Keyboard-Movement, decreaseWalkKey
	IniWrite, % defaultwalkSpeed, settings.ini, Keyboard-Movement, walkSpeed
	IniWrite, % defaultinvertedLX, settings.ini, Keyboard-Movement, invertedLX
	IniWrite, % defaultinvertedLY, settings.ini, Keyboard-Movement, invertedLY
	IniWrite, % defaultMovementStick, settings.ini, Keyboard-Movement, MovementStick
	;Write Keybinds
	IniWrite, % defaultjoystickButtonKeyList, settings.ini, Keybinds, joystickButtonKeyList
	;Bloodborne
	IniWrite, % defaultjoystickButtonKeyListBB, settings.ini, Bloodborne, joystickButtonKeyListBB
TrayTip, % "Settings reset to default", % "",,0x10
reload
Return



SubmitAll:
	;FileDelete, settings.ini ; Should I just delete the settings file before writing all settings to it? Guarantees a clean file, but doesn't allow for hidden options...
	; Write General
	IniWrite, % 2-opusevXBox, settings.ini, General, usevXBox
	IniWrite, % opgameExe, settings.ini, General, gameExe
	IniWrite, % 2-opautoActivateGame, settings.ini, General, autoActivateGame
	IniWrite, % opcontrollerSwitchKeyWin ? "#" . opcontrollerSwitchKey : opcontrollerSwitchKey, settings.ini, General, controllerSwitchKey
	IniWrite, % opexitKeyWin ? "#" . opexitKey : opexitKey, settings.ini, General, exitKey
	IniWrite, % ophideCursor, settings.ini, General, hideCursor
	;Write Mouse
	IniWrite, % opr, settings.ini, Mouse, r
	IniWrite, % opinterval, settings.ini, Mouse, interval
	IniWrite, % opminmove, settings.ini, Mouse, minmove
	IniWrite, % opacceleration, settings.ini, Mouse, acceleration
	IniWrite, % 2-opinvertedX, settings.ini, Mouse, invertedX
	IniWrite, % 2-opinvertedY, settings.ini, Mouse, invertedY
	IniWrite, % opMouseStick-1, settings.ini, Mouse, MouseStick
	;Write Keyboard-Movement
	IniWrite, % opupKey, settings.ini, Keyboard-Movement, upKey
	IniWrite, % opleftKey, settings.ini, Keyboard-Movement, leftKey
	IniWrite, % opdownKey, settings.ini, Keyboard-Movement, downKey
	IniWrite, % oprightKey, settings.ini, Keyboard-Movement, rightKey
	If opmovementIncrement>1
		opmovementIncrement:=1
	If opmovementIncrement<0.1
		opmovementIncrement:=0.1
	IniWrite, % opmovementSmoothing, settings.ini, Keyboard-Movement, movementSmoothing
	IniWrite, % opmovementIncrement, settings.ini, Keyboard-Movement, movementIncrement
	IniWrite, % opwalkModifierKey, settings.ini, Keyboard-Movement, walkModifierKey
	IniWrite, % opwalkToggleMode, settings.ini, Keyboard-Movement, walkToggleMode	
	IniWrite, % opincreaseWalkKey, settings.ini, Keyboard-Movement, increaseWalkKey
	IniWrite, % opdecreaseWalkKey, settings.ini, Keyboard-Movement, decreaseWalkKey
	IniWrite, % Round(opwalkSpeed/100, 2), settings.ini, Keyboard-Movement, walkSpeed
	IniWrite, % 2-opinvertedLX, settings.ini, Keyboard-Movement, invertedLX
	IniWrite, % 2-opinvertedLY, settings.ini, Keyboard-Movement, invertedLY
	IniWrite, % opMovementStick-1, settings.ini, Keyboard-Movement, MovementStick
	;Write Keybinds
	IniWrite, % opjoystickButtonKeyList, settings.ini, Keybinds, joystickButtonKeyList
	;Bloodborne
	IniWrite, % opjoystickButtonKeyListBB, settings.ini, Bloodborne, joystickButtonKeyListBB
	; Write Extra Settings
	;IF (RegexMatch(opjoystickButtonKeyList, "i)wheel(down|up)")) ; If wheeldown/up is part of the keylist you cannot use the special wheel functions for BotW
Return

selectionPath(ID) {
	TV_GetText(name,ID)
	IF (!name)
		Return 0
	parentID := ID
	Loop
	{
		parentID := TV_GetParent(parentID)
		IF (!parentID)
			Break
		parentName=
		TV_GetText(parentName, parentID)
		IF (parentName)
			name := parentName ">" name
	}
	Return name
}

findByName(Name){
	retID := False
	ItemID = 0  ; Causes the loop's first iteration to start the search at the top of the tree.
	Loop
	{
		ItemID := TV_GetNext(ItemID, "Full")  ; Replace "Full" with "Checked" to find all checkmarked items.
		IF (!ItemID)  ; No more items in tree.
			Break
		temp := selectionPath(ItemID)
		IF (temp = Name) {
			retID := ItemID
			Break
		}
	}
	Return retID
}

BuildTree(aGUI, treeString, oParent := 0) {
	Static pParent := []
	Static Call := 0
	Loop, Parse, treeString, `n, `r
	{
		startingString := A_LoopField
		temp := StrSplit(startingString, ",")
		Loop % temp.MaxIndex()
		{
			useString := Trim(temp[A_Index])
			IF (!useString)
				Continue
			Else IF (useString = "||") {
				useIndex := A_Index+1
				While (useIndex < temp.MaxIndex() + 1) {
					useRest .= "," . temp[useIndex]
					useIndex++
				}
				useRest := SubStr(useRest, 2)
				BuildTree(aGUI, useRest, pParent[--Call])
				Break
			}
			Else IF InStr(useString, "|") {
				newTemp := StrSplit(useString, "|")
				pParent[Call++] := oParent
				uParent := TV_Add(newTemp[1], oParent, (oParent = 0 ) ? "Expand" : "")
				useRest := RegExReplace(useString, newTemp[1] . "\|(.*)$", "$1")
				useIndex := A_Index+1
				While (useIndex < temp.MaxIndex() + 1) {
					useRest .= "," . temp[useIndex]
					useIndex++
				}
				BuildTree(aGUI, useRest, uParent)
				Break
			}
			Else
				TV_Add(useString, oParent)
		}
	}
}

NumberCheck(hEdit) {
    static PrevNumber := []

    ControlGet, Pos, CurrentCol,,, ahk_id %hEdit%
    GUIControlGet, NewNumber,, %hEdit%
    StrReplace(NewNumber, ".",, Count)

    If NewNumber ~= "[^\d\.-]|^.+-" Or Count > 1 { ; BAD
        GUIControl,, %hEdit%, % PrevNumber[hEdit]
        SendMessage, 0xB1, % Pos-2, % Pos-2,, ahk_id %hEdit%
    }

    Else ; GOOD
        PrevNumber[hEdit] := NewNumber
}

LoadSavedList:
	GUIControlGet, slName,, opSaveListName
	IniRead, ldKeyList, SavedKeyLists.ini, %slName%, KeyList
	IF (ldKeyList != "ERROR")
		GUIControl,, opjoystickButtonKeyList, %ldKeyList%
Return

SaveSavedList:
	GUIControlGet, slName,, opSaveListName
	IF (!slName) {
		MsgBox, Please enter anything as an identifier
		Return
	}
	GUIControlGet, slList,, opjoystickButtonKeyList
	IniWrite, %slList%, SavedKeyLists.ini, %slName%, KeyList
	IniRead,allSavedLists,SavedKeyLists.ini
	allSavedLists := StrReplace(allSavedLists, "`n", "|")
	GUIControl,, opSaveListName, % "|" . allSavedLists
	GUIControl, Text, opSaveListName, %slName%
Return

DeleteSavedList:
	GUIControlGet, slName,, opSaveListName
	IniDelete, SavedKeyLists.ini, %slName%
	IniRead,allSavedLists,SavedKeyLists.ini
	allSavedLists := StrReplace(allSavedLists, "`n", "|")
	GUIControl,, opSaveListName, % "|" . allSavedLists
Return

; Default settings in case problem reading/writing to file.
setSettingsToDefault:
	pairsDefault=
(
usevXBox=1
gameExe=
autoActivateGame=0
controllerSwitchKey=F1
exitKey=#q
hideCursor=1
r=80
interval=1
minmove=0.37
acceleration=0
invertedX=0
invertedY=0
MouseStick=1
upKey=w
leftKey=a
downKey=s
rightKey=d
movementSmoothing=1
movementIncrement=0.9
walkModifierKey=LAlt
walkToggleMode=0
increaseWalkKey=NumpadAdd
decreaseWalkKey=NumpadSub
walkSpeed=0.50
invertedLX=0
invertedLY=0
MovementStick=0
joystickButtonKeyList=e,Escape,r,f,XButton1,LButton,RButton,MButton,,Tab,,q,Home,End,Left,Right
joystickButtonKeyListBB=,,,,,,
)
	Loop,Parse,pairsDefault,`n
	{
		StringSplit,keyValue,A_LoopField,=
		%keyValue1%:=keyValue2
	}
	Goto, readSettingsSkippedDueToError
Return
;------------------------------------------------------------------------------Keyhelper for Bloodborn bonus keys
#IF KeyHelperRunning(setToggle)
#IF
KeyListHelperBB:
Hotkey, IF, KeyHelperRunning(setToggle)
HotKey,~LButton, getControlSimple, On
Hotkey, IF
GUI, Main:Default
GUIControlGet, getKeyList,, opjoystickButtonKeyListBB
KeyListByNumBB := []
Loop, Parse, getKeyList, `,
{
	keyName := A_LoopField
	If !keyName
		continue
	KeyListByNumBB[A_Index] := keyName
}
textWidth := 85
numEdits := 7
setToggle := False
GUI, Main:+Disabled
GUI, KeyHelper:New, +HWNDKeyHelperHWND -MinimizeBox +OwnerMain
GUI, Margin, 10, 7.5
GUI, Font,, Lucida Sans Typewriter ; Courier New
GUI, Add, Text, W0 H0 vLoseFocus, Hidden
GUI, Add, Text, W%textWidth% R1 Right Section, Dodge/Backstep
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[1]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v1, X
GUI, Add, Text, W%textWidth% xs R1 Right, Dodge
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[2]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v2, X
GUI, Add, Text, W%textWidth% xs R1 Right, Backstep
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[3]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v3, X
GUI, Add, Text, W%textWidth% xs R1 Right, Sprint
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[4]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v4, X
GUI, Add, Text, W%textWidth% xs R1 Right, Jump
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[5]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v5, X
GUI, Add, Text, W%textWidth% xs R1 Right, Jump Attack
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[6]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v6, X
GUI, Add, Text, W%textWidth% xs R1 Right, Save&&Quit
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNumBB[7]
GUI, Add, Button, xp+85 yp-1 w19 gClearOne v7, X
GUI, Add, Text, w0 xs R1 Right, Dummy

GUI, Add, Button, ys+122 w170 gClearButtonBB Section, Clear All
GUI, Add, Button, xs w80 gSaveButtonBB, Save
GUI, Add, Button, x+m w80 gCancelButton, Cancel
GUI, Add, Text, w0 yp+15 R1 Right, Dummy

GUI, Add, Text, xs+10 yp-170 R1 Left, Most of these only work correctly`nwith the Jump on L3 mod`n`nKey combinations`nare not supported

GUI, Show,, KeyList Helper
GuiControl, Focus, LoseFocus
Return
;------------------------------------------------------------------------------
#IF KeyHelperRunning(setToggle)
#IF
KeyListHelper:
Hotkey, IF, KeyHelperRunning(setToggle)
HotKey,~LButton, getControl, On
Hotkey, IF
GUI, Main:Default
GUIControlGet, getKeyList,, opjoystickButtonKeyList
KeyListByNum := []
IF (vXBox) {
	textWidth := 50
	numEdits := 16
}
Else {
	textWidth := 50
	numEdits := 16
}
Loop, Parse, getKeyList, `,
{
	useButton := A_Index
	If InStr(A_LoopField, "|") {
		Loop, Parse, A_LoopField, |
		{	
			keyName := A_LoopField
			If !keyName
				continue
			KeyListByNum[useButton] := keyName
			useButton+=numEdits
		}
	} Else {
		keyName := A_LoopField
		If !keyName
			continue
		KeyListByNum[useButton] := keyName
	}
}
editWidth:=140
editWidth2:=editWidth
XWidth:=19
setToggle := False
GUI, Main:+Disabled
GUI, KeyHelper:New, +HWNDKeyHelperHWND -MinimizeBox +OwnerMain
GUI, Margin, 10, 7.5
GUI, Font,, Lucida Sans Typewriter ; Courier New
GUI, Add, Text, W0 H0 vLoseFocus, Hidden
GUI, Add, Text, W%textWidth% R1 Right Section, % vXBox ? "A" : "✕"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[1]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v1, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "B" : "○"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[2]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v2, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "X" : "⬜"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[3]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v3, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "Y" : "△"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[4]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v4, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "LB" : "L1"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[5]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v5, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "RB" : "R1"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[6]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v6, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "LT" : "L2"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[7]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v7, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "RT" : "R2"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[8]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v8, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "Back" : "Share"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[9]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v9, X
GUI, Add, Text, W%textWidth% xs R1 Right, % vXBox ? "Start" : "Option"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[10]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v10, X
GUI, Add, Text, w45 xp+182 ys R1 Right Section, % vXBox ? "LS" : "L3"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[11]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v11, X
GUI, Add, Text, w45 xs ys+26 R1 Right, % vXBox ? "RS" : "R3"
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[12]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v12, X
GUI, Add, Text, w45 xs ys+60 R1 Right Section, D-Up
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[13]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v13, X
GUI, Add, Text, w80 xs-35 R1 Right, D-Down
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[14]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v14, X
GUI, Add, Text, w80 xs-35 R1 Right, D-Left
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[15]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v15, X
GUI, Add, Text, w80 xs-35 R1 Right, D-Right
GUI, Add, Edit, W%editWidth% R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[16]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v16, X
GUI, Add, Edit, W%editWidth% R1 xp-358 yp-137 Center ReadOnly -TabStop, % KeyListByNum[17]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v17, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[18]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v18, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[19]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v19, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[20]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v20, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[21]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v21, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[22]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v22, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[23]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v23, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[24]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v24, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[25]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v25, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[26]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v26, X
GUI, Add, Edit, W%editWidth% R1 xs+214 ys-63 Center ReadOnly -TabStop Section, % KeyListByNum[27]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v27, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[28]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v28, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+35 Center ReadOnly -TabStop, % KeyListByNum[29]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v29, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[30]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v30, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[31]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v31, X
GUI, Add, Edit, W%editWidth% R1 xp-%editWidth% yp+27 Center ReadOnly -TabStop, % KeyListByNum[32]
GUI, Add, Button, xp+%editWidth2% yp-1 w%XWidth% gClearOne v32, X
GUI, Add, Text, w0 xs-35 R1 Right, Dummy

GUI, Add, Text, w0 xm+400 R1 Right, Dummy
GUI, Add, Button, xp yp-30 w80 gSaveButton Section, Save
GUI, Add, Button, x+m w80 gCancelButton, Cancel
GUI, Add, Button, xs yp-30 w170 gAutoLoop, Auto Cycle
GUI, Add, Button, xs yp-30 w170 gClearButton, Clear All
GUI, Add, Text, ys-60 R1 Left Section, Set up two keys/controller input`nKey combinations are supported

GUI, Show,, KeyList Helper
GuiControl, Focus, LoseFocus
Return

ClearButton:
	GUI, KeyHelper:Default
	Loop % numEdits * 2
		GUIControl,,Edit%A_Index%,
Return

ClearButtonBB:
	GUI, KeyHelper:Default
	Loop %numEdits%
		GUIControl,,Edit%A_Index%,
Return

ClearOne:
	GUI, KeyHelper:Default
	GUIControl,,Edit%A_GuiControl%,
Return

CancelButton:
KeyHelperGUIClose:
	IF (setToggle)
		Return
	Hotkey, IF, KeyHelperRunning(setToggle)
	HotKey,~LButton, getControl, Off
	HotKey,~LButton, getControlSimple, Off
	Hotkey, IF
	GUI, Main:-Disabled
	GUI, KeyHelper:Destroy
Return

SaveButton:
	tempList := ""
	Loop %numEdits%
	{
	Secondary:=A_Index+numEdits
	GUIControlGet, tempKey,,Edit%A_Index%
	GUIControlGet, tempKeySecondary,,Edit%Secondary%
	If (tempKey and !tempKeySecondary) or (!tempKey and !tempKeySecondary) {
		tempList .= tempKey . ","
		continue
	}
	If (!tempKey and tempKeySecondary) {
		tempList .= tempKeySecondary . ","
		continue
	}
	If (tempKey and tempKeySecondary) {
		tempList .= tempKey . "|"
		tempList .= tempKeySecondary . ","
		continue
	}
	GUIControlGet, tempKey,,Edit%alt%
		tempList .= tempKey . ","
	}
	tempList := SubStr(tempList,1, StrLen(tempList)-1)
GUI, Main:Default
GUIControl,, opjoystickButtonKeyList, %tempList%
GoSub, KeyHelperGUIClose
Return

SaveButtonBB:	;Save button for Bloodborne key list
	tempList := ""
	Loop %numEdits%
	{
	GUIControlGet, tempKey,,Edit%A_Index%
		tempList .= tempKey . ","
	}
	tempList := SubStr(tempList,1, StrLen(tempList)-1)
GUI, Main:Default
GUIControl,, opjoystickButtonKeyListBB, %tempList%
GoSub, KeyHelperGUIClose
Return

getControl:
	GUI, KeyHelper:Default
	KeyWait, LButton

	setToggle := True
	MouseGetPos,,, mouseWin, useControl, 1
	IF (InStr(useControl, "Edit") AND mouseWin = KeyHelperHWND)
		GetKey()
	setToggle := False

	clearFocus:
	GuiControl, Focus, LoseFocus
Return

getControlSimple:
	GUI, KeyHelper:Default
	KeyWait, LButton

	setToggle := True
	MouseGetPos,,, mouseWin, useControl, 1
	IF (InStr(useControl, "Edit") AND mouseWin = KeyHelperHWND)
		GetKeySimple()
	setToggle := False

	; clearFocus:
	GuiControl, Focus, LoseFocus
Return

setWalkModKey:
	MouseGetPos,,,,useControl,1
	opwalkModifierKey:=GetKeySimple()
Return

AutoLoop:
	GUI, KeyHelper:Default
	Loop 4
		GUIControl, +Disabled, Button%A_Index%
	setToggle := True
	Loop %numEdits% {
		useControl := "Edit" . A_Index
		GetKey()
		If GetKeyState("LCtrl","P")	;prevent issues during auto-loop
			keywait, LCtrl
		If GetKeyState("LAlt","P")
			keywait, LAlt
		If GetKeyState("LShift","P")
			keywait, LShift
	}
	setToggle := False
	Loop 4
		GUIControl, -Disabled, Button%A_Index%
	GoSub, clearFocus
	MsgBox, Done
Return

KeyHelperRunning(setTog){
	Return (WinActive("KeyList Helper") AND !setTog)
}

GetKeySimple() {	;use separate function for non-main keybinds
	Global
	GoSub, TurnOn
	MousePressed := False
	GUIControl, -E0x200, %useControl%
	GuiControl,Text, %useControl%, Waiting
	ihSimple.Start()
	ErrorLevel := ihSimple.Wait()
	singleKey := ihSimple.EndKey
	GoSub, TurnOff
	
	IF (MousePressed)
		singleKey := MousePressed
	Else IF (singleKey = "," OR singleKey = "=") ; Comma and equal sign Don't work
		singleKey := ""
	
	singleKey := RegexReplace(singleKey, "Control", "Ctrl")
		
	GuiControl, Text, %useControl%, %singleKey%
	GUIControl, +E0x200, %useControl%
	Loop %numEdits%
	{
		GUIControlGet, tempKey,,Edit%A_Index%
		IF (tempKey = singleKey AND useControl != "Edit" . A_Index)
			GuiControl, Text, Edit%A_Index%,
	}
Return singleKey
}

GetKey() {
	Global
	GoSub, TurnOn
	EndIH:=0
	DetectSingleModifiersSet:=0
	MousePressed := False
	GUIControl, -E0x200, %useControl%
	GuiControl,Text, %useControl%, Waiting
	; ih.Start()
	; ErrorLevel := ih.Wait()
	; singleKey := ih.EndKey
	
	ih := InputHook()
	ih.KeyOpt("{All}", "E")
    ih.KeyOpt("{LCtrl}{LAlt}{LShift}", "-E +N")	;only allow left ctrl/shift/alt
	ih.KeyOpt("{RCtrl}{RShift}{LWin}{RWin}", "-E +S -N")
	ih.OnKeyDown := Func("DetectSingleModifiers")
	ih.OnKeyUp := Func("EndInputHook")
    ih.Start()
    ErrorLevel := ih.Wait()
	
	If !EndIH	;skip line below when InputHook was ended by a single modifier
		singleKey := ih.EndMods . ih.EndKey
	
	GoSub, TurnOff
	
	IF (MousePressed)
		singleKey := MousePressed
	Else IF (InStr(singleKey,",") OR InStr(singleKey,"=") OR InStr(singleKey,"RAlt")) ; Comma and equal sign Don't work, RAlt also
		singleKey := ""
	
	; singleKey := RegexReplace(singleKey, "Control", "Ctrl")	;not needed anymore
	
	singleKey:=alterModifiers(singleKey)	;modifier magic

	GuiControl, Text, %useControl%, %singleKey%
	GUIControl, +E0x200, %useControl%
	Loop % numEdits * 2
	{
		GUIControlGet, tempKey,,Edit%A_Index%
		IF (tempKey = singleKey AND useControl != "Edit" . A_Index)
			GuiControl, Text, Edit%A_Index%,
	}
Return singleKey
}

DetectSingleModifiers(ih) {
	Global DetectSingleModifiersSet, singleKey
	If !DetectSingleModifiersSet {
		If GetKeyState("LCtrl","P") {
			singleKey:="LCtrl"
			DetectSingleModifiersSet:=1
		} Else If GetKeyState("LAlt","P") {
			singleKey:="LAlt"
			DetectSingleModifiersSet:=1
		} Else If GetKeyState("LShift","P") {
			singleKey:="LShift"
			DetectSingleModifiersSet:=1
		} Else If GetKeyState("RAlt","P") {
			ih.Stop()
		}
	}
}

EndInputHook(ih) {
	Global EndIH
	EndIH:=1
	ih.Stop()
}

alterModifiers(singleKey) {
	If (singleKey="<^")
		singleKey := "LCtrl"
	If (singleKey="<!")
		singleKey := "LAlt"
	If (singleKey="<+")
		singleKey := "LShift"
	If ((singleKey="<^<!") or (singleKey="<^<+") or (singleKey="<!<+") or (singleKey="<^<!<+")) {	;do not allow double/triple modifiers on their own
		Return
	}
	singleKey := RegexReplace(singleKey, "\<\^", "LCtrl+")
	singleKey := RegexReplace(singleKey, "\<\!", "LAlt+")
	singleKey := RegexReplace(singleKey, "\<\+", "LShift+")
	Return singleKey
}

GetMouseModifiers() {	;function to add modifiers to the mouse buttons
	If GetKeyState("LCtrl","P")
		Modifier:="<^"
	If GetKeyState("LAlt","P")
		Modifier:=Modifier . "<!"
	If GetKeyState("LShift","P")
		Modifier:=Modifier . "<+"
	Return Modifier
}

WM_LBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	Modifier:=GetMouseModifiers()
	MousePressed := Modifier . "LButton"
	Return 0
}

WM_RBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	Modifier:=GetMouseModifiers()
	MousePressed := Modifier . "RButton"
	Return 0
}

WM_MBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	Modifier:=GetMouseModifiers()
	MousePressed := Modifier . "MButton"
	Return 0
}

WM_XBUTTONDOWN(w) {
	Global useControl, MousePressed
	Send, {Esc}
	Modifier:=GetMouseModifiers()
	SetFormat, IntegerFast, Hex
	IF ((w & 0xF0) = 0x20)	;changed 0xFF -> 0xF0 because modifier+XButton resulted in a different value
		MousePressed := Modifier . "XButton1"
	Else IF((w & 0xF0) = 0x40)	;changed 0xFF -> 0xF0 because modifier+XButton resulted in a different value
		MousePressed := Modifier . "XButton2"
	Return 0
}

WM_MOUSEHWHEEL(w) {
	Global useControl, MousePressed
	Send, {Esc}
	Modifier:=GetMouseModifiers()
	SetFormat, IntegerFast, Hex
	IF ((w & 0xFF0000) = 0x780000)
		MousePressed := Modifier . "WheelRight"
	Else IF((w & 0xFF0000) = 0x880000)
		MousePressed := Modifier . "WheelLeft"
	Return 0
}

WM_MOUSEWHEEL(w) {
	Global useControl, MousePressed
	Send, {Esc}
	Modifier:=GetMouseModifiers()
	SetFormat, IntegerFast, Hex
	MousePressed := "" . w + 0x0
	IF ((w & 0xFF0000) = 0x780000)
		MousePressed := Modifier . "WheelUp"
	Else IF((w & 0xFF0000) = 0x880000)
		MousePressed := Modifier . "WheelDown"
	Return 0
}

TurnOn:
OnMessage(0x0201, "WM_LBUTTONDOWN")
OnMessage(0x0204, "WM_RBUTTONDOWN")
OnMessage(0x0207, "WM_MBUTTONDOWN")
OnMessage(0x020B, "WM_XBUTTONDOWN")
OnMessage(0x020E, "WM_MOUSEHWHEEL")
OnMessage(0x020A, "WM_MOUSEWHEEL")
Return

TurnOff:
OnMessage(0x0201, "")
OnMessage(0x0204, "")
OnMessage(0x0207, "")
OnMessage(0x020B, "")
OnMessage(0x020E, "")
OnMessage(0x020A, "")
Return

;-------------------------------------------------------------------------------
show_Mouse(bShow := True) { ; show/hide the mouse cursor
;-------------------------------------------------------------------------------
	; https://autohotkey.com/boards/viewtopic.php?p=173707#p173707
    ; WINAPI: SystemParametersInfo, CreateCursor, CopyImage, SetSystemCursor
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms724947.aspx
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648385.aspx
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648031.aspx
    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms648395.aspx
    ;---------------------------------------------------------------------------
    static BlankCursor
    static CursorList := "32512, 32513, 32514, 32515, 32516, 32640, 32641"
        . ",32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650, 32651"
    local ANDmask, XORmask, CursorHandle

    IF (bShow) ; shortcut for showing the mouse cursor
        Return, DllCall("SystemParametersInfo"
            , "UInt", 0x57              ; UINT  uiAction    (SPI_SETCURSORS)
            , "UInt", 0                 ; UINT  uiParam
            , "Ptr",  0                 ; PVOID pvParam
            , "UInt", 0)                ; UINT  fWinIni

    IF (!BlankCursor) { ; create BlankCursor only once
        VarSetCapacity(ANDmask, 32 * 4, 0xFF)
        VarSetCapacity(XORmask, 32 * 4, 0x00)
        BlankCursor := DllCall("CreateCursor"
            , "Ptr", 0                  ; HINSTANCE  hInst
            , "Int", 0                  ; int        xHotSpot
            , "Int", 0                  ; int        yHotSpot
            , "Int", 32                 ; int        nWidth
            , "Int", 32                 ; int        nHeight
            , "Ptr", &ANDmask           ; const VOID *pvANDPlane
            , "Ptr", &XORmask)          ; const VOID *pvXORPlane
    }

    ; set all system cursors to blank, each needs a new copy
    Loop, Parse, CursorList, `,, %A_Space%
    {
        CursorHandle := DllCall("CopyImage"
            , "Ptr", BlankCursor        ; HANDLE hImage
            , "UInt", 2                 ; UINT   uType      (IMAGE_CURSOR)
            , "Int",  0                 ; int    cxDesired
            , "Int",  0                 ; int    cyDesired
            , "UInt", 0)                ; UINT   fuFlags
        DllCall("SetSystemCursor"
            , "Ptr", CursorHandle       ; HCURSOR hcur
            , "UInt",  A_Loopfield)     ; DWORD   id
    }
}
