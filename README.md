Homebrew tap of RRG Proxmark3 repo based on iceman fork
=======================================================

[Homebrew](http://brew.sh) - is a open-source package manager for Apple macOS.

This repository contains homebrew formulas for Rfid Research Group RRG proxmark3 project with it dependencies.
The repo is based on iceman fork.
The old HID-flasher doesn't compile on this version. You'll need to manually fix/compile it on MacOS.

### Install

- Install homebrew if you haven't yet already done so: http://brew.sh/

- Tap this repo: `brew tap rfidresearchgroup/proxmark3`

- Install Proxmark3:
  - `brew install proxmark3` for stable release 
  - `brew install --HEAD proxmark3` for latest non-stable from GitHub (use this if previous command fails)
  - `brew install --with-blueshark proxmark3` for blueshark support

	 
### Usage

Proxmark3 will be installed in `/usr/local/bin/proxmark3`  

Firmware located at `/usr/local/share/firmware/`  


#### Connect to device
`proxmark3 /dev/tty.usbmodem888` 

usually you replace the tty with where your proxmark3 device got installed on your system.


#### Flashing bootloader & firmware  
`sudo proxmark3-flasher /dev/tty.usbmodem888 -b /usr/local/share/firmware/bootrom.elf /usr/local/share/firmware/fullimage.elf`  
 
	
### Info

Current release version is UNKNOWN


### Maintainers

original [chrisfu](https://github.com/chrisfu/homebrew-tap), [zhovner](https://github.com/zhovner)

fork [iceman1001](https://github.com/RfidResearchGroup/homebrew-proxmark3)
