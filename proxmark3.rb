class Proxmark3 < Formula
  desc "RRG/Iceman Proxmark3 client, CDC flasher and firmware bundle"
  homepage "http://www.proxmark.org/"
  url "https://github.com/RfidResearchGroup/proxmark3/archive/v4.13441.tar.gz"
  sha256 "49c4f1854b364aa7ea7083581351f867128e71ea783d0ecd71fc41bcf7f63584"

  head do
    if ENV.has_key?('HOMEBREW_TRAVIS_COMMIT')
      url "https://github.com/RfidResearchGroup/proxmark3.git", :branch => "#{ENV['HOMEBREW_TRAVIS_BRANCH']}", :revision => "#{ENV['HOMEBREW_TRAVIS_COMMIT']}"
    else
      url "https://github.com/RfidResearchGroup/proxmark3.git"
    end
  end

  depends_on "readline"
  depends_on "pkg-config" => :build
  depends_on "qt5" => :recommended
  depends_on "./arm-none-eabi-gcc" => :build

  option "with-blueshark", "Enable Blueshark (BT Addon) support"
  option 'with-generic', 'Build for generic devices instead of RDV4'
  option 'with-small', 'Build for 256kB devices (HEAD only)'

  FUNCTIONS = %w[em4x50 felica hfplot hfsniff hitag iclass iso14443a iso14443b iso15693 legicrf lf nfcbarcode]
  STANDALONE = {
    'lf' => %w[em4100emul em4100rswb em4100rwc hidbrute icehid proxbrute samyrun skeleton tharexde],
    'hf' => %w[14asniff aveful bog craftbyte colin iceclass legic mattyrun tcprst tmudford young]
  }

  FUNCTIONS.each do |func|
    option "without-#{func}", "Build without #{func.upcase} functionality (HEAD only)"
  end

  option 'without-standalone', 'Build without standalone mode'

  STANDALONE.each do |freq, modes|
    modes.each do |mode|
      option "with-#{freq}-#{mode}", "Build with standalone mode #{freq.upcase}_#{mode.upcase}"
    end
  end

  def install
    ENV.deparallelize

    args = %W[
      BREW_PREFIX=#{HOMEBREW_PREFIX}
      PLATFORM=#{build.with?('generic') ? (build.head? ? 'PM3GENERIC' : 'PM3OTHER') : 'PM3RDV4'}
    ]

    args << 'PLATFORM_EXTRAS=BTADDON' if build.with? 'blueshark'
    args << 'PLATFORM_SIZE=256' if build.with? 'small'
    args << 'SKIPQT=1' unless build.with? 'qt5'

    if build.head?
      FUNCTIONS.each do |func|
        args << "SKIP_#{func.upcase}=1" unless build.with? func
      end
    end

    standalone = build.with?('standalone') ? nil : ''

    STANDALONE.each do |freq, modes|
      modes.each do |mode|
        if build.with? "#{freq}-#{mode}"
          odie 'Only one standalone mode may be selected' unless standalone.nil?
          standalone = "#{freq.upcase}_#{mode.upcase}"
        end
      end
    end

    args << "STANDALONE=#{standalone}" unless standalone.nil?

    system "make", "clean"
    system "make", "all", *args
    system "make", "install", "PREFIX=#{prefix}", *args

    ohai "Install success!"
    ohai "The latest bootloader and firmware binaries are ready and waiting in the current homebrew Cellar within share/firmware."
  end

  test do
    system "proxmark3", "-h"
  end
end
