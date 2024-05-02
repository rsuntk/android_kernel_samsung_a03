#! /usr/bin/env bash

#
# Rissu Projects (C) 2024
#

#
# TODO: Tidy up this scripts
# TODO: Add support for Local build too.
#

# declare static variable
RSUDIR="$(pwd)/Rissu"
RNDM_BIN=$RSUDIR/bin/rndm
RNDM=$($RNDM_BIN)
PROC=$(nproc --all);
MIN_CORES="2"
MK_SC="mk_cmd.sh"
MGSKBT=$RSUDIR/bin/mgskbt
OUTDIR="$(pwd)/out"
DEFCONFIG="rsuntk_defconfig"
TMP_DEFCONFIG="tmprsu_defconfig"

# declare global variable
export CROSS_COMPILE=$(pwd)/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
export ARCH=arm64
export CLANG_TOOL_PATH=$(pwd)/toolchain/clang/host/linux-x86/clang-r383902/bin/
export PATH=${CLANG_TOOL_PATH}:${PATH//"${CLANG_TOOL_PATH}:"}
export BSP_BUILD_FAMILY=qogirl6
export DTC_OVERLAY_TEST_EXT=$(pwd)/tools/mkdtimg/ufdt_apply_overlay
export DTC_OVERLAY_VTS_EXT=$(pwd)/tools/mkdtimg/ufdt_verify_overlay_host
export BSP_BUILD_ANDROID_OS=y

# giving magiskboot and rndm
chmod +x $MGSKBT && chmod +x $RNDM_BIN

# copy rsuntk_defconfig
cat arch/$ARCH/configs/$DEFCONFIG > arch/$ARCH/configs/$TMP_DEFCONFIG

if [ $PROC -lt $MIN_CORES ]; then
	TC="1"
elif [ $PROC -gt $MIN_CORES ]; then
	TC=$(nproc --all);
else
	TC=$MIN_CORES
fi

if [ ! -z $GIT_LOCALVERSION ]; then
	LOCALVERSION="`echo $GIT_LOCALVERSION`_`echo $RNDM`"
else
	LOCALVERSION="`echo Scorpio-CI_$RNDM`"
fi

if [[ $GIT_KSU_STATE = 'true' ]]; then
	if [ ! -d $(pwd)/KernelSU ]; then
		if [[ $GIT_KSU_BRANCH = 'dev' ]]; then
			curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
		elif [[ $GIT_KSU_BRANCH = 'stable' ]]; then
			curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
		fi
	fi
	
	KSU_COMMIT_COUNT=$(cd KernelSU && git rev-list --count HEAD)
	KSU_VERSION_NUMBER=$(expr 10200 + $KSU_COMMIT_COUNT)
	KSU_VERSION_TAGS=$(cd KernelSU && git describe --tags)
	FLAGS="CONFIG_KSU=y"
else
	if [ -d $(pwd)/KernelSU ]; then
		rm $(pwd)/KernelSU
		# https://github.com/tiann/KernelSU/blob/main/kernel/setup.sh#L29
		echo "[+] Cleaning up..."
	    	[ -L "$(pwd)/drivers/kernelsu" ] && rm "$(pwd)/drivers/kernelsu" && echo "[-] Symlink removed."
	    	grep -q "kernelsu" "$(pwd)/drivers/Makefile" && sed -i '/kernelsu/d' "$(pwd)/drivers/Makefile" && echo "[-] Makefile reverted."
	    	grep -q "drivers/kernelsu/Kconfig" "$(pwd)/drivers/Kconfig" && sed -i '/drivers\/kernelsu\/Kconfig/d' "$(pwd)/drivers/Kconfig" && echo "[-] Kconfig reverted."
	fi
fi

if [[ $GIT_RISSU_DEBUGS = 'true' ]]; then
	echo "- Rissu Debug enabled"
	FLAGS+=" CONFIG_RISSU_KERNEL_PATCHES=y CONFIG_RISSU_SYSFS_PATCH=y CONFIG_RISSU_SPRD_OC=y CONFIG_RISSU_FORCE_LZ4=y"
fi

printf "#! /usr/bin/env bash
make -C $(pwd) O=$(pwd)/out BSP_BUILD_DT_OVERLAY=y CONFIG_LOCALVERSION=\"-`echo $LOCALVERSION`\" `echo $FLAGS` CC=clang LD=ld.lld ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- tmprsu_defconfig
make -C $(pwd) O=$(pwd)/out BSP_BUILD_DT_OVERLAY=y CONFIG_LOCALVERSION=\"-`echo $LOCALVERSION`\" `echo $FLAGS` CC=clang LD=ld.lld ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- -j`echo $TC`" > $MK_SC

if [[ $GIT_KSU_STATE = 'true' ]]; then
	FMT="Scorpio-CI-KSU-`echo $KSU_VERSION_NUMBER`-`echo $KSU_VERSION_TAGS`_`echo $RNDM`"
else
	FMT="Scorpio-CI-NO_KSU_`echo $RNDM`"
fi

BOOT_FMT="`echo $FMT`.img"

echo $FMT > $(pwd)/tmp_gitout_name.txt

mk_bootimg() {
	cd $RSUDIR
	tar -xvf a03_s6.tar.xz
	$MGSKBT unpack boot.img
	rm $RSUDIR/kernel -f
	cp ../out/arch/arm64/boot/Image $RSUDIR/kernel
	$MGSKBT repack boot.img $BOOT_FMT
	rm $RSUDIR/kernel && rm $RSUDIR/ramdisk.cpio && rm $RSUDIR/dtb && rm $RSUDIR/boot.img
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
