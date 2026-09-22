class Proxmark3 < Formula
  desc "RRG/Iceman Proxmark3 client, CDC flasher and firmware bundle"
  homepage "http://www.proxmark.org/"
  url "https://github.com/RfidResearchGroup/proxmark3/archive/refs/tags/v4.23346.tar.gz"
  sha256 "5d727313d912d8d758365d3528fbf8af7463e5deec23a9bef79f1fab4fd0c66d"
  head do
    if ENV.key?("HOMEBREW_TRAVIS_COMMIT")
      url "https://github.com/RfidResearchGroup/proxmark3.git", branch: ENV["HOMEBREW_TRAVIS_BRANCH"].to_s, revision: ENV["HOMEBREW_TRAVIS_COMMIT"].to_s
    else
      url "https://github.com/RfidResearchGroup/proxmark3.git"
    end
  end

  option "with-blueshark", "Enable Blueshark (BT Addon) support"
  option "with-smartcard", "Enable Smartcard support"
  option "with-flash", "Enable Flash support"
  option "with-generic", "Build for generic devices instead of RDV4"
  option "with-small", "Build for 256kB devices"
  option "without-standalone", "Build without standalone mode"

  depends_on "lua" => :build

  depends_on "openssl@3" => :build

  depends_on "pkg-config" => :build

  depends_on "python@3.14" => :build
  depends_on "rfidresearchgroup/proxmark3/arm-none-eabi-gcc" => :build
  depends_on "coreutils"
  depends_on "readline"
  depends_on "gd" => :recommended
  depends_on "openssl" => :recommended
  depends_on "qt@5" => :recommended

  # Maps each --without-<name> option to the exact-case SKIP_* flag that
  # common_arm/Makefile.hal expects upstream (e.g. SKIP_EM4x50, not
  # SKIP_EM4X50).
  SKIPS = {
    "desfire-sim" => "SKIP_DESFIRE_SIM",
    "em4x50"      => "SKIP_EM4x50",
    "em4x70"      => "SKIP_EM4x70",
    "felica"      => "SKIP_FELICA",
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

    args = %W[
      BREW_PREFIX=#{HOMEBREW_PREFIX}
      PLATFORM=#{build.with?("generic") ? "PM3GENERIC" : "PM3RDV4"}
    ]

    # Build PLATFORM_EXTRAS based on selected options
    platform_extras = []
    platform_extras << "BTADDON" if build.with? "blueshark"
    platform_extras << "SMARTCARD" if build.with? "smartcard"
    platform_extras << "FLASH" if build.with? "flash"

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

    args << "SKIPQT=1" if build.without? "qt5"

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

    args << "-j"

    system "make", "clean", *args
    system "make", "all", *args
    system "make", "install", "PREFIX=#{prefix}", *args

    ohai "Install success!"
    ohai "The latest bootloader and firmware binaries are in share/firmware within the Homebrew Cellar."
  end

  test do
    system "proxmark3", "-h"
  end
end
