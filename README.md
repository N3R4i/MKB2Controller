Version 1.0.1

**SETUP GUIDE AT THE BOTTOM**

Acknowledgements
 * Helgef - Original mouse2joystic
 * CemuUser8 - mouse2joystick Custom CEMU version
 * Nefarius Software Solutions e.U. - ViGEmBus
 * evilC - AHK-ViGEm-Bus.ahk/ViGEmWrapper.dll

## Description
MKB2Controller allows the user to control a virtual controller with mouse and keyboard. Main purpose is for emulators and games that don't have mouse and keyboard support. Requires ViGEmBus to emulate the virtual controller. Based on Helgef's and CemuUser8's mouse2joystick.

## Main features
 * Supports both XInput and DirectInput virtual controllers. High precision mouse to analogue stick conversion with scalable sensitivity, optional deadzone compensation, mouse acceleration. Mouse/movement keys can be assigned to either stick. Inverted axis option. Main keybinds can be saved into separate profiles. Walk modifier key (both hold and toggle modes).
 * **BloodBorne Bonus Buttons [B<sup>4</sup>]** - Extra hotkeys specifically for Bloodborne. These hotkeys require the [Jump on L3 mod](https://www.nexusmods.com/bloodborne/mods/156?tab=description) to function properly.

## Known Issues
* ~~In shadPS4 Bloodborne, sometimes the camera starts stuttering periodically (roughly once every second).~~
* ~~Also in shadPS4 Bloodborne, there's a slight but constant camera stutter.~~
* ~~Workaround: this sounds very bizzare, but letting Yuzu run in the background eliminates both of these stutters ?WTF? Also, as a result, none of these issues happen in Yuzu.~~

With the later version of shadPS4, these issues seem be to resolved.

## Troubleshooting
* Try running the .exe as admin
* In case the ViGEmWrapper.dll is blocked, unblock it: right click on the .dll -> Properties -> General -> At the bottom of the tab Unblock (if you don't see this option, then the .dll is not blocked)

## Settings Overview
* **General**
  * Output Mode - Choose between XInput and DirectInput
  * Executable Name - Enter the executable's full name
  * Auto Switch - Will automatically switch to the game window when toggling on the controller
  * Toggle Controller On/Off - Set the key to toggle the controller (Default F1)
  * Quit Application - Set a hotkey to close the app
  * Hide Cursor - Show/Hide the cursor when the controller is switched on 
* **Mouse**
  * Resistance - Controls the camera sensitivity. Higher resistance=lower sensitivity and vice-versa
  * Mouse Check Interval (ms) - Value in ms. This is how often the mouse position is checked and reset back to the center. Higher value causes delayed camera control. Should be 1.
  * Deadzone Compensation - Used to eliminate ingame deadzone. Causes the stick tilt to start at the specified value. E.g. 0.5 will make the stick tilt start at 50% of its full range. Should be the same as the game's deadzone to improve mouse precision.
  * Mouse Acceleration - Exponent to control the mouse speed/camera sensitivity curve. Fast camera movement becomes even faster, slow camera movement is less affected. Set to 0 to turn it off.
  * Invert X/Y-Axis - self explanatory
  * Mouse to stick L/R - Choose which stick to control with the mouse
* **Keyboard-Movement**
  * Keyboard Movement - self explanatory
  * Walk Modifier - Set up keys for walking and increasing/decreasing walking speed. Check toggle if you want toggle mode instead of hold mode.
  * Invert X/Y-Axis - self explanatory
  * Movement to stick L/R - Choose which stick to control with the movement keys
* **Keybinds**
	* KeyList Helper - This is where you can conveniently set up your main keybinds
	* Saved KeyList Manager - Allows you to save your main keybinds into separate profiles
* **Bloodborne**
	* BonusButtons Bonus Buttons [B<sup>4</sup>] - Extra hotkeys for Bloodborne. [Jump on L3 mod](https://www.nexusmods.com/bloodborne/mods/156?tab=description) is required. Each key does specifically what it says. All dodge and backstep binds are executed on key press, rather than on release.
		* **Dodge/Backstep** - Dedicated dodge/backstep key | While standin still -> backstep | While running/sprinting -> dodge
		* **Dodge** - Dedicated dodge key | While standin still -> dodge forward | While running/sprinting -> dodge
		* **Backstep** - Dedicated backstep key | While standin still/running/sprinting -> backstep
		* **Sprint** - Dedicated sprint key | It makes you sprint
		* **Jump** - Dedicated jump key | It makes you jump
		* **Jump Attack** - Dedicated jump attack key | Does a jump attack. Can be used while standing still/running/sprinting.
		* **Save&Quit** - For tight situations

# Setup Guide
1. Download and install ViGEmBus [Windows 10/11](https://github.com/nefarius/ViGEmBus/releases/tag/v1.22.0) | [Windows 7/8.1](https://github.com/nefarius/ViGEmBus/releases/tag/setup-v1.16.116)<sup>1 2</sup>
1. Download and run the latest release of [MKB2Controller](https://github.com/N3R4i/MKB2Controller/releases/latest)
2. Double click on the **MKB2Controller tray icon**
3. Refer to the [Settings Overview](https://github.com/N3R4i/MKB2Controller#settings-overview) if an option is not clear
4. Run the game and press your toggle key (default is **F1**)

_<sup>1 </sup>For Windows 7 you may also need this: [Xbox 360 Controller for Windows driver](https://web.archive.org/web/20160425082525/https://www.microsoft.com/hardware/en-us/d/xbox-360-controller-for-windows)_<br>
_<sup>2 </sup>If you're installing the older version of ViGEmBus for Win7/8.1, you should read this [Adjusting the ViGEmBus updater (for Windows 7 and 8/8.1)](https://docs.nefarius.at/projects/ViGEm/End-of-Life/)_
