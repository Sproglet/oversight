#How to build oversight.

At present oversight is built using bash/make etc. I may port this to ant if this gives more flexibility.

To Build an environment:

  1. Windows only: Install cygwin
  1. Install gcc+make
  1. Install mips gcc toolchain
  1. build


## Cygwin ##

If using windows install [Cygwin](http://www.cygwin.com/). Most of my development is on cygwin. And some of the quick update scripts assume you are using cygwin drive mappings.
(Select the gcc and make packages in the installer)

## GCC + Make ##
Install Gcc + make if you haven't already.

## Mips Toolchain ##

Note if you want to publish releases you MUST isntall toolchains for both 100 and 200 series.

Download the mips toolchains from the following locations:
  * Windows cygwin
    * 100 series http://www.lundman.net/ftp/nmt/nmt-cygwin-toolchain-gcc-4.2.2-linux-2.6.15.7-uclibc-0.9.28.3.tar.bz2
    * 200 series http://www.codesourcery.com/downloads/public/public/gnu_toolchain/mips-linux-gnu/mips-4.3-154-mips-linux-gnu-i686-mingw32.tar.bz2
  * Linux
    * 100 series http://www.lundman.net/ftp/nmt/nmt-linux-intel-toolchain-gcc-4.0.4-linux-2.6.15.7-uclibc-0.9.28.3-lundman-P1.tgz
    * 200 series  http://www.codesourcery.com/downloads/public/public/gnu_toolchain/mips-linux-gnu/mips-4.3-154-mips-linux-gnu-i686-pc-linux-gnu.tar.bz2
  * Mac
    * 100 series http://www.lundman.net/ftp/nmt/nmt-OsX-intel-toolchain-gcc-4.0.4-linux-2.6.15.7-uclibc-0.9.28.3-lundman-P1.tgz
    * 200 series