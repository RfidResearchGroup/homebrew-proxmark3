# Homebrew tap for RRG/Iceman Proxmark

[Homebrew](https://brew.sh) packages for the
[RRG/Iceman Proxmark3](https://github.com/RfidResearchGroup/proxmark3) project on
macOS. Choose a shared client and install firmware for each device separately.
The formulae use upstream make targets and build options without patching the
upstream Makefiles, platform definitions, or flashing scripts.

## Packages

| Formula | Contents |
| --- | --- |
| `proxmark-client` | Command-line client, CDC flasher, scripts, dictionaries and host tools |
| `proxmark-client-gui` | The same client with Qt waveform analysis and image windows |
| `proxmark-firmware-generic` | `PM3GENERIC`, for generic 512 KB devices |
| `proxmark-firmware-rdv4` | `PM3RDV4` |
| `proxmark-firmware-pm5` | `PM5` |
| `proxmark-firmware-ultimate` | `PM3ULTIMATE` |
| `proxmark-firmware-custom` | Firmware with selectable platform, extras, feature trimming and standalone mode |

The two clients install the same commands and are mutually exclusive. Different
firmware packages can coexist: each installs its images in its own directory
and provides three package-specific flashing launchers. Firmware packages do
not declare either client as a runtime dependency, so you can choose and link
the CLI or GUI client. Clients do not need the ARM compiler or a firmware package.

iCopy-X is not packaged here: upstream requires a dedicated client build with
its own USB flashing behavior. This tap keeps the two general client variants.

The GUI remains a command-line client with auxiliary windows. It depends on
`qtbase`, `qtimageformats` and `qtsvg`, retaining waveform and image support
without the complete `qt` collection (WebEngine, Quick3D, Multimedia, etc.).

`PM3OTHER` is an upstream deprecated name for Generic, not a separate preset.
There is no `small` platform upstream. The current release's documented 256 KB
example exceeds that capacity; a `small` preset is deferred rather than changing
upstream defaults. Custom feature trimming remains available.

## Install

```sh
brew tap rfidresearchgroup/proxmark3
brew install proxmark-client proxmark-firmware-rdv4
# Or choose proxmark-client-gui instead of proxmark-client.
```

The legacy name `proxmark3` is an alias for `proxmark-client`, so installing
`rfidresearchgroup/proxmark3/proxmark3` installs the CLI client. Choose
`proxmark-client-gui` explicitly for Qt windows. The alias installs no device
firmware and does not forward old firmware options; existing combined-package
installations require the [migration steps below](#migrating-an-existing-combined-package).

Bottles are used when published for a compatible macOS version and CPU.
The CI builds bottles for arm64 Sequoia and Tahoe. Custom builds with options
compile from source.

Intel Macs retain source-build support on a best-effort basis. Homebrew has
[stopped building new Intel bottles](https://docs.brew.sh/Support-Tiers#future-macos-support),
and the current client dependencies lack a complete set of compatible bottles.
This tap does not build Intel bottles. Intel users may
need to build dependencies, including Qt and Python, from source; successful
Intel installation has not been validated.

To switch clients, unlink the installed variant before installing/linking the
other one. Firmware packages do not need to be switched.

```sh
brew unlink proxmark-client
brew install proxmark-client-gui
# If already installed: brew link proxmark-client-gui
```

All packages also support `--HEAD`. Keep the client and firmware on the same
upstream release; for HEAD builds, use matching source revisions.

## Firmware and flashing

Firmware images are installed under each package's prefix, for example:

```text
$(brew --prefix proxmark-firmware-rdv4)/share/proxmark3/firmware/rdv4/
  bootrom.elf
  fullimage.elf
  recovery.bin
```

Each firmware package provides `pm3-flash-<name>-all`,
`pm3-flash-<name>-bootrom` and `pm3-flash-<name>-fullimage`, where `<name>` is
`generic`, `rdv4`, `pm5`, `ultimate` or `custom`. To flash both images from the
RDV4 package:

```sh
pm3-flash-rdv4-all
```

Use the `-bootrom` or `-fullimage` command to flash only that image. Each launcher
checks that its required ELF files are readable, finds the corresponding
upstream `pm3-flash-*` helper on `PATH`, and runs it from the package's firmware
directory. Arguments and exit status are passed through unchanged. If the
helper is missing, the launcher explains how to install and link a client.

The linked client on `PATH` supplies the flashing implementation. A launcher's
package name selects firmware files, not a physical device: connected-device
discovery and the flashing protocol remain the upstream helper's behavior.
Choose images matching your hardware and keep the client and firmware versions
in sync; the launchers do not verify those matches.

The client retains the upstream `proxmark3`, `pm3` and `pm3-flash*` commands.
For advanced use, pass explicit image paths directly to `pm3-flash`:

```sh
firmware_dir="$(brew --prefix proxmark-firmware-rdv4)/share/proxmark3/firmware/rdv4"
pm3-flash -b "$firmware_dir/bootrom.elf"
pm3-flash "$firmware_dir/fullimage.elf"
```

`recovery.bin` is the combined image for JTAG recovery. No global default
firmware symlink is created. Directly invoking the original `pm3-flash-all`
helpers retains their filename lookup; use the package-specific launchers to
select one of the installed firmware directories.

The client also installs the upstream platform-independent smartcard upgrade
resources (`sim011`, `sim013`, `sim020`), scripts, dictionaries and host tools.

## Custom firmware

```sh
brew info rfidresearchgroup/proxmark3/proxmark-firmware-custom
brew install --build-from-source proxmark-firmware-custom --with-generic --with-flash
```

RDV4 is the default. Choose at most one of `--with-generic`, `--with-5`,
`--with-ultimate`. Other options retain their upstream
meaning:

- Extras: `--with-blueshark`, `--with-smartcard`, `--with-flash`;
  PM5 also supports `--with-bwm`, `--without-lowbatt-shutdown`, and
  `--without-lowbatt-beep`. Upstream couples the last option to the shutdown
  check: disabling the beep also disables low-battery shutdown.
- Feature trimming: `--without-lf`, `--without-hf`, `--without-seos`,
  `--without-em4x50`, `--without-desfire-sim`, and the other upstream `SKIP_*` flags.
- Standalone: `--with-lf-samyrun`, `--with-hf-mfcsim`, etc., or
  `--without-standalone`. Select at most one mode.
- `--with-small` requires `--with-generic`, retains the legacy trimming flags,
  and enables upstream's 256 KB size check. Current releases may still exceed
  the limit and need additional explicit `--without-*` choices.

Custom images are in `share/proxmark3/firmware/custom` under that package's
prefix; use `pm3-flash-custom-all`, `pm3-flash-custom-bootrom` or
`pm3-flash-custom-fullimage` to flash them. GUI selection belongs to the client
package, not the firmware build.
See upstream [Advanced compilation parameters](https://github.com/RfidResearchGroup/proxmark3/blob/master/doc/md/Use_of_Proxmark/4_Advanced-compilation-parameters.md).

## Toolchain and migration

Firmware builds retain the upstream tap dependency
`rfidresearchgroup/proxmark3/arm-none-eabi-gcc`. It supplies the complete Arm GNU
toolchain, including binutils and the matching C library headers. The existing compiler formula stays in this tap at the same version and
archive checksums. No separate newlib resource is downloaded and upstream
compiler flags are unchanged. The `CROSS` make variable selects that dependency's
executables explicitly.

The Intel Arm SDK compiler dynamically links to `zstd`, and its debugger needs
`xz`. The compiler formula declares both as Intel-only runtime dependencies;
firmware formulae also declare `zstd` as an Intel-only build dependency so forks
work with the existing upstream compiler formula. Installed firmware does not
need either library.

The current tap and upstream toolchain package are macOS-only. Linux support is
planned for future validation; this dependency does not establish Linux support.

### Migrating an existing combined package

The `proxmark3` alias preserves the installation name, not the old combined
package or its firmware configuration. There is no automatic formula rename
or one-to-many migration. Choose the new firmware package using your device
and the firmware options used for the old installation:

| Previous firmware configuration | New firmware package |
| --- | --- |
| RDV4 with default firmware options | `proxmark-firmware-rdv4` |
| Generic with no other firmware overrides | `proxmark-firmware-generic` |
| Extras, feature trimming, standalone or size overrides | `proxmark-firmware-custom`, with the corresponding firmware options |

Keep `--with-generic` when moving a customized Generic build to the custom
package. Options such as `--with-flash`, `--without-lf` and `--with-hf-mfcsim`
belong to `proxmark-firmware-custom`; they cannot be passed to the client or
through the `proxmark3` alias. The custom package's `--with-small` additionally
requires `--with-generic` and does not guarantee that firmware fits in 256 KiB.

For a first migration, unlink the old combined package before installing
either new client. This leaves its files available while you select and
install the replacement firmware:

```sh
if test -d "$(brew --cellar)/proxmark3" &&
   ! test -L "$(brew --cellar)/proxmark3" &&
   ! test -d "$(brew --cellar)/proxmark-client" &&
   ! test -d "$(brew --cellar)/proxmark-client-gui"; then
  brew unlink --formula proxmark3
fi
```

Once the new CLI client is installed, Homebrew's `opt/proxmark3` alias can
refer to it even while the old Cellar directory remains. Do not use the old
name to unlink or uninstall after migration. The first-time check above skips
installations where a new client already exists. For another old `proxmark3-*`
package, unlink its actual installed name before installing a new client.
Then install the canonical client and selected firmware names, for example,
for an RDV4 using default firmware options:

```sh
brew install proxmark-client proxmark-firmware-rdv4
```

Choose `proxmark-client-gui` instead if you need Qt windows, and use the
canonical client name for subsequent upgrades, switching and removal.

### Switching Arm toolchain taps

If `arm-none-eabi-gcc` is already installed from another tap, Homebrew may
refuse the same-named upstream package. When intentionally switching the compiler
used for source builds, uninstall that existing compiler and install the fully
qualified upstream dependency:

```sh
brew uninstall arm-none-eabi-gcc
brew install rfidresearchgroup/proxmark3/arm-none-eabi-gcc
```

Users installing prebuilt client/firmware bottles do not need the compiler.

## For maintainers

The default-branch CI checks tap syntax and CI helpers. Pull requests also
build and test changed formulae on the macOS matrix. In the upstream tap, an unbottled Arm compiler is
included in the same test-bot build before the dependent firmware. Forks use the
fully qualified upstream compiler; a runner-local bootstrap bottle stays outside
the artifacts uploaded by the fork. The retained compiler's version and Arm
archive checksums are unchanged by this package split.
