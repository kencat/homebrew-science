class Mumps < Formula
  desc "Parallel Sparse Direct Solver"
  homepage "http://mumps-solver.org"
  url "http://mumps.enseeiht.fr/MUMPS_5.1.1.tar.gz"
  mirror "http://graal.ens-lyon.fr/MUMPS/MUMPS_5.1.1.tar.gz"
  sha256 "a2a1f89c470f2b66e9982953cbd047d429a002fab9975400cef7190d01084a06"
  revision 1

  bottle :disable, "needs to be rebuilt with latest open-mpi"

  deprecated_option "without-mpi" => "without-open-mpi"

  depends_on "open-mpi" => :recommended
  depends_on "openblas" => OS.mac? ? :optional : :recommended
  depends_on "veclibfort" if build.without?("openblas") && OS.mac?
  depends_on "gcc" if OS.mac? # for gfortran

  if build.with? "open-mpi"
    if OS.mac?
      depends_on "scalapack" => build.with?("openblas") ? ["with-openblas"] : []
    else
      depends_on "scalapack" => build.without?("openblas") ? ["without-openblas"] : []
    end
  end
  depends_on "metis"    => :optional if build.without? "open-mpi"
  depends_on "parmetis" => :optional if build.with? "open-mpi"
  depends_on "scotch5"  => :optional
  depends_on "scotch"   => :optional

  resource "mumps_simple" do
    url "https://github.com/dpo/mumps_simple/archive/v0.4.tar.gz"
    sha256 "87d1fc87eb04cfa1cba0ca0a18f051b348a93b0b2c2e97279b23994664ee437e"
  end

  def install
    make_args = ["RANLIB=echo"]
    if OS.mac?
      # Building dylibs with mpif90 causes segfaults on 10.8 and 10.10. Use gfortran.
      shlibs_args = ["LIBEXT=.dylib",
                     "AR=#{ENV["FC"]} -dynamiclib -Wl,-install_name -Wl,#{lib}/$(notdir $@) -undefined dynamic_lookup -o "]
    else
      shlibs_args = ["LIBEXT=.so",
                     "AR=$(FL) -shared -Wl,-soname -Wl,$(notdir $@) -o "]
    end
    make_args += ["OPTF=-O", "CDEFS=-DAdd_"]
    orderingsf = "-Dpord"

    makefile = (build.with? "open-mpi") ? "Makefile.G95.PAR" : "Makefile.G95.SEQ"
    cp "Make.inc/" + makefile, "Makefile.inc"

    if build.with? "scotch5"
      make_args += ["SCOTCHDIR=#{Formula["scotch5"].opt_prefix}",
                    "ISCOTCH=-I#{Formula["scotch5"].opt_include}"]

      if build.with? "open-mpi"
        scotch_libs = "LSCOTCH=-L$(SCOTCHDIR)/lib -lptesmumps -lptscotch -lptscotcherr"
        scotch_libs += " -lptscotchparmetis" if build.with? "parmetis"
        make_args << scotch_libs
        orderingsf << " -Dptscotch"
      else
        scotch_libs = "LSCOTCH=-L$(SCOTCHDIR) -lesmumps -lscotch -lscotcherr"
        scotch_libs += " -lscotchmetis" if build.with? "metis"
        make_args << scotch_libs
        orderingsf << " -Dscotch"
      end
    elsif build.with? "scotch"
      make_args += ["SCOTCHDIR=#{Formula["scotch"].opt_prefix}",
                    "ISCOTCH=-I#{Formula["scotch"].opt_include}"]

      if build.with? "open-mpi"
        scotch_libs = "LSCOTCH=-L$(SCOTCHDIR)/lib -lptscotch -lptscotcherr -lptscotcherrexit -lscotch"
        scotch_libs += "-lptscotchparmetis" if build.with? "parmetis"
        make_args << scotch_libs
        orderingsf << " -Dptscotch"
      else
        scotch_libs = "LSCOTCH=-L$(SCOTCHDIR) -lscotch -lscotcherr -lscotcherrexit"
        scotch_libs += "-lscotchmetis" if build.with? "metis"
        make_args << scotch_libs
        orderingsf << " -Dscotch"
      end
    end

    if build.with? "parmetis"
      make_args += ["LMETISDIR=#{Formula["parmetis"].opt_lib}",
                    "IMETIS=#{Formula["parmetis"].opt_include}",
                    "LMETIS=-L#{Formula["parmetis"].opt_lib} -lparmetis -L#{Formula["metis"].opt_lib} -lmetis"]
      orderingsf << " -Dparmetis"
    elsif build.with? "metis"
      make_args += ["LMETISDIR=#{Formula["metis"].opt_lib}",
                    "IMETIS=#{Formula["metis"].opt_include}",
                    "LMETIS=-L#{Formula["metis"].opt_lib} -lmetis"]
      orderingsf << " -Dmetis"
    end

    make_args << "ORDERINGSF=#{orderingsf}"

    if build.with? "open-mpi"
      make_args += ["CC=#{ENV["MPICC"]} -fPIC",
                    "FC=#{ENV["MPIFC"]} -fPIC",
                    "FL=#{ENV["MPIFC"]} -fPIC",
                    "SCALAP=-L#{Formula["scalapack"].opt_lib} -lscalapack",
                    "INCPAR=", # Let MPI compilers fill in the blanks.
                    "LIBPAR=$(SCALAP)"]
    else
      make_args += ["CC=#{ENV["CC"]} -fPIC",
                    "FC=#{ENV["FC"]} -fPIC",
                    "FL=#{ENV["FC"]} -fPIC"]
    end

    if build.with? "openblas"
      make_args << "LIBBLAS=-L#{Formula["openblas"].opt_lib} -lopenblas"
    elsif build.with? "veclibfort"
      make_args << "LIBBLAS=-L#{Formula["veclibfort"].opt_lib} -lvecLibFort"
    else
      make_args << "LIBBLAS=-lblas -llapack"
    end

    ENV.deparallelize # Build fails in parallel on Mavericks.

    system "make", "alllib", *(shlibs_args + make_args)

    lib.install Dir["lib/*"]
    lib.install ("libseq/libmpiseq" + (OS.mac? ? ".dylib" : ".so")) if build.without? "open-mpi"

    # Build static libraries (e.g., for Dolfin)
    system "make", "alllib", *make_args
    (libexec/"lib").install Dir["lib/*.a"]
    (libexec/"lib").install "libseq/libmpiseq.a" if build.without? "open-mpi"

    inreplace "examples/Makefile" do |s|
      s.change_make_var! "libdir", lib
    end

    libexec.install "include"
    include.install_symlink Dir[libexec/"include/*"]
    # The following .h files may conflict with others related to MPI
    # in /usr/local/include. Do not symlink them.
    (libexec/"include").install Dir["libseq/*.h"] if build.without? "open-mpi"

    doc.install Dir["doc/*.pdf"]
    pkgshare.install "examples"

    prefix.install "Makefile.inc"  # For the record.
    File.open(prefix/"make_args.txt", "w") do |f|
      f.puts(make_args.join(" "))  # Record options passed to make.
    end

    if build.with? "open-mpi"
      resource("mumps_simple").stage do
        simple_args = ["CC=#{ENV["MPICC"]}", "prefix=#{prefix}", "mumps_prefix=#{prefix}",
                       "scalapack_libdir=#{Formula["scalapack"].opt_lib}"]
        if build.with? "scotch5"
          simple_args += ["scotch_libdir=#{Formula["scotch5"].opt_lib}",
                          "scotch_libs=-L$(scotch_libdir) -lptesmumps -lptscotch -lptscotcherr"]
        elsif build.with? "scotch"
          simple_args += ["scotch_libdir=#{Formula["scotch"].opt_lib}",
                          "scotch_libs=-L$(scotch_libdir) -lptscotch -lptscotcherr -lscotch"]
        end
        if build.with? "openblas"
          simple_args += ["blas_libdir=#{Formula["openblas"].opt_lib}",
                          "blas_libs=-L$(blas_libdir) -lopenblas"]
        end
        system "make", "SHELL=/bin/bash", *simple_args
        lib.install ("libmumps_simple." + (OS.mac? ? "dylib" : "so"))
        include.install "mumps_simple.h"
      end
    end
  end

  def caveats
    s = <<~EOS
      MUMPS was built with shared libraries. If required,
      static libraries are available in
        #{opt_libexec}/lib
    EOS
    if build.without? "open-mpi"
      s += <<~EOS
      You built a sequential MUMPS library.
      Please add #{libexec}/include to the include path
      when building software that depends on MUMPS.
      EOS
    end
    s
  end

  test do
    ENV.fortran
    cp_r pkgshare/"examples", testpath
    opts = ["-I#{opt_include}", "-L#{opt_lib}", "-lmumps_common", "-lpord"]
    if Tab.for_name("mumps").with? "openblas"
      opts << "-L#{Formula["openblas"].opt_lib}" << "-lopenblas"
    elsif OS.mac?
      opts << "-L#{Formula["veclibfort"].opt_lib}" << "-lvecLibFort"
    else
      opts << "-lblas" << "-llapack"
    end
    if Tab.for_name("mumps").with?("open-mpi")
      f90 = "mpif90"
      cc = "mpicc"
      mpirun = "mpirun -np 2"
      opts << "-lscalapack"
    else
      f90 = ENV["FC"]
      cc = ENV["CC"]
      mpirun = ""
    end

    cd testpath/"examples" do
      system f90, "-o", "ssimpletest", "ssimpletest.F", "-lsmumps", *opts
      system "#{mpirun} ./ssimpletest < input_simpletest_real"
      system f90, "-o", "dsimpletest", "dsimpletest.F", "-ldmumps", *opts
      system "#{mpirun} ./dsimpletest < input_simpletest_real"
      system f90, "-o", "csimpletest", "csimpletest.F", "-lcmumps", *opts
      system "#{mpirun} ./csimpletest < input_simpletest_cmplx"
      system f90, "-o", "zsimpletest", "zsimpletest.F", "-lzmumps", *opts
      system "#{mpirun} ./zsimpletest < input_simpletest_cmplx"
      system cc, "-c", "c_example.c", "-I#{opt_include}"
      system f90, "-o", "c_example", "c_example.o", "-ldmumps", *opts
      system *(mpirun.split + ["./c_example"] + opts)
    end
  end
end
