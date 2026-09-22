class ProxmarkFirmwarePm5 < Formula
  desc "RRG/Iceman firmware for Proxmark5"
  homepage "https://github.com/RfidResearchGroup/proxmark3"
  url "https://github.com/RfidResearchGroup/proxmark3/archive/refs/tags/v4.23346.tar.gz"
  sha256 "5d727313d912d8d758365d3528fbf8af7463e5deec23a9bef79f1fab4fd0c66d"
  license "GPL-3.0-or-later"
  head "https://github.com/RfidResearchGroup/proxmark3.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rfidresearchgroup/proxmark3/arm-none-eabi-gcc" => :build
  depends_on :macos

  on_intel do
    # Required by the upstream Arm SDK until its formula declares this dependency.
    depends_on "zstd" => :build
  end

  def install
    args = %W[
      BREW_PREFIX=#{HOMEBREW_PREFIX}
      CROSS=#{formula_opt_bin("rfidresearchgroup/proxmark3/arm-none-eabi-gcc")}/arm-none-eabi-
      DONT_BUILD_NATIVE=y
      PLATFORM=PM5
      PREFIX=#{prefix}
      INSTALLFWRELPATH=share/proxmark3/firmware/pm5
    ]

    system "make", "recovery/all", *args
    system "make", "recovery/install", *args

    firmware = share/"proxmark3/firmware/pm5"
    bin.mkpath
    %w[all bootrom fullimage].each do |mode|
      images = (mode == "all") ? %w[bootrom.elf fullimage.elf] : ["#{mode}.elf"]
      wrapper = bin/"pm3-flash-pm5-#{mode}"
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
    firmware = opt_share/"proxmark3/firmware/pm5"
    <<~EOS
      Firmware for Proxmark5 is installed in:
        #{firmware}

      Install and link either proxmark-client or proxmark-client-gui separately.
      Use a client matching the firmware version. Device-specific launchers:
        pm3-flash-pm5-bootrom
        pm3-flash-pm5-fullimage
        pm3-flash-pm5-all
      These select this package's images and forward options to the upstream
      helper found on PATH. They do not select the connected device for you.

      recovery.bin is the combined image for JTAG recovery.
    EOS
  end

  test do
    firmware = share/"proxmark3/firmware/pm5"
    %w[bootrom.elf fullimage.elf].each do |name|
      image = firmware/name
      assert_path_exists image
      header = image.binread(20)
      assert_equal "\x7fELF".b, header.byteslice(0, 4)
      assert_equal 1, header.getbyte(4)
      assert_equal 1, header.getbyte(5)
      assert_equal 40, header.byteslice(18, 2).unpack1("v")
    end

    recovery = firmware/"recovery.bin"
    assert_path_exists recovery
    assert_operator recovery.size, :>, 0
    assert_operator recovery.size, :<=, 512 * 1024

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
      wrapper = bin/"pm3-flash-pm5-#{mode}"
      arguments.each do |args|
        output = shell_output([wrapper.to_s, *args].shelljoin, 37)
        assert_equal [mode, firmware.realpath.to_s, *args], output.lines.map(&:chomp)
      end
    end

    # Resolve a relative PATH entry before changing to the firmware directory.
    ENV["PATH"] = "helpers"
    output = shell_output("#{bin}/pm3-flash-pm5-all --list", 37)
    assert_equal ["all", firmware.realpath.to_s, "--list"], output.lines.map(&:chomp)

    ENV["PATH"] = (testpath/"no-client").to_s
    output = shell_output("#{bin}/pm3-flash-pm5-all 2>&1", 127)
    assert_match "Install and link either proxmark-client or proxmark-client-gui", output
  end
end
