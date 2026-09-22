class ProxmarkFirmwareCustom < Formula
  desc "RRG/Iceman Proxmark firmware with custom build options"
  homepage "https://github.com/RfidResearchGroup/proxmark3"
  url "https://github.com/RfidResearchGroup/proxmark3/archive/refs/tags/v4.23346.tar.gz"
  sha256 "5d727313d912d8d758365d3528fbf8af7463e5deec23a9bef79f1fab4fd0c66d"
  license "GPL-3.0-or-later"
  head "https://github.com/RfidResearchGroup/proxmark3.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  option "with-blueshark", "Enable Blueshark (BT Addon) support"
  option "with-smartcard", "Enable Smartcard support"
  option "with-flash", "Enable Flash support"
  option "with-generic", "Build for generic devices instead of RDV4"
  option "with-5", "Build for Proxmark 5 instead of RDV4"
  option "with-ultimate", "Build for Proxmark3 Ultimate instead of RDV4"
  option "with-bwm", "Enable Proxmark 5 BWM addon support"
  option "without-lowbatt-shutdown", "Disable Proxmark 5 low-battery shutdown"
  option "without-lowbatt-beep", "Disable Proxmark 5 low-battery beep and shutdown"
  option "with-small", "Build for generic 256kB devices (requires --with-generic)"
  option "without-standalone", "Build without standalone mode"

  depends_on "rfidresearchgroup/proxmark3/arm-none-eabi-gcc" => :build
  depends_on :macos

  on_intel do
    # Required by the upstream Arm SDK until its formula declares this dependency.
    depends_on "zstd" => :build
  end

  # Maps each --without-<name> option to the exact-case SKIP_* flag that
  # common_arm/Makefile.hal expects upstream (e.g. SKIP_EM4x50, not
  # SKIP_EM4X50).
  SKIPS = {
    "desfire-sim" => "SKIP_DESFIRE_SIM",
    "em4x50"      => "SKIP_EM4x50",
    "em4x70"      => "SKIP_EM4x70",
    "felica"      => "SKIP_FELICA",
    "hf"          => "SKIP_HF",
    "hfplot"      => "SKIP_HFPLOT",
    "hfsniff"     => "SKIP_HFSNIFF",
    "hitag"       => "SKIP_HITAG",
    "iclass"      => "SKIP_ICLASS",
    "iso14443a"   => "SKIP_ISO14443a",
    "iso14443b"   => "SKIP_ISO14443b",
    "iso15693"    => "SKIP_ISO15693",
    "legicrf"     => "SKIP_LEGICRF",
    "lf"          => "SKIP_LF",
    "nfcbarcode"  => "SKIP_NFCBARCODE",
    "seos"        => "SKIP_SEOS",
    "zx8211"      => "SKIP_ZX8211",
  }.freeze
  STANDALONE = {
    "lf" => %w[em4100emul em4100rswb em4100rsww em4100rwc hidbrute hidfcbrute icehid multihid nedap_sim nexid
               prox2brute proxbrute samyrun skeleton tharexde],
    "hf" => %w[14asniff 14bsniff 15sim 15sniff aveful bog cardhopper colin craftbyte doegox_auth0 doegox_commit
               emvpng iceclass legic legic_rdv4 legicsim mattyrun mfcsim msdsal reblay st25_tearoff tcprst
               tmudford unisniff young],
  }.freeze
  # Standalone modes without an LF_/HF_ prefix.
  STANDALONE_MISC = %w[dankarmulti].freeze

  SKIPS.each_key do |name|
    option "without-#{name}", "Build without #{name} functionality"
  end

  STANDALONE.each do |freq, modes|
    modes.each do |mode|
      option "with-#{freq}-#{mode}", "Build with standalone mode #{freq.upcase}_#{mode.upcase}"
    end
  end

  STANDALONE_MISC.each do |mode|
    option "with-#{mode}", "Build with standalone mode #{mode.upcase}"
  end

  def install
    ENV.deparallelize

    platforms = {
      "generic"  => "PM3GENERIC",
      "5"        => "PM5",
      "ultimate" => "PM3ULTIMATE",
    }
    selected_platforms = platforms.select { |option, _| build.with? option }
    odie "Only one platform may be selected" if selected_platforms.size > 1
    platform = selected_platforms.values.first || "PM3RDV4"

    if build.with?("small") && platform != "PM3GENERIC"
      odie "--with-small is only valid for generic 256kB devices (--with-generic)"
    end

    pm5_extras = []
    pm5_extras << "BWM" if build.with? "bwm"
    pm5_extras << "NO_LOWBATT_SHUTDOWN" if build.without? "lowbatt-shutdown"
    pm5_extras << "NO_LOWBATT_BEEP" if build.without? "lowbatt-beep"
    if platform != "PM5" && pm5_extras.any?
      odie "BWM and low-battery extras require a Proxmark 5 build (--with-5)"
    end

    args = %W[
      BREW_PREFIX=#{HOMEBREW_PREFIX}
      CROSS=#{formula_opt_bin("rfidresearchgroup/proxmark3/arm-none-eabi-gcc")}/arm-none-eabi-
      PLATFORM=#{platform}
      DONT_BUILD_NATIVE=y
    ]

    # Build PLATFORM_EXTRAS based on selected options
    platform_extras = []
    platform_extras << "BTADDON" if build.with? "blueshark"
    platform_extras << "SMARTCARD" if build.with? "smartcard"
    platform_extras << "FLASH" if build.with? "flash"
    platform_extras += pm5_extras

    args << "PLATFORM_EXTRAS=#{platform_extras.join(" ")}" unless platform_extras.empty?

    if build.with? "small"
      args += %w[
        PLATFORM_SIZE=256
        STANDALONE=
        SKIP_EM4x50=1
        SKIP_EM4x70=1
        SKIP_FELICA=1
        SKIP_HFPLOT=1
        SKIP_HFSNIFF=1
        SKIP_HITAG=1
        SKIP_ICLASS=1
        SKIP_LEGICRF=1
        SKIP_NFCBARCODE=1
        SKIP_ZX8211=1
      ]
    end

    SKIPS.each do |name, flag|
      args << "#{flag}=1" if build.without? name
    end

    selected = []
    STANDALONE.each do |freq, modes|
      modes.each do |mode|
        selected << "#{freq.upcase}_#{mode.upcase}" if build.with? "#{freq}-#{mode}"
      end
    end
    STANDALONE_MISC.each do |mode|
      selected << mode.upcase if build.with? mode
    end

    odie "Only one standalone mode may be selected" if selected.size > 1
    if build.without?("standalone") && selected.any?
      odie "--without-standalone conflicts with a standalone mode selection"
    end

    standalone = selected.first
    standalone = "" if build.without? "standalone"
    args << "STANDALONE=#{standalone}" unless standalone.nil?

    system "make", "recovery/all", *args
    system "make", "recovery/install", "PREFIX=#{prefix}",
                   "INSTALLFWRELPATH=share/proxmark3/firmware/custom", *args

    firmware = share/"proxmark3/firmware/custom"
    bin.mkpath
    %w[all bootrom fullimage].each do |mode|
      images = (mode == "all") ? %w[bootrom.elf fullimage.elf] : ["#{mode}.elf"]
      wrapper = bin/"pm3-flash-custom-#{mode}"
      wrapper.write <<~SH
        #!/bin/sh
        set -eu
        firmware_dir=#{firmware.to_s.shellescape}
        for image in #{images.join(" ")}; do
          if [ ! -f "$firmware_dir/$image" ] || [ ! -r "$firmware_dir/$image" ]; then
            printf 'Missing or unreadable firmware: %s\\n' "$firmware_dir/$image" >&2
            exit 1
          fi
        done
        helper=$(command -v pm3-flash-#{mode}) || {
          printf '%s\\n' 'pm3-flash-#{mode} was not found.' \\
            'Install and link either proxmark-client or proxmark-client-gui.' >&2
          exit 127
        }
        case "$helper" in
          /*) ;;
          *) helper="$PWD/$helper" ;;
        esac
        cd "$firmware_dir"
        exec "$helper" "$@"
      SH
      wrapper.chmod 0755
    end
  end

  def caveats
    firmware = opt_share/"proxmark3/firmware/custom"

    <<~EOS
      Firmware is installed in:
        #{firmware}

      Install and link either proxmark-client or proxmark-client-gui separately.
      Use a client matching the firmware version. Device-specific launchers:
        pm3-flash-custom-bootrom
        pm3-flash-custom-fullimage
        pm3-flash-custom-all
      These select this package's images and forward options to the upstream
      helper found on PATH. They do not select the connected device for you.

      --with-small retains the legacy trimming options and checks the 256KB
      limit. It may require additional --without-* options for current releases.
    EOS
  end

  test do
    firmware = share/"proxmark3/firmware/custom"
    %w[bootrom.elf fullimage.elf].each do |name|
      header = (firmware/name).binread(20)
      assert_equal "\x7FELF", header[0, 4]
      assert_equal 1, header.getbyte(4) # ELF32
      assert_equal 1, header.getbyte(5) # Little endian
      assert_equal 40, header[18, 2].unpack1("v") # ARM
    end
    assert_operator (firmware/"recovery.bin").size, :>, 0
    assert_operator (firmware/"recovery.bin").size, :<=, 512 * 1024

    # Substitute every helper so this test cannot discover or flash a device.
    helpers = testpath/"helpers"
    helpers.mkpath
    %w[all bootrom fullimage].each do |mode|
      helper = helpers/"pm3-flash-#{mode}"
      helper.write <<~SH
        #!/bin/sh
        printf '%s\\n' '#{mode}'
        pwd -P
        for arg do printf '%s\\n' "$arg"; done
        exit 37
      SH
      helper.chmod 0755
    end

    ENV["PATH"] = helpers.to_s
    arguments = [[], %w[--help], %w[--list], %w[-n 2 --force], ["-p", "/dev/port with spaces"]]
    %w[all bootrom fullimage].each do |mode|
      wrapper = bin/"pm3-flash-custom-#{mode}"
      arguments.each do |args|
        output = shell_output([wrapper.to_s, *args].shelljoin, 37)
        assert_equal [mode, firmware.realpath.to_s, *args], output.lines.map(&:chomp)
      end
    end

    # Resolve a relative PATH entry before changing to the firmware directory.
    ENV["PATH"] = "helpers"
    output = shell_output("#{bin}/pm3-flash-custom-all --list", 37)
    assert_equal ["all", firmware.realpath.to_s, "--list"], output.lines.map(&:chomp)

    ENV["PATH"] = (testpath/"no-client").to_s
    output = shell_output("#{bin}/pm3-flash-custom-all 2>&1", 127)
    assert_match "Install and link either proxmark-client or proxmark-client-gui", output
  end
end
