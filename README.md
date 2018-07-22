Homebrew tap of RRG Proxmark3 repo based on iceman fork
=======================================================

[Homebrew](http://brew.sh) - is a open-source package manager for Apple macOS.

This repository contains homebrew formulas for RRG iceman fork of proxmark3 project with it dependencies.
The old HID-flasher doesn't compile on this version. You'll need to manually fix/compile it on MacOS.

### Install

1. Install homebrew if you haven't yet already done so: http://brew.sh/

2. Tap this repo: `brew tap rfidresearchgroup/proxmark3`

3. Install Proxmark3:
    `brew install proxmark3` for stable release 
	`brew install --HEAD proxmark3` for latest non-stable from GitHub (use this if previous command fails)

	 
### Usage

Proxmark3 will be installed in `/usr/local/bin/proxmark3`  

Firmware located at `/usr/local/share/firmware/`  


#### Connect to device
`proxmark3 /dev/tty.usbmodem88888` 

usually you replace the tty with where your proxmark3 device got installed on your system.


#### Flashing bootloader & firmware  
`sudo proxmark3-flasher /dev/tty.usbmodem88888 -b /usr/local/share/firmware/bootrom.elf /usr/local/share/firmware/fullimage.elf`  
 
	
### Info

Current release version is ice_v4.0.0


###Maintainers

original [chrisfu](https://github.com/chrisfu/homebrew-tap), [zhovner](https://github.com/zhovner)

fork [iceman1001](https://github.com/RfidResearchGroup/homebrew-proxmark3)
