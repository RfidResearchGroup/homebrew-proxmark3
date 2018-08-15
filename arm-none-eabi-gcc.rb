class ArmNoneEabiGcc < Formula
  desc "GCC for embedded ARM processors"
  homepage "https://launchpad.net/gcc-arm-embedded"
  url "https://launchpad.net/gcc-arm-embedded/5.0/5-2016-q3-update/+download/gcc-arm-none-eabi-5_4-2016q3-20160926-mac.tar.bz2"
  version "20160926"
  sha256 "5656cdec40f99d5c054a85bbc694276e1c4a1488cdacbbc448bc6acd3bbe070d"

  def install
    cp_r ["arm-none-eabi", "bin", "lib", "share"], "#{prefix}/"
  end
end
