# Client/firmware split validation

Validated on 2026-09-21, macOS 27 arm64, Homebrew 7.0.4-39-gf00137e.
Proxmark source: `v4.23346`, SHA256
`5d727313d912d8d758365d3528fbf8af7463e5deec23a9bef79f1fab4fd0c66d`.
Upstream Makefiles, platform definitions and flashing scripts are not patched.
The recorded builds ran in a local development fork (`hxsf/proxmark`); the
commands below use the target upstream tap name for maintainers.

## Clients

The CLI and GUI formulae were built from source through Homebrew, using
`--skip-link` to preserve the machine's existing Proxmark installation.
The GUI used QtBase, QtImageFormats and QtSvg 6.11.2; the full `qt` formula was
not installed. Tests are run on the unlinked kegs with `brew test --force`.

The formula tests cover executable startup, the GUI presence/absence flag,
an installed Lua script calculating CRC-16/ARC, dictionaries, host tools and
platform-independent smartcard resources. The GUI additionally decodes WebP
and SVG NDEF images with Qt's offscreen platform. Strict linkage checks cover
both installed clients. Lua, Jansson and Whereami use the upstream vendored
implementations to avoid host-dependent opportunistic linkage.

```sh
brew install --build-from-source --skip-link rfidresearchgroup/proxmark3/proxmark-client rfidresearchgroup/proxmark3/proxmark-client-gui
brew test --force rfidresearchgroup/proxmark3/proxmark-client rfidresearchgroup/proxmark3/proxmark-client-gui
brew linkage --test --strict rfidresearchgroup/proxmark3/proxmark-client rfidresearchgroup/proxmark3/proxmark-client-gui
```

### Legacy client alias

`Aliases/proxmark3` points to `proxmark-client`; the old installation name
selects the CLI client without device firmware or firmware build options.
The compatibility change adds no `formula_renames.json` mapping. Existing
combined installations still require an explicit client/firmware migration.

Homebrew resolved the fully qualified alias in an isolated temporary tap to
the same formula and version as `proxmark-client`. Its dependencies contain
no Qt, firmware or Arm compiler, and it exposes no old firmware build options
or automatic rename metadata. Five shell fixtures verified that the README's
first-time unlink step runs only for an old real Cellar directory when neither
new client is installed. No installed package was unlinked or removed.

## Firmware

The firmware dependency is the upstream
`rfidresearchgroup/proxmark3/arm-none-eabi-gcc` package, version `13.3-2024.7`
(Arm GNU Toolchain 13.3.Rel1, GCC 13.3.1). It includes its matching binutils and
C library headers. The formulae do not download or stage separate newlib headers
and use only upstream's `CROSS` variable to select the declared toolchain.

The machine already had that SDK installed by the old `hxsf/proxmark` formula.
Both architectures' archive URLs and SHA256 values were checked against the
upstream RRG formula and match. This existing toolchain was preserved.
Homebrew source installations of the final firmware formulae, including launchers, used
`--ignore-dependencies --skip-link` to avoid replacing the same-name compiler
solely to change its tap attribution. Thus actual formula build/install/test
logic was exercised, but clean-machine dependency installation was not.

Upstream `recovery/all` and `recovery/install`, followed by the formula tests,
produced these results:

| Firmware | recovery.bin bytes | Build and installation |
| --- | ---: | --- |
| Generic | 439869 | Passed |
| RDV4 | 494897 | Passed |
| PM5 | 356916 | Passed |
| Ultimate | 404979 | Passed |
| Custom, default RDV4 | 494897 | Passed |

These installation checks confirmed `bootrom.elf`, `fullimage.elf` and
`recovery.bin` under each platform-specific directory. Tests check
ELF32/little-endian/ARM headers and nonempty recovery images within the 512 KiB
limit. The installation receipts record no runtime formula dependencies. The
compiler is build-only.

The custom formula's rejection paths were also checked: multiple platforms,
small without Generic, PM5-only extras on another platform, multiple standalone
modes, and a mode combined with `--without-standalone`.

### Firmware launchers

Each firmware package also provides three shell launchers in `bin`:
`pm3-flash-<name>-all`, `pm3-flash-<name>-bootrom` and
`pm3-flash-<name>-fullimage`, for `generic`, `rdv4`, `pm5`, `ultimate` and
`custom`. The package payload is three firmware files and three shell launchers;
it adds no compiler, headers or compiled host executable.

The launchers select the package's firmware directory and find the original
upstream helper on `PATH`, allowing either linked client variant without a
client runtime dependency. They check required ELF files, preserve arguments
and exit status, and leave device discovery and the flashing protocol to the
upstream helper. They do not verify the selected hardware or client/firmware
version match.

All five packages were rebuilt, installed and passed `brew test --force` with
the launchers. The tests substitute every helper and isolate `PATH`, covering
all fifteen commands with no arguments, help/list, device index/force and a port
argument containing spaces. They also verify working-directory selection,
relative `PATH` resolution, the helper's exit status, and the missing-client
installation hint. No real helper or hardware is invoked by these formula tests.

Additional checks ran against the installed scripts: POSIX shell syntax,
ShellCheck, firmware paths containing spaces, missing required images, and the
ability to flash one image without requiring the other. Missing-image fixtures
use copies of the installed scripts with only their firmware directory changed,
so the installed kegs are not damaged. ShellCheck excludes SC2043 because a
single-image mode intentionally generates a one-element loop.

Three integration checks execute the unchanged upstream helpers against a fake
`proxmark3` executable with an explicit dummy port. They confirm the original
helper receives the selected working directory, preserves its bootrom/all mode
and forwards its exit status; no device discovery or flashing occurs. As with
the upstream scripts, this check uses a space-free helper installation prefix.

The launchers check firmware before resolving the client, including for help or
list requests. A damaged package therefore reports its missing image first.

## CI checks

### Build CI

Formula style/audit and workflow syntax were checked. The existing Arm compiler
formula is retained in this tap; its version, both architecture URLs and SHA256
values match upstream. Its test compiles a C file using standard headers for
ARM7TDMI and Cortex-M4. Formula loading on Linux was checked without installing
macOS binaries; this does not establish Linux build support.

Offline fixtures verify the test-bot build lists for the owning upstream tap and
for forks. The upstream tap builds a missing compiler bottle in the same batch;
forks exclude their unused compiler mirror from installation tests and may use
a temporary local bottle for the upstream dependency. Homebrew's `file://`
bottle download/SHA256 handling and `bottled_or_built?` predicate were checked
separately. No runner-local compiler bottle is uploaded by the fork.

GitHub Actions run [35588164751](https://github.com/hxsf/homebrew-proxmark3/actions/runs/35588164751)
at `a4ece8f` passed all selected client/firmware builds and tests on `macos-15`
and `macos-26` (both arm64). On `macos-15-intel`, the clients were skipped because
their dependency graph lacked compatible bottles. All five firmware builds
failed when Arm's `cc1` could not load `/usr/local/opt/zstd/lib/libzstd.1.dylib`.

The Intel Arm SDK archive was downloaded and its SHA256 matched the formula.
Inspection of all 50 host Mach-O files found two external Homebrew libraries:
`libzstd.1.dylib` for the compiler executables and `liblzma.5.dylib` for GDB.
The installed arm64 SDK's 50 host Mach-O files linked only to system libraries.
Neither inspection ran the Intel executables.

The compiler now declares Intel-only runtime dependencies on `xz` and `zstd`;
the five firmware formulae also declare `zstd` as a build dependency for
compatibility with the existing upstream compiler formula used by forks.
Homebrew formula loading under simulated Intel and arm64 systems verified these
dependency scopes. The compiler test now also starts GDB to check its runtime
library loading. This does not establish that an Intel source build or bottle
build succeeds.

The bottle matrix requires only `macos-15` and
`macos-26` (arm64). Homebrew no longer builds new Intel dependency bottles, and
this tap does not maintain a separate build pipeline for that dependency graph.
Intel formula support remains available for best-effort source builds.

## Deferred and unverified cases

The upstream documented 256 KiB example was tested without changes using Arm's
13.3.Rel1 toolchain:

```sh
make -j4 recovery/all PLATFORM=PM3GENERIC PLATFORM_SIZE=256 STANDALONE= SKIP_HITAG=1 SKIP_FELICA=1
```

It fails the upstream size check: `355777 > 262144`. Upstream documents that the
example may need additional trimming as firmware grows. No additional `small`
preset or upstream feature changes were adopted.

An iCopy-X build was also investigated, but it requires a dedicated upstream
client configuration and is not included in the final package set.

No physical device was flashed. Qt image tests were offscreen, not a native
Cocoa interaction audit. Intel builds have not passed. Older macOS versions,
HEAD builds, complete custom-option combinations and release publication were
not validated.
