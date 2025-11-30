class ArmNoneEabiGcc < Formula
  desc "GCC for embedded ARM processors"
  homepage 'https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads'
  version '13.3-2024.7'

  if Hardware::CPU.intel?
    url "https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-darwin-x86_64-arm-none-eabi.tar.xz"
    sha256 "1ab00742d1ed0926e6f227df39d767f8efab46f5250505c29cb81f548222d794"
  else
    url 'https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-darwin-arm64-arm-none-eabi.tar.xz'
    sha256 'fb6921db95d345dc7e5e487dd43b745e3a5b4d5c0c7ca4f707347148760317b4' 
  end

  def install
    (prefix/"gcc").install Dir["./*"]
    Dir.glob(prefix/"gcc/bin/*") { |file| bin.install_symlink file }
  end
end
