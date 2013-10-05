#!/bin/sh
#
# This script builds the m68k-elf- or arm-elf- toolchain for use
# with uClinux.  It can be used to build for almost any architecture
# without too much change.
#
# Before running you will need to obtain (if you don't have them in this
# directory):
#
#    binutils-2.10.tar.bz2         in current directory (or a gzipped version)
#    binutils-2.10-full.patch      in current directory
#    gcc-2.95.3.tar.bz2            in current directory (or a gzipped version)
#    gcc-2.95.3-full.patch         in current directory
#    gcc-2.95.3-arm-pic.patch      in current directory
#    gcc-2.95.3-arm-pic.patch2     in current directory
#    gcc-2.95.3-arm-mlib.patch     in current directory
#    gcc-2.95.3-sigset.patch       in current directory
#    gcc-2.95.3-m68k-zext.patch    in current directory
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
# WARNING: it removes all current tools from ${PREFIX},  so back them up
#          first :-)
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

BASEDIR="`pwd`"

#############################################################
#
# EDIT these to suit your system and source locations
#

MAKE=make
PATCH=patch
ELF2FLT="$BASEDIR/elf2flt"
UCLIBC="$BASEDIR/uClibc"
KERNEL="$BASEDIR/linux-2.4.x"
# KERNEL="$BASEDIR/uClinux-2.0.x"

# TARGET=m68k-elf
TARGET=arm-elf

# set your install directory here and add the correct PATH
# PREFIX=/tmp/tools
# PATH="${PREFIX}/bin:$PATH"; export PATH

# uncomment the following line to build for Cygwin
# you may also need to include your PATCH path specifically
# CYGWIN=cygwin-
# PATCH=/usr/bin/patch

#############################################################
#
# Don't edit these
#

sysinclude=include

#############################################################
#
# mark stage done
#

mark()
{
	echo "STAGE $1 - complete"
	touch "$BASEDIR/STAGE$1"
}

#
# check if stage should be built
#

schk()
{
	echo "--------------------------------------------------------"
	[ -f "$BASEDIR/STAGE$1" ] && echo "STAGE $1 - already built" && return 1
	echo "STAGE $1 - needs building"
	return 0
}

#
# extract most XYZ format files
#

extract()
{
	for i in "$@"; do
		case "$i" in
		*.tar.gz|*.tgz)   tar xzf "$i" ;;
		*.tar.bz2|*.tbz2) bunzip2 < "$i" | tar xf - ;;
		*.tar)            tar xf  "$i" ;;
		*)
			echo "Unknown file format $i" >&2
			return 1
			;;
		esac
	done
	return 0
}

#
# work like cp -L -r on systems without it
#

cp_Lr()
{
	cd "$1/."
	[ -d "$2" ] || mkdir -p $2
	find . | cpio -pLvdum "$2/."
}

#############################################################
#
# clean any previous runs, extract some stuff
#

stage1()
{
	schk 1 || return 0

	rm -rf binutils-2.10
	rm -rf gcc-2.95.3
	rm -rf STLport-4.5.3
	rm -rf ${PREFIX}/${TARGET}
	rm -rf ${PREFIX}/lib/gcc-lib/${TARGET}
	rm -rf ${PREFIX}/bin/${TARGET}*
	rm -rf ${PREFIX}/man/*/${TARGET}-*
#
#	extract binutils, gcc and anything else we know about
#
	extract binutils-2.10.*
	extract gcc-2.95.3.*
	extract STLport-4.5.3.tar.gz
#
#	apply any patches
#
	${PATCH} -p0 < gcc-2.95.3-full.patch
    ${PATCH} -p0 < gcc-2.95.3-arm-pic.patch
    ${PATCH} -p0 < gcc-2.95.3-arm-pic.patch2
    ${PATCH} -p0 < gcc-2.95.3-arm-mlib.patch
    ${PATCH} -p0 < gcc-2.95.3-sigset.patch
	${PATCH} -p0 < gcc-2.95.3-m68k-zext.patch
	${PATCH} -p0 < binutils-2.10-full.patch
    if [ "${CYGWIN}" ]; then
        ${PATCH} -p0 < gcc-2.95.3-cygwin-020611.patch
    fi
	${PATCH} -p0 < STLport-4.5.3.patch

	rm -rf gcc-2.95.3/libio
	rm -rf gcc-2.95.3/libstdc++

	cd $BASEDIR
	mark 1
}

#############################################################
#
# build binutils
#

stage2()
{
	schk 2 || return 0

	rm -rf ${TARGET}-binutils
	mkdir ${TARGET}-binutils
	cd ${TARGET}-binutils
	../binutils-2.10/configure ${HOST_TARGET} --target=${TARGET} ${PREFIXOPT}
	${MAKE}
	${MAKE} install
	cd $BASEDIR
	mark 2
}

#############################################################
#
# common uClibc Config substitutions
#

fix_uclibc_config()
{
	(grep -v KERNEL_SOURCE; echo "KERNEL_SOURCE=\"${KERNEL}\"") |
	if [ "${NOMMU}" ]; then
		egrep -v '(UCLIBC_HAS_MMU|HAVE_SHARED|BUILD_UCLIBC_LDSO)' |
			egrep -v '(HAS_SHADOW|MALLOC|UNIX98PTY_ONLY|UCLIBC_CTOR_DTOR)' |
			egrep -v '(DOPIC|UCLIBC_DYNAMIC_ATEXIT|UCLIBC_MALLOC_DEBUGGING)' |
			egrep -v '(UCLIBC_HAS_THREADS|UCLIBC_HAS_WCHAR|UCLIBC_HAS_LOCALE)'
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

	#
	# fix up the uClibc auto gen files
	#
	cd ${UCLIBC}/.
	fix_uclibc_config < extra/Configs/Config.${_CPU}.default > .config
	rm -f ${KERNEL}/include/asm
	rm -f ${KERNEL}/include/asm-${_CPU}${NOMMU}/proc
	rm -f ${KERNEL}/include/asm-${_CPU}${NOMMU}/arch
	ln -s ${KERNEL}/include/asm-${_CPU}${NOMMU} ${KERNEL}/include/asm
	${MAKE} oldconfig CROSS="${TARGET}-" TARGET_ARCH=${_CPU}
	${MAKE} headers CROSS="${TARGET}-" TARGET_ARCH=${_CPU}
	chmod 644 include/bits/uClibc_config.h

	rm -rf ${PREFIX}/${TARGET}/${sysinclude}
	rm -f ${UCLIBC}/include/asm
	cp_Lr ${UCLIBC}/include ${PREFIX}/${TARGET}/${sysinclude}
	rm -rf ${PREFIX}/${TARGET}/${sysinclude}/asm
	rm -rf ${PREFIX}/${TARGET}/${sysinclude}/bits
	cp_Lr ${UCLIBC}/include/bits ${PREFIX}/${TARGET}/${sysinclude}/bits
	# cp -r ${UCLIBC}/libc/sysdeps/linux/${_CPU}/bits ${PREFIX}/${TARGET}/${sysinclude}/.
	# cp include/bits/uClibc_config.h ${PREFIX}/${TARGET}/${sysinclude}/bits/.
	rm -rf ${PREFIX}/${TARGET}/${sysinclude}/linux
	cp_Lr ${KERNEL}/include/linux ${PREFIX}/${TARGET}/${sysinclude}/linux
	touch ${PREFIX}/${TARGET}/${sysinclude}/linux/autoconf.h
	cp_Lr ${KERNEL}/include/asm-${_CPU}${NOMMU} \
			${PREFIX}/${TARGET}/${sysinclude}/asm-${_CPU}${NOMMU}

	# 2.4 headers also need this (may not be there for some archs)
	cp_Lr ${KERNEL}/include/asm-${_CPU} \
			${PREFIX}/${TARGET}/${sysinclude}/asm-${_CPU}  || true

	ln -s ${PREFIX}/${TARGET}/${sysinclude}/asm-${_CPU}${NOMMU} \
					${PREFIX}/${TARGET}/${sysinclude}/asm
	
	case ${TARGET} in
	arm*)
		ln -s ${PREFIX}/${TARGET}/${sysinclude}/asm-${_CPU}${NOMMU}/arch-atmel \
						${PREFIX}/${TARGET}/${sysinclude}/asm/arch
		ln -s ${PREFIX}/${TARGET}/${sysinclude}/asm-${_CPU}${NOMMU}/proc-armv \
						${PREFIX}/${TARGET}/${sysinclude}/asm/proc
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

	cd $BASEDIR
	mark 3
}

#############################################################
#
# first pass,  just the C compiler so we can build uClibc
#

stage4()
{
	schk 4 || return 0

	rm -rf ${TARGET}-gcc
	mkdir ${TARGET}-gcc
	cd ${TARGET}-gcc
	../gcc-2.95.3/configure ${HOST_TARGET} \
			--enable-languages=c --target=${TARGET} ${PREFIXOPT}
	${MAKE}
	${MAKE} install

	cd $BASEDIR
	mark 4
}

#############################################################
#
# build uClibc with first pass compiler
#

stage5()
{
	schk 5 || return 0

	cd ${UCLIBC}/.
	make distclean
	fix_uclibc_config < extra/Configs/Config.${_CPU}.default > .config
	rm -f ${KERNEL}/include/asm/proc
	rm -f ${KERNEL}/include/asm/arch
	rm -f ${KERNEL}/include/asm
	ln -s ${KERNEL}/include/asm-${_CPU}${NOMMU} ${KERNEL}/include/asm
	case ${TARGET} in
	arm*)
		ln -s ${KERNEL}/include/asm-${_CPU}${NOMMU}/arch-atmel \
						${KERNEL}/include/asm/arch
		ln -s ${KERNEL}/include/asm-${_CPU}${NOMMU}/proc-armv \
						${KERNEL}/include/asm/proc
		;;
	esac
	rm -rf include/config
	mkdir include/config
	touch include/config/autoconf.h
	${MAKE} oldconfig CROSS="${TARGET}-" TARGET_ARCH=${_CPU}
	${MAKE} clean CROSS="${TARGET}-" TARGET_ARCH=${_CPU} || true
	${MAKE} CROSS="${TARGET}-" TARGET_ARCH=${_CPU} ARCH_CFLAGS="-I${KERNEL}/include"
	rm -rf include/config

	cd $BASEDIR
	mark 5
}

#############################################################
#
# second pass,  build everything,  all compilers of use :-)
#

stage6()
{
	schk 6 || return 0

	#
	# We need these files for the configure parts of this stage
	#
	cp ${UCLIBC}/lib/libc.a ${PREFIX}/${TARGET}/lib/.
	cp ${UCLIBC}/lib/crt0.o ${PREFIX}/${TARGET}/lib/.

	rm -rf ${TARGET}-gcc
	mkdir ${TARGET}-gcc
	cd ${TARGET}-gcc

	case "${TARGET}" in
	arm-*)
		# create if not there
		ar rv ${PREFIX}/${TARGET}/lib/libg.a
		;;
	esac

	../gcc-2.95.3/configure ${HOST_TARGET} \
			--with-gxx-include-dir=${PREFIX}/${TARGET}/stlport \
			--enable-languages=c,c++ --target=${TARGET} \
			--enable-multilib ${PREFIXOPT}
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
			if [ ! -d "${PREFIX}/lib/gcc-lib/${TARGET}/2.95.3/$MLIB" ]
			then
				echo "Fixing ${PREFIX}/lib/gcc-lib/${TARGET}/2.95.3/$MLIB"
				mkdir -p "${PREFIX}/lib/gcc-lib/${TARGET}/2.95.3/$MLIB"
				chmod 755 "${PREFIX}/lib/gcc-lib/${TARGET}/2.95.3/$MLIB"
			fi
		done || exit 1
	done || exit 1

	${MAKE} install

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

	cd $BASEDIR
	mark 6
}

#############################################################
#
# build genromfs
#

stage7()
{
	schk 7 || return 0
	rm -rf genromfs-0.5.1
	extract genromfs-0.5.1.*
	cd genromfs-0.5.1
	if [ "${CYGWIN}" ]; then
		${PATCH} -p0 < ../genromfs-0.5.1-cygwin-020605.patch
	fi
	${MAKE}
	cp genromfs${EXE} ${PREFIX}/bin/.
	chmod 755 ${PREFIX}/bin/genromfs${EXE}

	cd $BASEDIR
	mark 7
}

#############################################################
#
# build elf2flt
#

stage8()
{
	schk 8 || return 0


	cd ${ELF2FLT}
	./configure ${HOST_TARGET} \
		--with-libbfd=${BASEDIR}/${TARGET}-binutils/bfd/libbfd.a \
		--with-libiberty=${BASEDIR}/${TARGET}-binutils/libiberty/libiberty.a \
		--with-bfd-include-dir=${BASEDIR}/${TARGET}-binutils/bfd \
		--target=${TARGET} ${PREFIXOPT}
	${MAKE}
	${MAKE} install

	cd $BASEDIR
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
	cd ${UCLIBC}/.

	rm -rf include/config
	mkdir include/config
	touch include/config/autoconf.h

	multilib_table | while read mlibdir pic cflags
	do
		fix_uclibc_config $pic < extra/Configs/Config.${_CPU}.default > .config
		${MAKE} oldconfig CROSS="${TARGET}-" TARGET_ARCH=${_CPU}
		${MAKE} clean CROSS="${TARGET}-" TARGET_ARCH=${_CPU} || true
		cflahs="${cflags} -I${KERNEL}/include"
		${MAKE} CROSS="${TARGET}-" TARGET_ARCH=${_CPU} ARCH_CFLAGS="${cflags}"

		cp lib/crt0.o ${PREFIX}/${TARGET}/lib/$mlibdir/crt0.o || exit 1
		cp lib/libc.a ${PREFIX}/${TARGET}/lib/$mlibdir/libc.a || exit 1
		cp lib/libcrypt.a ${PREFIX}/${TARGET}/lib/$mlibdir/libcrypt.a || exit 1
		cp lib/libm.a ${PREFIX}/${TARGET}/lib/$mlibdir/libm.a || exit 1
		cp lib/libresolv.a ${PREFIX}/${TARGET}/lib/$mlibdir/libresolv.a || \
				exit 1
		cp lib/libutil.a ${PREFIX}/${TARGET}/lib/$mlibdir/libutil.a || exit 1
		cp lib/libpthread.a ${PREFIX}/${TARGET}/lib/$mlibdir/libpthread.a || exit 1

		chmod 644 ${PREFIX}/${TARGET}/lib/$mlibdir/libc.a || exit 1
		chmod 644 ${PREFIX}/${TARGET}/lib/$mlibdir/crt0.o || exit 1
	done

	rm -rf include/config

	cd $BASEDIR
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

	cd $BASEDIR/STLport-4.5.3/src
	multilib_table | while read mlibdir pic cflags
	do
		make -f gcc-uclinux-elf.mak ARCH=${_CPU} PREFIX=${PREFIX} \
				CROSS=${TARGET}- clean
		make -f gcc-uclinux-elf.mak ARCH=${_CPU} PREFIX=${PREFIX} \
				CROSS=${TARGET}- ARCH_CFLAGS="${cflags}" all || exit 1
		cp ../lib/libstdc++.a ${PREFIX}/${TARGET}/lib/$mlibdir/. || exit 1
	done

	rm -rf ${PREFIX}/${TARGET}/stlport
	cp -a ../stlport ${PREFIX}/${TARGET}/.

	cd $BASEDIR
	mark A
}

#############################################################
#
# tar up everthing we have built
#

build_tar_file()
{
	# set -x
	cd /

	EXTRAS=
	case "${TARGET}" in
	m68k*)
		if [ -f ".${PREFIX}/bin/m68k-bdm-elf-gdb${EXE}" ]
		then
			EXTRAS=".${PREFIX}/bin/m68k-bdm-elf-gdb${EXE}"
			EXTRAS="${EXTRAS} .${PREFIX}/bin/m68k-elf-gdb${EXE}"
			strip ${PREFIX}/bin/m68k-bdm-elf-gdb${EXE}
			ln -s ${PREFIX}/bin/m68k-bdm-elf-gdb${EXE} \
					${PREFIX}/bin/m68k-elf-gdb${EXE}
		fi
		;;
	esac

	#
	# strip the binaries,  make sure we don't strip the libraries (some
	# platforms allow this :-(
	#
	strip ${PREFIX}/bin/genromfs${EXE} > /dev/null 2>&1 || true
	strip ${PREFIX}/bin/${TARGET}-* > /dev/null 2>&1 || true
	strip ${PREFIX}/${TARGET}/bin/* > /dev/null 2>&1 || true
	strip ${PREFIX}/lib/gcc-lib/${TARGET}/2.95.3/*[!a] > /dev/null 2>&1 || true

	#
	# fix all directories
	#
	chmod a+rx .${PREFIX}/bin
	chmod a+rx .${PREFIX}/lib .${PREFIX}/lib/gcc-lib
	find .${PREFIX}/${TARGET} .${PREFIX}/lib/gcc-lib/${TARGET} -type d | \
			xargs chmod a+rw
	#
	# tar it all up
	#
	tar cvzf $BASEDIR/${TARGET}-tools-${CYGWIN}`date +%Y%m%d`.tar.gz \
		.${PREFIX}/${TARGET} \
		.${PREFIX}/lib/gcc-lib/${TARGET} \
		.${PREFIX}/man/*/${TARGET}-* \
		.${PREFIX}/bin/${TARGET}-* \
		.${PREFIX}/bin/genromfs${EXE} \
		.${PREFIX}/bin/elf2flt${EXE} \
		.${PREFIX}/bin/flthdr${EXE} \
		${EXTRAS}
	
	#
	# make an executable out of it that pre-cleans the directory
	# and checks a few things.
	#

	cat <<!EOF > $BASEDIR/${TARGET}-tools-${CYGWIN}`date +%Y%m%d`.sh
#!/bin/sh

SCRIPT="\$0"
case "\${SCRIPT}" in
/*)
	;;
*)
	if [ -f "\${SCRIPT}" ]
	then
		SCRIPT="\`pwd\`/\${SCRIPT}"
	else
		SCRIPT="\`which \${SCRIPT}\`"
	fi
	;;
esac

cd /

if [ ! -f "\${SCRIPT}" ]
then
	echo "Cannot find the location of the install script (\$SCRIPT) ?"
	exit 1
fi

SKIP=\`awk '/^__ARCHIVE_FOLLOWS__/ { print NR + 1; exit 0; }' \${SCRIPT}\`

if id | grep root > /dev/null
then
	:
else
	echo "You must be root to install these tools."
	exit 1
fi

rm -rf "${PREFIX}/${TARGET}"
rm -rf "${PREFIX}/lib/gcc-lib/${TARGET}"
rm -f ${PREFIX}/bin/${TARGET}-*

tail +\${SKIP} \${SCRIPT} | gunzip | tar xvf -

exit 0
__ARCHIVE_FOLLOWS__
!EOF

	cat $BASEDIR/${TARGET}-tools-${CYGWIN}`date +%Y%m%d`.tar.gz >> \
			$BASEDIR/${TARGET}-tools-${CYGWIN}`date +%Y%m%d`.sh
	chmod 755 $BASEDIR/${TARGET}-tools-${CYGWIN}`date +%Y%m%d`.sh

	cd $BASEDIR
}

#############################################################
#
# cleanup
#

clean_all()
{
	echo "Cleaning everything up..."

	rm -f $BASEDIR/STAGE*
	rm -rf binutils-2.10
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
# if not defined use the GNU tools default of /usr/local
#
if [ -z "${PREFIX}" ]
then
	PREFIX=/usr/local
else
	PREFIXOPT="--prefix=${PREFIX}"
fi

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

#
# first check some args
#

case "$1" in
build)
	rm -f $BASEDIR/STAGE*
	;;
continue)
	# do nothing here
	;;
tar)
	build_tar_file
	exit 0
	;;
clean)
	clean_all
	exit 0
	;;
*)
	echo "usage: $0 (build|continue|clean)" >&2
	echo ""
	echo "       build    = build everything from scratch."
	echo "       continue = continue building from last error."
	echo "       tar      = build for distribution of binaries."
	echo "       clean    = clean all temporary files etc."
	exit 1
	;;
esac

#
# You have to root for this one
#

if [ "${PREFIXOPT}" ]
then
	if [ ! -w "${PREFIX}" ]
	then
		echo "Bad,  ${PREFIX} is not writable !"
		exit 1
	fi
else
	if id | grep root > /dev/null
	then
		echo "Good, you are root :-)"
	else
		echo "Bad,  you are not root."
		exit 1
	fi
fi

if [ ! -f ${KERNEL}/include/linux/version.h -o \
		! -f ${KERNEL}/include/linux/autoconf.h ]; then
	echo "Your kernel is not configured, cannot continue." >&2
	echo "The following files do not exist:"
	echo
	echo "    ${KERNEL}/include/linux/version.h"
	echo "    ${KERNEL}/include/linux/autoconf.h"
	echo
	echo "These are need by the build.  You should do the following:"
	echo
	echo "    cd ${KERNEL}"
	echo "    make ARCH=${_CPU}${NOMMU} oldconfig"
	echo "    make dep"
	echo
	echo "You should then be able to continue."
	exit 1
fi

# set -x	# debug script
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
