class Clinfo < Formula
  desc "Print information about OpenCL platforms and devices"
  homepage "https://github.com/Oblomov/clinfo"
  url "https://github.com/Oblomov/clinfo/archive/2.1.17.02.09.tar.gz"
  sha256 "ae2b2ae0d287b1ec310844bbd3ae95f3cf8589dd356c736a6fe3133427df438d"

  bottle do
    cellar :any_skip_relocation
    sha256 "d9d4b007c3d33031ad4337037c7e517c547243cd7f6f486396f575132c6ba6d0" => :el_capitan
    sha256 "861f4c5da56d208b7a38ebb5dd7c4c21ca3240e16a0175dea3f8aec29150bbd4" => :yosemite
    sha256 "1c118487256f381b4b51168e062262c7ba31c09ae4fef06f73c0b44a7a3d508d" => :mavericks
  end

  def install
    system "make"
    bin.install "clinfo"
    man1.install "man/clinfo.1"
  end

  test do
    output = shell_output bin/"clinfo"
    assert_match /Device Type +CPU/, output
  end
end
