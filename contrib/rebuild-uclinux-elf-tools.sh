#!/bin/bash
set -x
set -e



function delete_subdirs()
{
  local ddd=${1}
  (cd ${ddd} && ( ls -AU . | xargs --no-run-if-empty -n 3 rm -rf ) )
}



function echo_var_by_name()
{
  local var=${1}
  local ttt=
  (
    shift
    while [ $# -gt 0 ] ; do
      ff=${1}
      shift
      . ${ff}
    done
    eval ttt=\$${var} ; echo ${ttt}
  )
}



function rebuild_uclinux_elf_tools_3()
{
  test 'UCLINUX_ELF_TOOLS_Y_PATH,'${UCLINUX_ELF_TOOLS_Y_PATH} != 'UCLINUX_ELF_TOOLS_Y_PATH,'
  test 'UCLINUX_ELF_TARBALLS_DIR,'${UCLINUX_ELF_TARBALLS_DIR} != 'UCLINUX_ELF_TARBALLS_DIR,'
  test 'TOOLCOMBO,'${TOOLCOMBO} != 'TOOLCOMBO,'
  test 'TOOLCPU,'${TOOLCPU} != 'TOOLCPU,'
  test 'TARGET,'${TARGET} != 'TARGET,'
  test 'UCLINUX_ELF_TOOLS_RESULT_TOP,'${UCLINUX_ELF_TOOLS_RESULT_TOP} != 'UCLINUX_ELF_TOOLS_RESULT_TOP,'

  export TOP_DIR=${UCLINUX_ELF_TOOLS_Y_PATH}
  export PREFIX=${UCLINUX_ELF_TOOLS_RESULT_TOP}/${TOOLCOMBO}/${TARGET}
  export BUILD_DIR=${PWD}/${TOOLCOMBO}/${TARGET}/bld
  export SRC_DIR=${PWD}/${TOOLCOMBO}/${TARGET}/src
  export TARBALLS_DIR=${UCLINUX_ELF_TARBALLS_DIR}

  delete_subdirs ${PREFIX}
  rm -rf ${BUILD_DIR} ${SRC_DIR}
  mkdir -v -p ${BUILD_DIR} ${SRC_DIR}


  eval `cat ${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/${TOOLCOMBO}.conf ${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/${TOOLCPU}.conf` \
        sh ${UCLINUX_ELF_TOOLS_Y_PATH}/uclinux-elf-tools-builder.sh build
}



function rebuild_uclinux_elf_tools_2()
{
  test 'UCLINUX_ELF_TOOLS_Y_PATH,'${UCLINUX_ELF_TOOLS_Y_PATH} != 'UCLINUX_ELF_TOOLS_Y_PATH,'
  test 'TOOLCOMBO,'${TOOLCOMBO} != 'TOOLCOMBO,'
  test 'TOOLCPU,'${TOOLCPU} != 'TOOLCPU,'
  test -f "${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/${TOOLCOMBO}.conf"
  test -f "${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/${TOOLCPU}.conf"
  TARGET=`echo_var_by_name TARGET "${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/${TOOLCOMBO}.conf" "${UCLINUX_ELF_TOOLS_Y_PATH}/datfiles/${TOOLCPU}.conf"`
  test 'TARGET,'${TARGET} != 'TARGET,'
  rebuild_uclinux_elf_tools_3  2>&1 | tee rebuild-uclinux-elf-tools-${TOOLCOMBO}-${TARGET}.log
}



function rebuild_uclinux_elf_tools_1()
{

local UCLINUX_ELF_TOOLS_Y_PATH=${HOME}/src/uclinux-elf-tools-edit/uclinux-elf-tools-2003
local UCLINUX_ELF_TARBALLS_DIR=${HOME}/build_cache/uclinux-elf-tarballs
local UCLINUX_ELF_TOOLS_RESULT_TOP=${HOME}/uclinux-elf-tools

local TOOLCOMBOS_LIST=
if [ -n "${TOOLCOMBO}" ] ; then
  TOOLCOMBOS_LIST=${TOOLCOMBO}
else
TOOLCOMBOS_LIST='
gcc-2.95.3-uClibc-0.9.19-linux-2.4.20-uc0-debug
gcc-2.95.3-uClibc-0.9.19-linux-2.4.20-uc0-release
gcc-2.95.3-uClibc-0.9.19-linux-2.6.9-uc0-debug
gcc-2.95.3-uClibc-0.9.19-linux-2.6.9-uc0-release
'
fi

local TOOLCPU=m68k

for toolcombo in ${TOOLCOMBOS_LIST} ; do
    TOOLCOMBO=${toolcombo} TOOLCPU=${TOOLCPU} rebuild_uclinux_elf_tools_2
done

}



rebuild_uclinux_elf_tools_1
