#! /bin/bash

#
# Temp build script
#
RSUDIR="$(pwd)/Rissu"
MGSKBT=$RSUDIR/bin/mgskbt
chmod +x $MGSKBT
init_variable() {
	export CROSS_COMPILE=$(pwd)/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
	export ARCH=arm64
	export CLANG_TOOL_PATH=$(pwd)/toolchain/clang/host/linux-x86/clang-r383902/bin/
	export PATH=${CLANG_TOOL_PATH}:${PATH//"${CLANG_TOOL_PATH}:"}
	export BSP_BUILD_FAMILY=qogirl6
	export DTC_OVERLAY_TEST_EXT=$(pwd)/tools/mkdtimg/ufdt_apply_overlay
	export DTC_OVERLAY_VTS_EXT=$(pwd)/tools/mkdtimg/ufdt_verify_overlay_host
	export BSP_BUILD_ANDROID_OS=y
}
init_variable;
PROC=$(nproc --all);
MIN_CORES="2"
MK_SC="mk_cmd.sh"

if [ $PROC -lt $MIN_CORES ]; then
	TC="1"
elif [ $PROC -gt $MIN_CORES ]; then
	TC=$(nproc --all);
else
	TC=$MIN_CORES
fi

printf "#! /usr/bin/env bash
make -C $(pwd) O=$(pwd)/out BSP_BUILD_DT_OVERLAY=y CC=clang LD=ld.lld ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- rsuntk_defconfig
make -C $(pwd) O=$(pwd)/out BSP_BUILD_DT_OVERLAY=y CC=clang LD=ld.lld ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- -j`echo $TC`" > $MK_SC

mk_bootimg() {
	cd $RSUDIR
	tar -xvf a03_s6.tar.xz
	$MGSKBT unpack boot.img
	rm $RSUDIR/kernel -f
	cp ../out/arch/arm64/boot/Image $RSUDIR/kernel
	$MGSKBT repack boot.img Scorpio-CI-`echo $RANDOM`
	rm $RSUDIR/kernel && rm $RSUDIR/ramdisk.cpio && rm $RSUDIR/dtb
}

if [ -f $MK_SC ]; then
	bash $MK_SC
	rm $MK_SC
	
	if [ -f $(pwd)/out/arch/arm64/boot/Image ]; then
		BUILD_STATE=0
	else
		BUILD_STATE=1
	fi
	
	if [[ $BUILD_STATE = '0' ]]; then
		mk_bootimg;
	else
		echo "Build failed, with $BUILD_STATE code."
		exit 1;
	fi
else
	echo "$MK_SC not found! Abort."
	exit 1
fi
