# Disable stripping of tool chain binaries
%global debug_package %{nil}
# Disable stripping of tool chain binaries
%define __strip   /bin/true

%define PKGPREFIX   uclinux-elf-tools
%define TOOLCOMBO   gcc-2.95.3-uClibc-0.9.19-linux-2.4.20-uc0-release
%define RESULT_TOP  /opt/uclinux-elf-tools
%define TOOLCPU     m68k
%define TARGET      m68k-elf

%ifarch i686
%define HOSTCC_COMMAND gcc -m32
%else
%define HOSTCC_COMMAND gcc
%endif

Name            : %{?PKGPREFIX}-%{?TOOLCOMBO}-%{?TOOLCPU}-devel
Summary         : %{?TOOLCOMBO} toolchain for %{?TOOLCPU}
Version         : 1.0
Release         : 1%{?dist}
License         : GPL/LGPL
Group           : Development/Languages
URL             : http://www.uclinux.org/pub/uClinux/uclinux-elf-tools/
AutoReqProv     : no
BuildRequires   : binutils, glibc-devel
BuildRequires   : zlib-devel, gettext, bison, flex, texinfo
BuildRoot       : %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Source0         : uclinux-elf-tools-2003-%{version}.tar.gz
Source1         : binutils-2.14.tar.bz2
Source2         : gcc-2.95.3.tar.gz
Source3         : uClibc-0.9.19.tar.bz2
Source4         : linux-2.4.20.tar.bz2
Source5         : uClinux-2.4.20-uc0.diff.gz
Source6         : genromfs-0.5.1.tar.gz
Source7         : elf2flt-20030923.tar.gz
Source8         : STLport-4.5.3.tar.gz

%description

%{?TOOLCOMBO} toolchain and ELF tools
for %{?TOOLCPU} aka %{?TARGET}.
For use with uClinux/%{?TOOLCPU}.

Built using %{?PKGPREFIX}-%{?TOOLCOMBO} version
%{version}.

%prep

%setup0 -n uclinux-elf-tools-2003-%{version}

%build
##
## This is an UGLY alternative to fix-embedded-paths
## utility, that modifies toolchain binaries.
##
## I want to avoid modifying toolchain binaries after
## they were built.
##
## This is why I install directly into
## /opt/uclinux-elf-tools/%{?TOOLCOMBO}/%{?TARGET}
##
## To build as non-root, the last directory component
## (%{?TARGET}) must be pre-created, with the appropriate
## permissions given to the last directory only.
##
## Script uclinux-elf-tools-builder.sh checks that the
## directory exists, is writable and is empty.
## At the end of the build, the clean script removes
## all files in the directory.
##
## After the package has been built, the directory
## must be manually removed by the builder.
##
## TODO: For mock builds, make a package that
## creates this directory in post scriptlet
## and removes it in the preun scriptlet
## and put that package into BuildRequires
##
test -d %{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET}
test -w %{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET}

UCLINUX_ELF_TOOLS_Y_PATH=${PWD}
export TOP_DIR=${UCLINUX_ELF_TOOLS_Y_PATH}
export PREFIX=%{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET}
export BUILD_DIR=%{_builddir}/%{?TOOLCOMBO}/%{?TARGET}/bld
export SRC_DIR=%{_builddir}/%{?TOOLCOMBO}/%{?TARGET}/src
STASH_BUILDROOT_DIR=%{_builddir}/%{?TOOLCOMBO}/%{?TARGET}/stashbuildroot
export TARBALLS_DIR=%{_sourcedir}
cd ..

mkdir -v -p ${BUILD_DIR} ${SRC_DIR} ${STASH_BUILDROOT_DIR}

echo >>${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/%{?TOOLCOMBO}.conf
echo HOSTCC_COMMAND=\'%{?HOSTCC_COMMAND}\'>>${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/%{?TOOLCOMBO}.conf

eval `cat ${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/%{?TOOLCOMBO}.conf ${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/%{?TOOLCPU}.conf` \
   sh ${UCLINUX_ELF_TOOLS_Y_PATH}/uclinux-elf-tools-builder.sh build

mkdir -v -p ${STASH_BUILDROOT_DIR}%{?RESULT_TOP}/%{?TOOLCOMBO}

cp -R --preserve=mode,timestamps %{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET} \
    ${STASH_BUILDROOT_DIR}%{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET}
chmod 0755 ${STASH_BUILDROOT_DIR}%{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET}

%install
rm -rf %{buildroot}
mkdir %{buildroot}

STASH_BUILDROOT_DIR=%{_builddir}/%{?TOOLCOMBO}/%{?TARGET}/stashbuildroot
mkdir -v -p %{buildroot}/%{?RESULT_TOP}/%{?TOOLCOMBO}
cp -R --preserve=mode,timestamps \
    ${STASH_BUILDROOT_DIR}%{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET} \
    %{buildroot}/%{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET}

%clean
rm -rf %{buildroot}

echo Removing files from real dir %{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET}
(cd %{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET} && ( ls -AU . | xargs --no-run-if-empty -n 1 rm -rf ) )

rm -rf %{_builddir}/%{?TOOLCOMBO}/%{?TARGET}
rm -rf %{_builddir}/%{?TOOLCOMBO}

cd %{_builddir}
rm -rf %{_builddir}/uclinux-elf-tools-2003-%{version}

%files
%defattr(-,root,root)
%{?RESULT_TOP}/%{?TOOLCOMBO}/%{?TARGET}

%changelog
* Sun Oct 06 2013 Evgueni Souleimanov <esoule@100500.ca> - 1.0-1
- Initial revision
