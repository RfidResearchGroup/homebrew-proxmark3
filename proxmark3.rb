class Proxmark3 < Formula
  desc "RRG/Iceman Proxmark3 client, CDC flasher and firmware bundle"
  homepage "http://www.proxmark.org/"
#  url "https://github.com/RfidResearchGroup/proxmark3/archive/xxxx.tar.gz"
#  sha256 "bc19f98c661304db5a79e07b44b2f16ef5229b490985dc1d87e6f494a6729558"
  head do
    puts "env variable TRAVIS_COMMIT: `#{ENV['HOMEBREW_TRAVIS_COMMIT']}`"
    if ENV.has_key?('HOMEBREW_TRAVIS_COMMIT')
      url "https://github.com/RfidResearchGroup/proxmark3.git", :branch => "#{ENV['HOMEBREW_TRAVIS_BRANCH']}", :revision => "#{ENV['HOMEBREW_TRAVIS_COMMIT']}"
    else
      url "https://github.com/RfidResearchGroup/proxmark3.git"
    end
  end
  
  depends_on "automake" => :build
  depends_on "readline"
  depends_on "p7zip" => :build
  depends_on "libusb"
  depends_on "libusb-compat"
  depends_on "pkg-config" => :build
  depends_on "wget"
  depends_on "qt5"
  depends_on "perl"
  depends_on "RfidResearchGroup/proxmark3/arm-none-eabi-gcc" => :build

  option "with-blueshark", "Enable Blueshark (BT Addon) support"

  def install
    ENV.deparallelize

    system "make", "clean"	  
    if build.with? "blueshark"
      system "make", "all", "PLATFORM_EXTRAS=BTADDON"
    else
      system "make", "all"
    end

    bin.mkpath
    bin.install "client/flasher" => "proxmark3-flasher"
    bin.install "client/proxmark3" => "proxmark3"
#   bin.install "client/fpga_compress" => "fpga_compress"
#	bin.install "tools/mfkey/mfkey32" => "mfkey32"
#	bin.install "tools/mfkey/mfkey64" => "mfkey64"

    # default keys
    bin.install "client/default_keys.dic" => "default_keys.dic"
    bin.install "client/default_pwd.dic" => "default_pwd.dic"
    if File.exist?("client/default_iclass_keys.dic") then
        bin.install "client/default_iclass_keys.dic" => "default_iclass_keys.dic"
    end

    # hardnested files
    (bin/"hardnested").mkpath
    (bin/"hardnested").install "client/hardnested/bf_bench_data.bin"
    (bin/"hardnested/tables").install Dir["client/hardnested/tables/*"]	

    # lua libs for proxmark3 scripts
    (bin/"lualibs").mkpath
    (bin/"lualibs").install Dir["client/lualibs/*"]

    # lua scripts
    (bin/"scripts").mkpath
    (bin/"scripts").install Dir["client/scripts/*"]

    # trace files for experimentations
    (bin/"traces").mkpath
    (bin/"traces").install Dir["traces/*"]

    # emv public keys file
    if File.exist?("client/emv/capk.txt") then
        (bin/"emv").mkpath
        (bin/"emv").install "client/emv/capk.txt"
    end

    # compiled firmware for flashing
    share.mkpath	
    (share/"firmware").mkpath
    (share/"firmware").install "armsrc/obj/fullimage.elf" => "fullimage.elf"
    (share/"firmware").install "bootrom/obj/bootrom.elf" => "bootrom.elf"
    ohai "Install success!  Only proxmark3-flashern is available."
    ohai "The latest bootloader and firmware binaries are ready and waiting in the current homebrew Cellar within share/firmware."
  end

  test do
    system "proxmark3", "-h"
  end
end
