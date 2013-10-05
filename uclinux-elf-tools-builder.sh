#!/bin/sh
#
# This script builds the m68k-elf- or arm-elf- toolchain for use
# with uClinux.  It can be used to build for almost any architecture
# without too much change.
#
# Before running you will need to obtain (if you don't have them in this
# directory):
#
#    binutils-2.14.tar.bz2         in current directory (or a gzipped version)
#    gcc-2.95.3.tar.bz2            in current directory (or a gzipped version)
#    gcc-2.95.3-full.patch         in current directory
#    gcc-2.95.3-arm-pic.patch      in current directory
#    gcc-2.95.3-arm-pic.patch2     in current directory
#    gcc-2.95.3-arm-mlib.patch     in current directory
#    gcc-2.95.3-sigset.patch       in current directory
#    gcc-2.95.3-m68k-zext.patch    in current directory
#    gcc-makeinfo-strcpy-overlap.patch  in current directory
#    genromfs-0.5.1.tar.gz         in current directory, romfs.sourceforge.net
#    STLport-4.5.3.tar.gz          in current directory
#    STLport-4.5.3.patch           in current directory
#
# You will also need
#
#    a current elf2flt tree from cvs.uclinux.org
#    the uClibc-20030314.tar.gz included with the tools sources (extract it)
#    a current uClinux kernel (2.0/2.4) from cvs.uclinux.org
#    to change the EDIT section below appropriately
#
# You can link the uClibc and uClinux-2.0.x or uClinux-2.4.x dirs into the
# current directory or change the values below.
#
# This script:
#
# DOES build all the gcc tools/libraries
#
# DOES build target specific versions of libc
#
# Unless you modify PREFIX below, you will need to be root to run this
# script correctly.
#
# To build everything run "./uclinux-elf-tools-builder.sh build 2>&1 | tee errs"
#
# Copyright (C) 2001-2003 David McCullough <davidm@snapgear.com>
#
# Cygwin changes from Heiko Degenhardt <linux@sentec-elektronik.de>
#     I've modified that script to build the toolchain under Cygwin.
#     My changes are based on the information I found at
#     http://fiddes.net/coldfire/ # (thanks to David J. Fiddes) and the
#     very good introduction at
#     http://www.uclinux.org/pub/uClinux/archive/8306.html (thanks to
#     Paul M. Banasik (PaulMBanasik@eaton.com).
#
#############################################################
#
# our build starts here
#

set -x	# debug script

BASEDIR="`pwd`"

SCRIPT_NAME=uclinux-elf-tools-builder.sh

abort() {
    echo ${SCRIPT_NAME}: $@
    exec false
}

test -z "${PREFIX}"           && abort "Please set PREFIX to where you want the toolchain installed."
test -z "${BUILD_DIR}"        && abort "Please set BUILD_DIR to the directory where the tools are to be built"
test -z "${SRC_DIR}"          && abort "Please set SRC_DIR to the directory where the source tarballs are to be unpacked"
test -z "${TARBALLS_DIR}"     && abort "Please set TARBALLS_DIR to the directory where the source tarballs are stored"

test -z "${BINUTILS_DIR}"     && abort "Please set BINUTILS_DIR to the bare filename of the binutils tarball or directory"
test -z "${GCC_DIR}"          && abort "Please set GCC_DIR to the bare filename of the gcc tarball or directory"
test -z "${UCLIBC_DIR}"       && abort "Please set UCLIBC_DIR to the bare filename of the uClibc tarball or directory"

test -z "${TARGET}"           && abort "Please set TARGET to the Gnu target identifier (e.g. pentium-linux)"
test -z "${TARGET_CFLAGS}"    && abort "Please set TARGET_CFLAGS to any compiler flags needed when building glibc (-O recommended)"
test -z "${LINUX_DIR}"        && abort "Please set LINUX_DIR to the bare filename of the tarball or directory containing the kernel headers"

test -z "${ELF2FLT_DIR}"       && abort "Please set ELF2FLT_DIR to the bare filename of the elf2flt tarball or directory"
test -z "${STLPORT_DIR}"       && abort "Please set STLPORT_DIR to the bare filename of the STLport tarball or directory"

test -z "${KERNELCONFIG}"      && abort "Please set KERNELCONFIG to the path to kernel configuration file"
test -z "${UCLIBCCONFIG}"      && abort "Please set UCLIBCCONFIG to the path to uClibc configuration file"

test -r "${KERNELCONFIG}"  || abort  "Can't read file KERNELCONFIG = $KERNELCONFIG, please fix."
test -r "${UCLIBCCONFIG}"  || abort  "Can't read file UCLIBCCONFIG = $UCLIBCCONFIG, please fix."

test -d "${PREFIX}"        || abort "PREFIX = $PREFIX must be a directory"
test -w "${PREFIX}"        || abort "PREFIX = $PREFIX must be writable"
PREFIX_FILECOUNT=`ls -A ${PREFIX} | wc -l`
test "${PREFIX_FILECOUNT}" -eq '0' || abort "PREFIX = $PREFIX must be empty"

TOP_DIR=${TOP_DIR-`pwd`}
#############################################################
#
# EDIT these to suit your system and source locations
#

MAKE=make
PATCH=patch
##ELF2FLT="$BASEDIR/${ELF2FLT_DIR}"
##UCLIBC="$BASEDIR/${UCLIBC_DIR}"
##KERNEL="$BASEDIR/${LINUX_DIR}"
# KERNEL="$BASEDIR/uClinux-2.0.x"

# TARGET=m68k-elf
# TARGET=arm-elf

# set your install directory here and add the correct PATH

# uncomment the following line to build for Cygwin
# you may also need to include your PATCH path specifically
# CYGWIN=cygwin-
# PATCH=/usr/bin/patch

#############################################################
#
# Don't edit these
#

PATH="${PREFIX}/bin:$PATH"; export PATH
LANG=C

sysinclude=include

UMASK_PREV=`umask`
if [ ${UMASK_PREV} != '0022' ] ; then
  umask 0022
fi

if [ -z "${HOSTCC_COMMAND}" ] ; then
  HOSTCC_COMMAND=gcc
fi

#############################################################
#
# mark stage done
#

mark()
{
	echo "STAGE $1 - complete"
	touch "${BUILD_DIR}/STAGE$1-m.txt"

	if [ -d ${PREFIX} ] ; then
          local letter=b
	  find ${PREFIX} -type f >> ${BUILD_DIR}/STAGE$1-tmp-files.txt
	  find ${PREFIX} -type l >> ${BUILD_DIR}/STAGE$1-tmp-links.txt
	  > ${BUILD_DIR}/STAGE$1-${letter}-prefix.txt
	  cat ${BUILD_DIR}/STAGE$1-tmp-files.txt | LANG=C sort \
	    | sed "s,${PREFIX},PREFIX," >> ${BUILD_DIR}/STAGE$1-${letter}-prefix.txt
	  cat ${BUILD_DIR}/STAGE$1-tmp-links.txt | LANG=C sort \
	    | sed "s,${PREFIX},PREFIX," >> ${BUILD_DIR}/STAGE$1-${letter}-prefix.txt
	  cat ${BUILD_DIR}/STAGE$1-tmp-files.txt | LANG=C sort \
	    | xargs --no-run-if-empty -n 1 md5sum -b  \
	    | sed "s,${PREFIX},PREFIX," >> ${BUILD_DIR}/STAGE$1-${letter}-md5sums.txt
	  rm -f ${BUILD_DIR}/STAGE$1-tmp-files.txt
	  rm -f ${BUILD_DIR}/STAGE$1-tmp-links.txt
	fi
}

#
# check if stage should be built
#

schk()
{
	echo "--------------------------------------------------------"
	[ -f "${BUILD_DIR}/STAGE$1-m.txt" ] && echo "STAGE $1 - already built" && return 1
	echo "STAGE $1 - needs building"

	if [ -d ${PREFIX} ] ; then
          local letter=a
	  find ${PREFIX} -type f >> ${BUILD_DIR}/STAGE$1-tmp-files.txt
	  find ${PREFIX} -type l >> ${BUILD_DIR}/STAGE$1-tmp-links.txt
	  > ${BUILD_DIR}/STAGE$1-${letter}-prefix.txt
	  cat ${BUILD_DIR}/STAGE$1-tmp-files.txt | LANG=C sort \
	    | sed "s,${PREFIX},PREFIX," >> ${BUILD_DIR}/STAGE$1-${letter}-prefix.txt
	  cat ${BUILD_DIR}/STAGE$1-tmp-links.txt | LANG=C sort \
	    | sed "s,${PREFIX},PREFIX," >> ${BUILD_DIR}/STAGE$1-${letter}-prefix.txt
	  cat ${BUILD_DIR}/STAGE$1-tmp-files.txt | LANG=C sort \
	    | xargs --no-run-if-empty -n 1 md5sum -b  \
	    | sed "s,${PREFIX},PREFIX," >> ${BUILD_DIR}/STAGE$1-${letter}-md5sums.txt
	  rm -f ${BUILD_DIR}/STAGE$1-tmp-files.txt
	  rm -f ${BUILD_DIR}/STAGE$1-tmp-links.txt
	fi

	return 0
}

#
# extract most XYZ format files
#

function extract_tarball()
{
   local tarballs_dir=${TARBALLS_DIR}
   local src_dir=${1}
   local basename=${2}
   local orig_dir=`pwd`
   local tar_done=0
   if [ -n "${basename}" ] ; then
       ( cd ${src_dir} && rm -rf ${basename} )
   fi
   for fff in ${tarballs_dir}/${basename}.tar* ; do
      if [ -f ${fff} -a -r ${fff} ] ; then
         (
            cd ${src_dir} && tar -xf ${fff}
         )
         tar_done=1
         break
      fi
   done
   test ${tar_done} -eq 1 || abort "No tarfile to extract, ${tarballs_dir}, ${src_dir}, ${basename}  "
   cd ${orig_dir}
}

function patch_sources()
{
   local src_dir=${1}
   local basename=${2}
   # Pattern in a patch log to indicate failure
   local patchfailmsgs="^No file to patch.  Skipping patch.|^Hunk .* FAILED at"
   local orig_dir=`pwd`
   if [ -d ${TOP_DIR}/patches/${basename} ] ; then
      cd ${src_dir}/${basename}
      for ppp in ${TOP_DIR}/patches/${basename}/*.patch ${TOP_DIR}/patches/${basename}/*.diff ; do
         if test -f ${ppp} ; then
            patch -g0 --fuzz=1 -p1 -f --input=${ppp} > patch$$.log 2>&1 || { cat patch$$.log ; abort "${SCRIPT_NAME}: patch $p failed" ; }
            cat patch$$.log
            egrep -q "${patchfailmsgs}" patch$$.log && abort "${SCRIPT_NAME}: patch $p failed"
            rm -f patch$$.log
         fi
      done
   fi
   cd ${orig_dir}
}

function patch_kernel_uclinux()
{
   local tarballs_dir=${TARBALLS_DIR}
   local src_dir=${1}
   local kernel_basename=${2}
   local ucpatch_basename=${3}
   local orig_dir=`pwd`
   # Pattern in a patch log to indicate failure
   local patchfailmsgs="^No file to patch.  Skipping patch.|^Hunk .* FAILED at"
   for ppp in ${ucpatch_basename}.patch.gz ${ucpatch_basename}.diff.gz ] ; do
      if [ -f ${tarballs_dir}/${ppp} ] ; then
	  cd ${src_dir}/${kernel_basename}
	  zcat ${tarballs_dir}/${ppp} | patch -g0 --fuzz=1 -p1 -f > patch$$.log 2>&1 || { cat patch$$.log ; abort "${SCRIPT_NAME}: patch $p failed" ; }
	  cat patch$$.log
	  egrep -q "${patchfailmsgs}" patch$$.log && abort "${SCRIPT_NAME}: patch $p failed"
	  rm -f patch$$.log
      fi
   done
   cd ${orig_dir}
}

#############################################################
#
# clean any previous runs, extract some stuff
#

stage1()
{

 	schk 1 || return 0
# 
# 	rm -rf binutils-2.14
# 	rm -rf gcc-2.95.3
# 	rm -rf STLport-4.5.3
# 	rm -rf ${PREFIX}/${TARGET}
# 	rm -rf ${PREFIX}/lib/gcc-lib/${TARGET}
# 	rm -rf ${PREFIX}/bin/${TARGET}*
# 	rm -rf ${PREFIX}/man/*/${TARGET}-*
# #
# #	extract binutils, gcc and anything else we know about
# #
# 	extract binutils-2.14.*
# 	extract gcc-2.95.3.*
# 	extract STLport-4.5.3.tar.gz
# #
# #	apply any patches
# #
# 
# 	${PATCH} -p0 < gcc-2.95.3-full.patch
#     ${PATCH} -p0 < gcc-2.95.3-arm-pic.patch
#     ${PATCH} -p0 < gcc-2.95.3-arm-pic.patch2
#     ${PATCH} -p0 < gcc-2.95.3-arm-mlib.patch
#     ${PATCH} -p0 < gcc-2.95.3-sigset.patch
# 	${PATCH} -p0 < gcc-2.95.3-m68k-zext.patch
# 	${PATCH} --directory gcc-2.95.3 -p1 < gcc-makeinfo-strcpy-overlap.patch
#     if [ "${CYGWIN}" ]; then
#         ${PATCH} -p0 < gcc-2.95.3-cygwin-020611.patch
#     fi
# 	${PATCH} -p0 < STLport-4.5.3.patch
# 	${PATCH} --directory=binutils-2.14 -p1 < binutils-2.15-allow-gcc-4.0.patch
# 	rm -rf gcc-2.95.3/libio
# 	rm -rf gcc-2.95.3/libstdc++
# 
 	cd ${BUILD_DIR}
 	mark 1

}

#############################################################
#
# build binutils
#

stage2()
{
  schk 2 || return 0

  extract_tarball ${SRC_DIR} ${BINUTILS_DIR}
  patch_sources ${SRC_DIR} ${BINUTILS_DIR}
  rm -rf ${BUILD_DIR}/build-${BINUTILS_DIR}-${TARGET}
  mkdir -v ${BUILD_DIR}/build-${BINUTILS_DIR}-${TARGET}
  cd ${BUILD_DIR}/build-${BINUTILS_DIR}-${TARGET}
  CC=${HOSTCC_COMMAND} ${SETARCH_COMMAND} ${SRC_DIR}/${BINUTILS_DIR}/configure ${HOST_TARGET} \
    --target=${TARGET} --prefix=${PREFIX} \
    --disable-nls
  ${MAKE}
  ${MAKE} install

  # remove files not found in original toolchain distribution
  rm -v -f ${PREFIX}/lib/libiberty.a
  rm -v -f ${PREFIX}/info/as.info
  rm -v -f ${PREFIX}/info/bfd.info
  rm -v -f ${PREFIX}/info/bfd.info*
  rm -v -f ${PREFIX}/info/binutils.info
  rm -v -f ${PREFIX}/info/configure.info
  rm -v -f ${PREFIX}/info/configure.info*
  rm -v -f ${PREFIX}/info/dir
  rm -v -f ${PREFIX}/info/ld.info
  rm -v -f ${PREFIX}/info/standards.info

  cd ${BUILD_DIR}
  mark 2
}

#############################################################
#
# common uClibc Config substitutions
#

fix_uclibc_config()
{
	(grep -v KERNEL_SOURCE; echo "KERNEL_SOURCE=\"${SRC_DIR}/${LINUX_DIR}\"") |
	if [ "${NOMMU}" ]; then
		egrep -v '(UCLIBC_HAS_MMU|HAVE_SHARED|BUILD_UCLIBC_LDSO)' |
			egrep -v '(HAS_SHADOW|MALLOC=y|MALLOC is not set|UNIX98PTY_ONLY|UCLIBC_CTOR_DTOR)' |
			egrep -v '(DOPIC|UCLIBC_DYNAMIC_ATEXIT|UCLIBC_MALLOC_DEBUGGING)' |
			egrep -v '(UCLIBC_HAS_THREADS|PTHREADS_DEBUG_SUPPORT|UCLIBC_HAS_WCHAR|UCLIBC_HAS_LOCALE)'
		echo '# UCLIBC_HAS_MMU is not set'
		echo '# HAVE_SHARED is not set'
		echo '# BUILD_UCLIBC_LDSO is not set'
		echo '# HAS_SHADOW is not set'
		echo 'MALLOC=y'
		echo '# MALLOC_930716 is not set'
		echo '# UNIX98PTY_ONLY is not set'
		echo 'UCLIBC_CTOR_DTOR=y'
		echo 'UCLIBC_DYNAMIC_ATEXIT=y'
		echo '# UCLIBC_MALLOC_DEBUGGING is not set'
		echo "UCLIBC_HAS_WCHAR=y"
		echo "# UCLIBC_HAS_LOCALE is not set"
		echo "UCLIBC_HAS_THREADS=y"
		echo '# PTHREADS_DEBUG_SUPPORT is not set'
		echo "# DOPIC is not set"
	else
		cat
	fi
}

#############################################################
#
# hack the env up for gcc build
#

stage3()
{
  schk 3 || return 0
  # set -x

  extract_tarball ${SRC_DIR} ${LINUX_DIR}
  if [ -n "${LINUX_UCLINUX_DIR}" ] ; then
    patch_kernel_uclinux ${SRC_DIR} ${LINUX_DIR} ${LINUX_UCLINUX_DIR}
  fi
  patch_sources ${SRC_DIR} ${LINUX_DIR}

  cd ${SRC_DIR}/${LINUX_DIR}
  cp ${KERNELCONFIG} .config
  make ARCH=${_CPU}${NOMMU} oldconfig
  make ARCH=${_CPU}${NOMMU} dep
  rm -f ./include/asm
  rm -f ./include/asm-${_CPU}${NOMMU}/proc
  rm -f ./include/asm-${_CPU}${NOMMU}/arch
  ln -v -s asm-${_CPU}${NOMMU} ./include/asm
  cd ${BUILD_DIR}

  extract_tarball ${SRC_DIR} ${UCLIBC_DIR}
  if [ -d "${SRC_DIR}/uClibc" ] ; then
    mv "${SRC_DIR}/uClibc" "${SRC_DIR}/${UCLIBC_DIR}"
  fi
  patch_sources ${SRC_DIR} ${UCLIBC_DIR}
  
  cd ${SRC_DIR}/${UCLIBC_DIR}
  # remove junk object files, wrong architecture
  rm -v -rf ./extra/config/*.o ./extra/config/conf ./extra/config/mconf
  # remove symbolic link to non-existent file
  rm -v -rf ./include/net/bpf.h
  cp ${UCLIBCCONFIG} .config.001~
  fix_uclibc_config < .config.001~ > .config.002~
  diff -urNp .config.001~ .config.002~ || true
  cp .config.002~ .config
  ${MAKE} oldconfig CROSS="${TARGET}-" TARGET_ARCH=${_CPU}
  ${MAKE} headers CROSS="${TARGET}-" TARGET_ARCH=${_CPU}
  chmod 644 include/bits/uClibc_config.h

  rm -rf ${PREFIX}/${TARGET}/${sysinclude}
  rm -f ./include/asm
  cp -L -r ./include   ${PREFIX}/${TARGET}/${sysinclude}
  rm -rf ${PREFIX}/${TARGET}/${sysinclude}/asm
  rm -rf ${PREFIX}/${TARGET}/${sysinclude}/bits
  cp -L -r ./include/bits ${PREFIX}/${TARGET}/${sysinclude}/bits
  # cp -r ./libc/sysdeps/linux/${_CPU}/bits ${PREFIX}/${TARGET}/${sysinclude}/.
  # cp include/bits/uClibc_config.h ${PREFIX}/${TARGET}/${sysinclude}/bits/.
  rm -rf ${PREFIX}/${TARGET}/${sysinclude}/linux
  cp -L -r ${SRC_DIR}/${LINUX_DIR}/include/linux ${PREFIX}/${TARGET}/${sysinclude}/linux
  touch ${PREFIX}/${TARGET}/${sysinclude}/linux/autoconf.h
  cp -L -r ${SRC_DIR}/${LINUX_DIR}/include/asm-${_CPU}${NOMMU} \
    ${PREFIX}/${TARGET}/${sysinclude}/asm-${_CPU}${NOMMU}

  # 2.4 headers also need this (may not be there for some archs)
  cp -L -r ${SRC_DIR}/${LINUX_DIR}/include/asm-${_CPU} \
    ${PREFIX}/${TARGET}/${sysinclude}/asm-${_CPU}  || true

  ln -v -s asm-${_CPU}${NOMMU} ${PREFIX}/${TARGET}/${sysinclude}/asm

  case ${TARGET} in
    arm*)
      ln -v -s ../asm-${_CPU}${NOMMU}/arch-atmel ${PREFIX}/${TARGET}/${sysinclude}/asm/arch
      ln -v -s ../asm-${_CPU}${NOMMU}/proc-armv  ${PREFIX}/${TARGET}/${sysinclude}/asm/proc
      ;;
  esac

  #
  # clean out any CVS files,  don't fail on this one
  #
  set +e
  find ${PREFIX}/${TARGET}/${sysinclude} -name CVS | xargs rm -rf
  set -e

  mkdir -p ${PREFIX}/lib/gcc-lib || true
  chmod 755 ${PREFIX}/lib/gcc-lib

  cd ${BUILD_DIR}
  mark 3
}

#############################################################
#
# first pass,  just the C compiler so we can build uClibc
#

stage4()
{
  schk 4 || return 0

  extract_tarball ${SRC_DIR} ${GCC_DIR}
  rm -rf ${SRC_DIR}/${GCC_DIR}/libio
  rm -rf ${SRC_DIR}/${GCC_DIR}/libstdc++
  patch_sources ${SRC_DIR} ${GCC_DIR}

  rm -rf ${BUILD_DIR}/build-${GCC_DIR}-${TARGET}-core
  mkdir -v ${BUILD_DIR}/build-${GCC_DIR}-${TARGET}-core
  cd ${BUILD_DIR}/build-${GCC_DIR}-${TARGET}-core

  CC=${HOSTCC_COMMAND} ${SETARCH_COMMAND} ${SRC_DIR}/${GCC_DIR}/configure ${HOST_TARGET} \
     --target=${TARGET} --prefix=${PREFIX} \
     --enable-languages=c
  make
  make install
  # remove files not found in original toolchain distribution
  rm -v -f ${PREFIX}/lib/libiberty.a
  rm -v -f ${PREFIX}/info/cpp.info
  rm -v -f ${PREFIX}/info/cpp.info*
  rm -v -f ${PREFIX}/info/gcc.info
  rm -v -f ${PREFIX}/info/gcc.info*

  cd ${BUILD_DIR}
  mark 4
}

#############################################################
#
# build uClibc with first pass compiler
#

stage5()
{
  schk 5 || return 0

  cd ${SRC_DIR}/${UCLIBC_DIR}
  make distclean

  cp ${UCLIBCCONFIG} .config.001~
  fix_uclibc_config < .config.001~ > .config.002~
  diff -urNp .config.001~ .config.002~ || true
  cp .config.002~ .config

  rm -f ${SRC_DIR}/${LINUX_DIR}/include/asm/proc
  rm -f ${SRC_DIR}/${LINUX_DIR}/include/asm/arch
  rm -f ${SRC_DIR}/${LINUX_DIR}/include/asm
  ln -v -s asm-${_CPU}${NOMMU} ${SRC_DIR}/${LINUX_DIR}/include/asm

  case ${TARGET} in
    arm*)
      ln -v -s ../asm-${_CPU}${NOMMU}/arch-atmel \
        ${SRC_DIR}/${LINUX_DIR}/include/asm/arch
      ln -v -s ../asm-${_CPU}${NOMMU}/proc-armv \
        ${SRC_DIR}/${LINUX_DIR}/include/asm/proc
      ;;
  esac

  rm -rf ./include/config
  mkdir ./include/config
  touch include/config/autoconf.h

  ${MAKE} oldconfig CROSS="${TARGET}-" TARGET_ARCH=${_CPU}

  ${MAKE} clean CROSS="${TARGET}-" TARGET_ARCH=${_CPU} || true
  ${MAKE} CROSS="${TARGET}-" TARGET_ARCH=${_CPU} ARCH_CFLAGS="-I${SRC_DIR}/${LINUX_DIR}/include"
  rm -rf ./include/config

  cd ${BUILD_DIR}
  mark 5
}

#############################################################
#
# second pass,  build everything,  all compilers of use :-)
#

stage6()
{
  schk 6 || return 0

  local gccver=`expr match "${GCC_DIR}" 'gcc\-\([0-9.]\+\)'`
  test -n "${gccver}" || abort "Could not detect gcc version in ${GCC_DIR}"

  extract_tarball ${SRC_DIR} ${GCC_DIR}
  rm -rf ${SRC_DIR}/${GCC_DIR}/libio
  rm -rf ${SRC_DIR}/${GCC_DIR}/libstdc++
  patch_sources ${SRC_DIR} ${GCC_DIR}

  rm -rf ${BUILD_DIR}/build-${GCC_DIR}-${TARGET}-gcc
  mkdir -v ${BUILD_DIR}/build-${GCC_DIR}-${TARGET}-gcc
  cd ${BUILD_DIR}/build-${GCC_DIR}-${TARGET}-gcc

  #
  # We need these files for the configure parts of this stage
  #
  cp ${SRC_DIR}/${UCLIBC_DIR}/lib/libc.a ${PREFIX}/${TARGET}/lib/.
  cp ${SRC_DIR}/${UCLIBC_DIR}/lib/crt0.o ${PREFIX}/${TARGET}/lib/.
  case "${TARGET}" in
    arm-*)
      # create if not there
      ar rv ${PREFIX}/${TARGET}/lib/libg.a
      ;;
  esac

  CC=${HOSTCC_COMMAND} ${SETARCH_COMMAND} ${SRC_DIR}/${GCC_DIR}/configure ${HOST_TARGET} \
     --with-gxx-include-dir=${PREFIX}/${TARGET}/stlport \
     --target=${TARGET} --prefix=${PREFIX} \
     --enable-languages=c,c++ --enable-multilib

  ${MAKE} LIBS=-lc CFLAGS='-Dlinux -D__linux__ -Dunix'

  #
  # Make sure the multilib directories exist, the ARM install misses
  # these for some reason
  #
  for lib in libio libiostream libstdc++
  do
    find ${TARGET} -name $lib.a -print | while read file
    do
      MLIB=`expr $file : "${TARGET}\(.*\)"`
      MLIB=`expr $MLIB : "\(.*\)/[^/]*/$lib.a"`
      if [ ! -d "${PREFIX}/lib/gcc-lib/${TARGET}/${gccver}/$MLIB" ]
      then
        echo "Fixing ${PREFIX}/lib/gcc-lib/${TARGET}/${gccver}/$MLIB"
        mkdir -p "${PREFIX}/lib/gcc-lib/${TARGET}/${gccver}/$MLIB"
        chmod 755 "${PREFIX}/lib/gcc-lib/${TARGET}/${gccver}/$MLIB"
      fi
    done || exit 1
  done || exit 1

  ${MAKE} install
  # remove files not found in original toolchain distribution
  rm -v -f ${PREFIX}/lib/libiberty.a
  rm -v -f ${PREFIX}/info/cpp.info
  rm -v -f ${PREFIX}/info/cpp.info*
  rm -v -f ${PREFIX}/info/gcc.info
  rm -v -f ${PREFIX}/info/gcc.info*

  #
  # The _ctors.o file included in libgcc causes all kinds of random pain
  # sometimes it gets included and sometimes it doesn't.  By removing it
  # and using a good linker script (ala elf2flt.ld) all will be happy
  #
  find ${PREFIX}/lib/gcc-lib/${TARGET}/. -name libgcc.a -print | while read t
  do
    ${TARGET}-ar dv "$t" _ctors.o
  done

  #
  #
  # Don't leave these around as they will not work for all targets
  # the proper ones get built later in stage9/stageA
  #
  rm -f ${PREFIX}/${TARGET}/lib/libc.a
  rm -f ${PREFIX}/${TARGET}/lib/crt0.o

  cd ${BUILD_DIR}
  mark 6
}

#############################################################
#
# build genromfs
#

stage7()
{
  schk 7 || return 0
  test -n "${GENROMFS_DIR}" || return 0

  extract_tarball ${SRC_DIR} ${GENROMFS_DIR}
  patch_sources ${SRC_DIR} ${GENROMFS_DIR}

  cd ${SRC_DIR}/${GENROMFS_DIR}
  CC=${HOSTCC_COMMAND} ${MAKE}
  cp genromfs${EXE} ${PREFIX}/bin/.
  chmod 755 ${PREFIX}/bin/genromfs${EXE}

  cd ${BUILD_DIR}
  mark 7
}

#############################################################
#
# build elf2flt
#

stage8()
{
  schk 8 || return 0
  test -n "${ELF2FLT_DIR}" || return 0
  
  extract_tarball ${SRC_DIR} ${ELF2FLT_DIR}
  if [ -d "${SRC_DIR}/elf2flt" ] ; then
    mv "${SRC_DIR}/elf2flt" "${SRC_DIR}/${ELF2FLT_DIR}"
  fi
  patch_sources ${SRC_DIR} ${ELF2FLT_DIR}

  cd ${SRC_DIR}/${ELF2FLT_DIR}
  CC=${HOSTCC_COMMAND} ${SETARCH_COMMAND} ./configure ${HOST_TARGET} \
      --with-libbfd=${BUILD_DIR}/build-${BINUTILS_DIR}-${TARGET}/bfd/libbfd.a \
      --with-libiberty=${BUILD_DIR}/build-${BINUTILS_DIR}-${TARGET}/libiberty/libiberty.a \
      --with-bfd-include-dir=${BUILD_DIR}/build-${BINUTILS_DIR}-${TARGET}/bfd \
      --target=${TARGET} --prefix=${PREFIX}
  ${MAKE}
  ${MAKE} install

  cd ${BUILD_DIR}
  mark 8
}

#############################################################

multilib_table()
{
	case "${_CPU}" in
	m68k*) ALL_BUILDS="-Wa,--bitwise-or -D__linux__=1" ;;
	*)     ALL_BUILDS="-D__linux__=1" ;;
	esac

	ALL_BUILDS="${ALL_BUILDS} -I${KERNEL}/include"

	echo ". $ALL_BUILDS"
	case "${_CPU}" in
	m68k*)
		echo "msoft-float       false $ALL_BUILDS -msoft-float"

		echo "m5200             false $ALL_BUILDS -m5200 -Wa,-m5200"
		echo "m5200/msep-data   true  $ALL_BUILDS -m5200 -Wa,-m5200 -msep-data"
		echo "m5200/mid-shared-library   true  $ALL_BUILDS -m5200 -Wa,-m5200 -mid-shared-library"

		echo "m5307             false $ALL_BUILDS -m5307 -Wa,-m5307"
		echo "m5307/msep-data   true  $ALL_BUILDS -m5307 -Wa,-m5307 -msep-data"
		echo "m5307/mid-shared-library   true  $ALL_BUILDS -m5307 -Wa,-m5307 -mid-shared-library"

		echo "m68000            false $ALL_BUILDS -m68000"
		echo "m68000/msep-data  true  $ALL_BUILDS -m68000 -msep-data"
		echo "m68000/mid-shared-library   true  $ALL_BUILDS -m68000 -Wa,-m68000 -mid-shared-library"

		echo "mcpu32            false $ALL_BUILDS -mcpu32"
		echo "mcpu32/msep-data  true  $ALL_BUILDS -mcpu32 -msep-data"
		;;
	arm*)
		echo "fpic                           true $ALL_BUILDS -fpic"
		echo "fpic/msingle-pic-base          true $ALL_BUILDS -fpic -msingle-pic-base"
		echo "mapcs-26                       false $ALL_BUILDS -mapcs-26"
		echo "fpic/mapcs-26                  true $ALL_BUILDS -fpic -mapcs-26"
		echo "fpic/mapcs-26/msingle-pic-base true $ALL_BUILDS -fpic -mapcs-26 -msingle-pic-base"
		echo "mbig-endian/fpic                           true $ALL_BUILDS -fpic -mbig-endian"
		echo "mbig-endian/fpic/msingle-pic-base          true $ALL_BUILDS -fpic -mbig-endian -msingle-pic-base"
		echo "mbig-endian/mapcs-26                       false $ALL_BUILDS -mapcs-26 -mbig-endian"
		echo "mbig-endian/fpic/mapcs-26                  true $ALL_BUILDS -fpic -mapcs-26 -mbig-endian"
		echo "mbig-endian/fpic/mapcs-26/msingle-pic-base true $ALL_BUILDS -fpic -mapcs-26 -msingle-pic-base -mbig-endian"
		;;
	esac
}

#############################################################
#
# build multilib versions of uCLibc for a fuller install
#

stage9()
{
  schk 9 || return 0
  # set -x
  cd ${SRC_DIR}/${UCLIBC_DIR}

  rm -rf include/config
  mkdir include/config
  touch include/config/autoconf.h

  multilib_table | while read mlibdir pic cflags
  do
    cp ${UCLIBCCONFIG} .config.001~
    fix_uclibc_config $pic < .config.001~ > .config.002~
    diff -urNp .config.001~ .config.002~ || true
    cp .config.002~ .config

    ${MAKE} oldconfig CROSS="${TARGET}-" TARGET_ARCH=${_CPU}
    ${MAKE} clean CROSS="${TARGET}-" TARGET_ARCH=${_CPU} || true
    cflags="${cflags} -I${SRC_DIR}/${LINUX_DIR}/include"
    ${MAKE} CROSS="${TARGET}-" TARGET_ARCH=${_CPU} ARCH_CFLAGS="${cflags}"

    cp lib/crt0.o ${PREFIX}/${TARGET}/lib/$mlibdir/crt0.o || exit 1
    cp lib/libc.a ${PREFIX}/${TARGET}/lib/$mlibdir/libc.a || exit 1
    cp lib/libcrypt.a ${PREFIX}/${TARGET}/lib/$mlibdir/libcrypt.a || exit 1
    cp lib/libm.a ${PREFIX}/${TARGET}/lib/$mlibdir/libm.a || exit 1
    cp lib/libresolv.a ${PREFIX}/${TARGET}/lib/$mlibdir/libresolv.a || exit 1
    cp lib/libutil.a ${PREFIX}/${TARGET}/lib/$mlibdir/libutil.a || exit 1
    cp lib/libpthread.a ${PREFIX}/${TARGET}/lib/$mlibdir/libpthread.a || exit 1

    chmod 644 ${PREFIX}/${TARGET}/lib/$mlibdir/libc.a || exit 1
    chmod 644 ${PREFIX}/${TARGET}/lib/$mlibdir/crt0.o || exit 1

    # remove files not found in original toolchain distribution
    rm  -v -f ${PREFIX}/${TARGET}/lib/libc.a
    rm  -v -f ${PREFIX}/${TARGET}/lib/crt0.o
  done

  rm -rf include/config

  cd ${BUILD_DIR}
  mark 9
}

#############################################################
#
# build the STLport stuff,  and install it
#

stageA()
{
  schk A || return 0
  # set -x

  extract_tarball ${SRC_DIR} ${STLPORT_DIR}
  patch_sources ${SRC_DIR} ${STLPORT_DIR}

  cd ${SRC_DIR}/${STLPORT_DIR}/src
  multilib_table | while read mlibdir pic cflags
  do
    make -f gcc-uclinux-elf.mak ARCH=${_CPU} PREFIX=${PREFIX} CROSS=${TARGET}- clean
    make -f gcc-uclinux-elf.mak ARCH=${_CPU} PREFIX=${PREFIX} CROSS=${TARGET}- ARCH_CFLAGS="${cflags}" all || exit 1
    cp ../lib/libstdc++.a ${PREFIX}/${TARGET}/lib/$mlibdir/. || exit 1
  done

  rm -rf ${PREFIX}/${TARGET}/stlport
  cp -a ../stlport ${PREFIX}/${TARGET}/.

  cd ${BUILD_DIR}
  mark A
}


#############################################################
#
# cleanup
#

clean_all()
{
	echo "Cleaning everything up..."

	rm -f ${BUILD_DIR}/STAGE*
	rm -rf binutils-2.14
	rm -rf gcc-2.95.3
	rm -rf genromfs-0.5.1
	rm -rf STLport-4.5.3
	rm -rf ${TARGET}-gcc
	rm -rf ${TARGET}-binutils
}

#############################################################
#
# main - put everything together in order.
#
# Some setup
#

case ${TARGET} in
m68k*) _CPU=m68k; NOMMU=nommu ;;
arm*)  _CPU=arm;  NOMMU=nommu ;;
esac


#
# setup some Cygwin changes
#
if [ "${CYGWIN}" ]
then
	EXE=".exe"
	HOST_TARGET="--host=i386-pc-cygwin32"
else
	EXE=""
	HOST_TARGET=""
fi

rm -f ${BUILD_DIR}/STAGE*

set -e		# if anything fails, stop

stage1
stage2
stage3
stage4
stage5
stage6
stage7
stage8
stage9
stageA

echo "--------------------------------------------------------"
echo "Build successful !"
echo "--------------------------------------------------------"

#############################################################
