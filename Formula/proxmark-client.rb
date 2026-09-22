class ProxmarkClient < Formula
  desc "RRG/Iceman Proxmark3 command-line client and host tools"
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
  depends_on "readline"

  conflicts_with "proxmark-client-gui", because: "both install the Proxmark3 client and host tools"

  def install
    ENV.deparallelize

    args = %W[
      BREW_PREFIX=#{HOMEBREW_PREFIX}
      PLATFORM=PM3RDV4
      DONT_BUILD_NATIVE=y
      SKIPLUASYSTEM=1
      SKIPJANSSONSYSTEM=1
      SKIPWHEREAMISYSTEM=1
      SKIPQT=1
    ]

    system "make", "host/clean", *args
    system "make", "host/all", *args
    # Common resources include platform-independent smartcard upgrade images.
    # Device bootrom/fullimage/recovery images are built by the firmware formulae.
    system "make", "host/install", "common/install", "PREFIX=#{prefix}", *args
  end

  test do
    system bin/"proxmark3", "-h"
    output = shell_output("#{bin}/proxmark3 -c 'hw version; script run data_hex_crc -d 01020304 -w 16'")
    assert_match(/QT GUI support\.+ absent/, output)
    assert_match(%r{CRC-16/ARC\s+\| A10F}, output)

    assert_path_exists bin/"pm3-flash-all"
    assert_path_exists share/"proxmark3/tools/mfd_aes_brute"
    assert_path_exists share/"proxmark3/dictionaries/mfc_default_keys.dic"
    assert_path_exists share/"proxmark3/firmware/sim011.bin"
    refute_path_exists share/"proxmark3/firmware/bootrom.elf"
    refute_path_exists share/"proxmark3/firmware/fullimage.elf"
  end
end
