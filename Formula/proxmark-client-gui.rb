class ProxmarkClientGui < Formula
  desc "RRG/Iceman Proxmark3 client with Qt waveform and image windows"
  homepage "https://github.com/RfidResearchGroup/proxmark3"
  url "https://github.com/RfidResearchGroup/proxmark3/archive/refs/tags/v4.23346.tar.gz"
  sha256 "5d727313d912d8d758365d3528fbf8af7463e5deec23a9bef79f1fab4fd0c66d"
  license "GPL-3.0-or-later"
  head "https://github.com/RfidResearchGroup/proxmark3.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "pkgconf" => :build
  depends_on "coreutils"
  depends_on "gd"
  depends_on "lz4"
  depends_on :macos
  depends_on "openssl@3"
  depends_on "python@3.14"
  depends_on "qtbase"
  depends_on "qtimageformats"
  depends_on "qtsvg"
  depends_on "readline"

  conflicts_with "proxmark-client", because: "both install the Proxmark3 client and host tools"

  def install
    ENV.deparallelize

    args = %W[
      BREW_PREFIX=#{HOMEBREW_PREFIX}
      PLATFORM=PM3RDV4
      DONT_BUILD_NATIVE=y
      SKIPLUASYSTEM=1
      SKIPJANSSONSYSTEM=1
      SKIPWHEREAMISYSTEM=1
      FORCEQT=1
      FORCEQT6=1
    ]

    system "make", "host/clean", *args
    system "make", "host/all", *args
    # Common resources include platform-independent smartcard upgrade images.
    # Device bootrom/fullimage/recovery images are built by the firmware formulae.
    system "make", "host/install", "common/install", "PREFIX=#{prefix}", *args
  end

  test do
    ENV["QT_QPA_PLATFORM"] = "offscreen"
    system bin/"proxmark3", "-h"
    output = shell_output("#{bin}/proxmark3 -c 'hw version; script run data_hex_crc -d 01020304 -w 16'")
    assert_match(/QT GUI support\.+ present/, output)
    assert_match(%r{CRC-16/ARC\s+\| A10F}, output)

    assert_path_exists bin/"pm3-flash-all"
    assert_path_exists share/"proxmark3/tools/mfd_aes_brute"
    assert_path_exists share/"proxmark3/dictionaries/mfc_default_keys.dic"
    assert_path_exists share/"proxmark3/firmware/sim011.bin"
    refute_path_exists share/"proxmark3/firmware/bootrom.elf"
    refute_path_exists share/"proxmark3/firmware/fullimage.elf"

    # Exercise both optional image plugins through the offline NDEF decoder.
    webp = %w[
      52494646420000005745425056503820360000003002009d012a10001000020034258c027407
      e807f001991e5b0000fec143333ee0cc27fa9da0a6e57a4f614055eaf32ad596a2172000
    ].join
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">' \
          '<rect width="16" height="16"/></svg>'
    images = {
      "image/svg+xml" => svg,
      "image/webp"    => [webp].pack("H*"),
    }
    images.each do |type, image|
      record = [0xd2, type.bytesize, image.bytesize].pack("C*") + type + image
      output = shell_output("#{bin}/proxmark3 -c 'nfc decode -d #{record.unpack1("H*")}; msleep -t 100'")
      assert_match "IMAGE details", output
      refute_match(/Failed to decode|No GUI in this build/, output)
    end
  end
end
