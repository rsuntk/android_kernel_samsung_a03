#! /usr/bin/env bash

#
# Rissu Projects (C) 2024
#

#
# TODO: Tidy up this scripts
# TODO: Add support for Local build too.
# I guess this is not possible on Local build. since half
# of it handled by CI.
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
if [[ $GIT_CI_RELEASE_TYPE = "release" ]]; then
	DEFCONFIG="rsuntk_defconfig"
	sed -i 's/CONFIG_LOCALVERSION=\"\"/CONFIG_LOCALVERSION="-Scorpio-`echo $GIT_KERNEL_REVNUM`"/' "$(pwd)/arch/arm64/configs/$DEFCONFIG"
elif [[ $GIT_CI_RELEASE_TYPE = "testing" ]]; then
	DEFCONFIG="rsuci_defconfig"
fi
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

if [ $PROC -lt $MIN_CORES ]; then
	TC="1"
elif [ $PROC -gt $MIN_CORES ]; then
	TC=$(nproc --all);
else
	TC=$MIN_CORES
fi

if [ ! -z $GIT_LOCALVERSION ]; then
	LOCALVERSION="`echo $GIT_LOCALVERSION`_`echo $RNDM`"
	LTR="`echo $GIT_LOCALVERSION`"
else
	LOCALVERSION="Scorpio-CI"
	LTR="$LOCALVERSION"
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

printf "#! /usr/bin/env bash
make -C $(pwd) O=$(pwd)/out BSP_BUILD_DT_OVERLAY=y `echo $FLAGS` CC=clang LD=ld.lld ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- `echo $DEFCONFIG`
make -C $(pwd) O=$(pwd)/out BSP_BUILD_DT_OVERLAY=y `echo $FLAGS` CC=clang LD=ld.lld ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- -j`echo $TC`" > $MK_SC

if [[ $GIT_KSU_STATE = 'true' ]]; then
	FMT="`echo $LTR`-KSU-`echo $KSU_VERSION_NUMBER`-`echo $KSU_VERSION_TAGS`_`echo $RNDM`"
else
	FMT="`echo $LTR`-NO_KSU_`echo $RNDM`"
fi

BOOT_FMT="`echo $FMT`.img"
LZ4_FMT="`echo $BOOT_FMT`.lz4"

echo $FMT > $(pwd)/tmp_gitout_name.txt

mk_bootimg() { ## Stolen and simplified from rsuntk_v4.19.150 :D
	cd $RSUDIR
	tar -xvf a03_s6.tar.xz
	$MGSKBT unpack boot.img
	rm $RSUDIR/kernel -f
	cp ../out/arch/arm64/boot/Image $RSUDIR/kernel
	$MGSKBT repack boot.img $BOOT_FMT
	lz4 -B6 --content-size $BOOT_FMT $LZ4_FMT
	rm $RSUDIR/kernel && rm $RSUDIR/ramdisk.cpio && rm $RSUDIR/dtb && rm $RSUDIR/boot.img
}
upload_to_tg() {
	# Thanks to ItzKaguya, for references.
	cd $RSUDIR
	FILE_NAME="$LZ4_FMT"
	LINUX_VERSION=$(cd .. && make kernelversion)
	GIT_REPO_HASH=$(cd .. && git rev-parse --short HEAD)
	GIT_COMMIT_MSG=$(cd .. && git rev-list --max-count=1 --no-commit-header --format=%B HEAD)
	GIT_REPO_COMMIT_COUNT=$(cd .. && git rev-list --count HEAD)
	if [[ $GIT_CI_RELEASE_TYPE = "release" ]]; then
		release_text=$(cat <<EOF
Scorpio Kernel v`echo $GIT_KERNEL_REVNUM`
[$GIT_REPO_HASH](https://github.com/`echo $GIT_REPO`/commit/`echo $GIT_SHA`)

*Build Date:* `date`
Kernel Version: `echo $LINUX_VERSION`

\`\`\`
`echo $GIT_COMMIT_MSG`
\`\`\`

*Notes:*
- Untested, make sure to backup working boot.img before flash!

*How to flash:*
1. Unpack .lz4 archive,
2. Reboot to TWRP,
3. Select install, click Install Image,
4. Flash this to boot partition,
5. Reboot.

*How to make it ODIN flashable (tarball file)*
A. In Linux:
1. Install required dependency: lz4
2. Type this command:
\`\`\`sh
lz4 -d <Scorpio-CI-file>.lz4
mv <Scorpio-CI-file>.img boot.img
tar -cvf ScorpioCI.tar boot.img
\`\`\`

B. In Windows:
1. Unpack .lz4 file with 7Zip-ZS or WinRAR
2. Rename the .img file to boot.img
3. Right click at the boot.img file
4. Select 7zip ZS, click add to archive
5. Select Archive format to tar, and set it to GNU (default)

Bot by @RissuDesu

[Source Code](https://github.com/rsuntk/a03)
EOF
)
	elif [[ $GIT_CI_RELEASE_TYPE = "testing" ]]; then
		release_text=$(cat <<EOF
Scorpio CI-Kernel
[$GIT_REPO_HASH](https://github.com/`echo $GIT_REPO`/commit/`echo $GIT_SHA`)

*Build Date:* `date`
Kernel Version: `echo $LINUX_VERSION`

\`\`\`
`echo $GIT_COMMIT_MSG`
\`\`\`

*Notes:*
- Untested, make sure to backup working boot.img before flash!

*How to flash:*
1. Unpack .lz4 archive,
2. Reboot to TWRP,
3. Select install, click Install Image,
4. Flash this to boot partition,
5. Reboot.

*How to make it ODIN flashable (tarball file)*
A. In Linux:
1. Install required dependency: lz4
2. Type this command:
\`\`\`sh
lz4 -d <Scorpio-CI-file>.lz4
mv <Scorpio-CI-file>.img boot.img
tar -cvf ScorpioCI.tar boot.img
\`\`\`

B. In Windows:
1. Unpack .lz4 file with 7Zip-ZS or WinRAR
2. Rename the .img file to boot.img
3. Right click at the boot.img file
4. Select 7zip ZS, click add to archive
5. Select Archive format to tar, and set it to GNU (default)

Bot by @RissuDesu

[Source Code](https://github.com/rsuntk/a03)
EOF
)
	fi

	if [ ! -z $TG_BOT_TOKEN ]; then
		curl -s -F "chat_id=-`echo $TG_CHAT_ID`" -F "document=@$FILE_NAME" -F parse_mode='Markdown' -F "caption=$release_text" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument"
	else
		echo "! Telegram bot token empty. Abort kernel uploading";
	fi
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
		if [[ $TG_UPLOAD = 'true' ]]; then
			upload_to_tg;
		fi
	else
		echo "Build failed, with $BUILD_STATE code."
		exit 1;
	fi
else
	echo "$MK_SC not found! Abort."
	exit 1
fi
