class ArmNoneEabiGcc < Formula
  desc "GCC for embedded ARM processors"
  homepage "https://gitlab.arm.com/tooling/gnu-toolchains-for-arm"
  version "13.3-2024.7"
  license "GPL-3.0-or-later"
  revision 1

  livecheck do
    skip "Prebuilt Arm toolchain archive, updated manually"
  end

  depends_on :macos

  on_intel do
    # Arm's Intel debugger needs liblzma; the compiler needs libzstd.
    depends_on "xz"
    depends_on "zstd"
  end

  if Hardware::CPU.intel?
    url "https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-darwin-x86_64-arm-none-eabi.tar.xz"
    sha256 "1ab00742d1ed0926e6f227df39d767f8efab46f5250505c29cb81f548222d794"
  else
    url "https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-darwin-arm64-arm-none-eabi.tar.xz"
    sha256 "fb6921db95d345dc7e5e487dd43b745e3a5b4d5c0c7ca4f707347148760317b4"
  end

  def install
    (prefix/"gcc").install Dir["./*"]
    Dir.glob(prefix/"gcc/bin/*") { |file| bin.install_symlink file }
  end

  test do
    system bin/"arm-none-eabi-gdb", "--version"
    (testpath/"test.c").write <<~C
      #include <stdint.h>
      #include <string.h>
      uint32_t copy_word(uint32_t value) {
        uint32_t copy;
        memcpy(&copy, &value, sizeof(copy));
        return copy;
      }
    C
    %w[arm7tdmi cortex-m4].each do |cpu|
      system bin/"arm-none-eabi-gcc", "-mcpu=#{cpu}", "-mthumb", "-c", "test.c", "-o", "#{cpu}.o"
      assert_match "elf32-littlearm", shell_output("#{bin}/arm-none-eabi-objdump -f #{cpu}.o")
    end
  end
end
