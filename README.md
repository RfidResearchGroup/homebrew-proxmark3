Homebrew tap for RRG/Iceman Proxmark3 repo
=========================================

[Homebrew](http://brew.sh) - is a open-source package manager for Apple macOS.

This repository contains homebrew formulas for RRG/Iceman Proxmark3 project with it dependencies.

[note]
The old HID-flasher doesn't compile on this version. You'll need to manually fix/compile it on MacOS but this old flasher software is used if you have firmware from 2012 installed on your device.  

### Install

- Install homebrew if you haven't yet already done so: http://brew.sh/

- Tap this repo: `brew tap rfidresearchgroup/proxmark3`

- Install Proxmark3:
  - (Optional) `export HOMEBREW_PROXMARK3_PLATFORM=xxxxxx` to specify [platform](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Use_of_Proxmark/4_Advanced-compilation-parameters.md#platform), default value is `PM3RDV4` if none
  - `brew install proxmark3` for stable release 
  - `brew install --HEAD proxmark3` for latest non-stable from GitHub (use this if previous command fails)
  - `brew install --with-blueshark proxmark3` for blueshark support

### Errors while running

- If you see this message 
    `To reinstall HEAD, run brew reinstall proxmark3`
- do this
   ```
   brew remove proxmark3
   brew reinstall proxmark3
   ```

	 
### Usage

Proxmark3 client will be installed in 
`/usr/local/bin/proxmark3`  

Firmware will be located in 
`/usr/local/share/firmware/`  

_If you did a **install --HEAD**,  the firmware will be located in a subfolder_


See [instructions on the RRG repo](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Installation_Instructions/Mac-OS-X-Homebrew-Installation-Instructions.md#flash-the-bootrom--fullimage)

### Maintainers

original [chrisfu](https://github.com/chrisfu/homebrew-tap), [zhovner](https://github.com/zhovner)

fork [iceman1001](https://github.com/RfidResearchGroup/homebrew-proxmark3)
