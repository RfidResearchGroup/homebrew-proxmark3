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
  - `brew install proxmark3` for stable release 
  - `brew install --HEAD proxmark3` for latest non-stable from GitHub (use this if previous command fails)
  - `brew install --with-blueshark proxmark3` for blueshark support, stable release
  - `brew install --HEAD --with-blueshark proxmark3` for blueshark support, latest non-stable from GitHub (use this if previous command fails)
  - `brew install --with-generic --with-flash proxmark3` build for generic (non-RDV4) devices with external flash chip, stable release

### Build options

Use `brew info proxmark3` to see all available options.

#### Platform selection

Firmware is built for the Proxmark3 RDV4 device by default. Use the following options to select other platforms:

- `--with-generic`: build for generic (non-RDV4) devices, see [platform](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Use_of_Proxmark/4_Advanced-compilation-parameters.md#platform).
- `--with-small`: enable build-time size limit for devices with 256kB flash, see [256kb versions](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Use_of_Proxmark/4_Advanced-compilation-parameters.md#256kb-versions).

#### Platform extras

RRG/Iceman Proxmark3 supports multiple [PLATFORM_EXTRAS](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Use_of_Proxmark/4_Advanced-compilation-parameters.md#platform_extras) parameters. Multiple options can be used at the same time, but make sure, you select the correct ones for your device.

- `--with-blueshark`: for blueshark support
- `--with-flash`: for generic proxmark 3 devices with external flash chip
- `--with-smartcard`: for generic proxmark 3 devices with smartcard support

#### Removing features

It's possible to remove features to reduce firmware size for 256kB devices using options such as `--without-lf`, `--without-hitag`, etc.

`--without-foo` corresponds to the `SKIP_FOO` compile options listed [here](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Use_of_Proxmark/4_Advanced-compilation-parameters.md#256kb-versions).

#### Standalone mode

Firmware is built with the `LF_SAMYRUN` standalone mode by default. Use the `--with-lf-foo` or `--with-hf-foo` options to select a different standalone mode,
or `--without-standalone` to disable standalone mode altogether.

`--with-lf-foo` corresponds to the `STANDALONE=LF_FOO` compile options listed [here](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Use_of_Proxmark/4_Advanced-compilation-parameters.md#standalone).

### Errors while running

- If you see this message 
    `To reinstall HEAD, run brew reinstall proxmark3`
- do this
   ```
   brew remove proxmark3
   brew reinstall proxmark3
   ```

### Force HomeBrew to pull the latest source from github

```sh
brew upgrade --fetch-HEAD proxmark3
```
	 
### Usage

Proxmark3 client will be installed in 
`/usr/local/bin/proxmark3`  

Firmware will be located in 
`/usr/local/share/firmware/`  

The paths mentioned above are symlinks created by Homebrew (`brew install` implies `brew link`) to your Cellar.

See [instructions on the RRG repo](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Installation_Instructions/macOS-Homebrew-Installation-Instructions.md#flash-the-bootrom--fullimage)
