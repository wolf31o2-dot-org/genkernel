#!/bin/bash
# $Id$

compile_kernel_args() {
	local ARGS

	ARGS=''
	if [ "${KERNEL_CROSS_COMPILE}" != '' ]
	then
		ARGS="${ARGS} CROSS_COMPILE=\"${KERNEL_CROSS_COMPILE}\""
	else
		if [ "${KERNEL_CC}" != '' ]
		then
			ARGS="CC=\"${KERNEL_CC}\""
		fi
		if [ "${KERNEL_LD}" != '' ]
		then
			ARGS="${ARGS} LD=\"${KERNEL_LD}\""
		fi
		if [ "${KERNEL_AS}" != '' ]
		then
			ARGS="${ARGS} AS=\"${KERNEL_AS}\""
		fi
		if [ -n "${KERNEL_ARCH}" ]
		then
			ARGS="${ARGS} ARCH=\"${KERNEL_ARCH}\""
		fi
	fi
	echo -n "${ARGS}"
}

compile_utils_args()
{
	local ARGS
	ARGS=''

	if [ -n "${UTILS_CROSS_COMPILE}" ]
	then
		UTILS_CC="${UTILS_CROSS_COMPILE}gcc"
		UTILS_LD="${UTILS_CROSS_COMPILE}ld"
		UTILS_AS="${UTILS_CROSS_COMPILE}as"
	fi

	if [ "${UTILS_ARCH}" != '' ]
	then
		ARGS="ARCH=\"${UTILS_ARCH}\""
	fi
	if [ "${UTILS_CC}" != '' ]
	then
		ARGS="CC=\"${UTILS_CC}\""
	fi
	if [ "${UTILS_LD}" != '' ]
	then
		ARGS="${ARGS} LD=\"${UTILS_LD}\""
	fi
	if [ "${UTILS_AS}" != '' ]
	then
		ARGS="${ARGS} AS=\"${UTILS_AS}\""
	fi

	echo -n "${ARGS}"
}

export_utils_args()
{
	save_args
	if [ "${UTILS_ARCH}" != '' ]
	then
		export ARCH="${UTILS_ARCH}"
	fi
	if [ "${UTILS_CC}" != '' ]
	then
		export CC="${UTILS_CC}"
	fi
	if [ "${UTILS_LD}" != '' ]
	then
		export LD="${UTILS_LD}"
	fi
	if [ "${UTILS_AS}" != '' ]
	then
		export AS="${UTILS_AS}"
	fi
}

unset_utils_args()
{
	if [ "${UTILS_ARCH}" != '' ]
	then
		unset ARCH
	fi
	if [ "${UTILS_CC}" != '' ]
	then
		unset CC
	fi
	if [ "${UTILS_LD}" != '' ]
	then
		unset LD
	fi
	if [ "${UTILS_AS}" != '' ]
	then
		unset AS
	fi
	reset_args
}

export_kernel_args()
{
	if [ "${KERNEL_CC}" != '' ]
	then
		export CC="${KERNEL_CC}"
	fi
	if [ "${KERNEL_LD}" != '' ]
	then
		export LD="${KERNEL_LD}"
	fi
	if [ "${KERNEL_AS}" != '' ]
	then
		export AS="${KERNEL_AS}"
	fi
	if [ "${KERNEL_CROSS_COMPILE}" != '' ]
	then
		export CROSS_COMPILE="${KERNEL_CROSS_COMPILE}"
	fi
}

unset_kernel_args()
{
	if [ "${KERNEL_CC}" != '' ]
	then
		unset CC
	fi
	if [ "${KERNEL_LD}" != '' ]
	then
		unset LD
	fi
	if [ "${KERNEL_AS}" != '' ]
	then
		unset AS
	fi
	if [ "${KERNEL_CROSS_COMPILE}" != '' ]
	then
		unset CROSS_COMPILE
	fi
}
save_args()
{
	if [ "${ARCH}" != '' ]
	then
		export ORIG_ARCH="${ARCH}"
	fi
	if [ "${CC}" != '' ]
	then
		export ORIG_CC="${CC}"
	fi
	if [ "${LD}" != '' ]
	then
		export ORIG_LD="${LD}"
	fi
	if [ "${AS}" != '' ]
	then
		export ORIG_AS="${AS}"
	fi
	if [ "${CROSS_COMPILE}" != '' ]
	then
		export ORIG_CROSS_COMPILE="${CROSS_COMPILE}"
	fi
}
reset_args()
{
	if [ "${ORIG_ARCH}" != '' ]
	then
		export ARCH="${ORIG_ARCH}"
		unset ORIG_ARCH
	fi
	if [ "${ORIG_CC}" != '' ]
	then
		export CC="${ORIG_CC}"
		unset ORIG_CC
	fi
	if [ "${ORIG_LD}" != '' ]
	then
		export LD="${ORIG_LD}"
		unset ORIG_LD
	fi
	if [ "${ORIG_AS}" != '' ]
	then
		export AS="${ORIG_AS}"
		unset ORIG_AS
	fi
	if [ "${ORIG_CROSS_COMPILE}" != '' ]
	then
		export CROSS_COMPILE="${ORIG_CROSS_COMPILE}"
		unset ORIG_CROSS_COMPILE
	fi
}

apply_patches() {
	util=$1
	version=$2

	if [ -d "${GK_SHARE}/patches/${util}/${version}" ]
	then
		print_info 1 "${util}: >> Applying patches..."
		for i in ${GK_SHARE}/patches/${util}/${version}/*{diff,patch}
		do
			patch_success=0
			for j in `seq 0 5`
			do
				patch -p${j} --backup-if-mismatch -f < "${i}" >/dev/null
				if [ $? = 0 ]
				then
					patch_success=1
					break
				fi
			done
			if [ ${patch_success} != 1 ]
			then
				gen_die "could not apply patch ${i} for ${util}-${version}"
			fi
		done
	fi
}

compile_generic() {
	local RET
	[ "$#" -lt '2' ] &&
		gen_die 'compile_generic(): improper usage!'
	local target=${1}
	local argstype=${2}

	if [ "${argstype}" = 'kernel' ] || [ "${argstype}" = 'runtask' ]
	then
		export_kernel_args
		MAKE=${KERNEL_MAKE}
	elif [ "${2}" = 'utils' ]
	then
		export_utils_args
		MAKE=${UTILS_MAKE}
	fi
	case "${argstype}" in
		kernel) ARGS="`compile_kernel_args`" ;;
		utils) ARGS="`compile_utils_args`" ;;
		*) ARGS="" ;; # includes runtask
	esac
	shift 2

	# the eval usage is needed in the next set of code
	# as ARGS can contain spaces and quotes, eg:
	# ARGS='CC="ccache gcc"'
	if [ "${argstype}" == 'runtask' ]
	then
		print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS/-j?/j1} ${ARGS} ${target} $*" 1 0 1
		eval ${MAKE} -s ${MAKEOPTS/-j?/-j1} "${ARGS}" ${target} $*
		RET=$?
	elif [ "${LOGLEVEL}" -gt "1" ]
	then
		# Output to stdout and logfile
		print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} ${ARGS} ${target} $*" 1 0 1
		eval ${MAKE} ${MAKEOPTS} ${ARGS} ${target} $* 2>&1 | tee -a ${LOGFILE}
		RET=${PIPESTATUS[0]}
	else
		# Output to logfile only
		print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} ${ARGS} ${1} $*" 1 0 1
		eval ${MAKE} ${MAKEOPTS} ${ARGS} ${target} $* >> ${LOGFILE} 2>&1
		RET=$?
	fi
	[ "${RET}" -ne '0' ] &&
		gen_die "Failed to compile the \"${target}\" target..."

	unset MAKE
	unset ARGS
	if [ "${argstype}" = 'kernel' ]
	then
		unset_kernel_args
	elif [ "${argstype}" = 'utils' ]
	then
		unset_utils_args
	fi
}

compile_modules() {
	print_info 1 "        >> Compiling ${KV} modules..."
	cd ${KERNEL_DIR}
	compile_generic modules kernel
	export UNAME_MACHINE="${ARCH}"
	[ "${INSTALL_MOD_PATH}" != '' ] && export INSTALL_MOD_PATH
	compile_generic "modules_install" kernel
	unset UNAME_MACHINE
}

compile_kernel() {
	[ "${KERNEL_MAKE}" = '' ] &&
		gen_die "KERNEL_MAKE undefined - I don't know how to compile a kernel for this arch!"
	cd ${KERNEL_DIR}
	print_info 1 "        >> Compiling ${KV} ${KERNEL_MAKE_DIRECTIVE/_install/ [ install ]/}..."
	compile_generic "${KERNEL_MAKE_DIRECTIVE}" kernel
	if [ "${KERNEL_MAKE_DIRECTIVE_2}" != '' ]
	then
		print_info 1 "        >> Starting supplimental compile of ${KV}: ${KERNEL_MAKE_DIRECTIVE_2}..."
		compile_generic "${KERNEL_MAKE_DIRECTIVE_2}" kernel
	fi

	local tmp_kernel_binary=$(find_kernel_binary ${KERNEL_BINARY})
	local tmp_kernel_binary2=$(find_kernel_binary ${KERNEL_BINARY_2})
	if [ -z "${tmp_kernel_binary}" ]
	then
		gen_die "Cannot locate kernel binary"
	fi

	if ! isTrue "${CMD_NOINSTALL}"
	then
		copy_image_with_preserve "kernel" \
			"${tmp_kernel_binary}" \
			"kernel-${KNAME}-${ARCH}-${KV}"

		copy_image_with_preserve "System.map" \
			"System.map" \
			"System.map-${KNAME}-${ARCH}-${KV}"

		if isTrue "${GENZIMAGE}"
		then
			copy_image_with_preserve "kernelz" \
				"${tmp_kernel_binary2}" \
				"kernelz-${KV}"
		fi
	else
		cp "${tmp_kernel_binary}" "${TMPDIR}/kernel-${KNAME}-${ARCH}-${KV}" ||
			gen_die "Could not copy the kernel binary to ${TMPDIR}!"
		cp "System.map" "${TMPDIR}/System.map-${KNAME}-${ARCH}-${KV}" ||
			gen_die "Could not copy System.map to ${TMPDIR}!"
		if isTrue "${GENZIMAGE}"
		then
			cp "${tmp_kernel_binary2}" "${TMPDIR}/kernelz-${KV}" ||
				gen_die "Could not copy the kernelz binary to ${TMPDIR}!"
		fi
	fi
}

compile_busybox() {
	[ -f "${BUSYBOX_SRCTAR}" ] ||
		gen_die "Could not find busybox source tarball: ${BUSYBOX_SRCTAR}!"

	if [ -n "${BUSYBOX_CONFIG}" ]
	then
		[ -f "${BUSYBOX_CONFIG}" ] ||
			gen_die "Could not find busybox config file: ${BUSYBOX_CONFIG}"
	elif isTrue "${NETBOOT}" && [ -f "$(arch_replace "${GK_SHARE}/arch/%%ARCH%%/netboot-busy-config")" ]
	then
		BUSYBOX_CONFIG="$(arch_replace "${GK_SHARE}/arch/%%ARCH%%/netboot-busy-config")"
	elif isTrue "${NETBOOT}" && [ -f "${GK_SHARE}/netboot/busy-config" ]
	then
		BUSYBOX_CONFIG="${GK_SHARE}/netboot/busy-config"
	elif [ -f "$(arch_replace "${GK_SHARE}/arch/%%ARCH%%/busy-config")" ]
	then
		BUSYBOX_CONFIG="$(arch_replace "${GK_SHARE}/arch/%%ARCH%%/busy-config")"
	elif [ -f "${GK_SHARE}/defaults/busy-config" ]
	then
		BUSYBOX_CONFIG="${GK_SHARE}/defaults/busy-config"
	else
		gen_die "Could not find a busybox config file"
	fi

	# Delete cache if stored config's MD5 does not match one to be used
	if [ -f "${BUSYBOX_BINCACHE}" ]
	then
		oldconfig_md5=$(tar -xjf "${BUSYBOX_BINCACHE}" -O .config.gk_orig 2>/dev/null | md5sum)
		newconfig_md5=$(md5sum < "${BUSYBOX_CONFIG}")
		if [ "${oldconfig_md5}" != "${newconfig_md5}" ]
		then
			print_info 1 "busybox: >> Removing stale cache..."
			rm -rf "${BUSYBOX_BINCACHE}"
		else
			print_info 1 "busybox: >> Using cache"
		fi
	fi

	if [ ! -f "${BUSYBOX_BINCACHE}" ]
	then
		cd "${TEMP}"
		rm -rf "${BUSYBOX_DIR}" > /dev/null
		/bin/tar -jxpf ${BUSYBOX_SRCTAR} ||
			gen_die 'Could not extract busybox source tarball!'
		[ -d "${BUSYBOX_DIR}" ] ||
			gen_die 'Busybox directory ${BUSYBOX_DIR} is invalid!'
		cp "${BUSYBOX_CONFIG}" "${BUSYBOX_DIR}/.config"
		cp "${BUSYBOX_CONFIG}" "${BUSYBOX_DIR}/.config.gk_orig"
		cd "${BUSYBOX_DIR}"
		apply_patches busybox ${BUSYBOX_VER}
		print_info 1 'busybox: >> Configuring...'
		yes '' 2>/dev/null | compile_generic oldconfig utils

		print_info 1 'busybox: >> Compiling...'
		compile_generic all utils
		print_info 1 'busybox: >> Copying to cache...'
		[ -f "${TEMP}/${BUSYBOX_DIR}/busybox" ] ||
			gen_die 'Busybox executable does not exist!'
		strip "${TEMP}/${BUSYBOX_DIR}/busybox" ||
			gen_die 'Could not strip busybox binary!'
		tar -cj -C "${TEMP}/${BUSYBOX_DIR}" -f "${BUSYBOX_BINCACHE}" busybox .config .config.gk_orig ||
			gen_die 'Could not create the busybox bincache!'

		cd "${TEMP}"
		rm -rf "${BUSYBOX_DIR}" > /dev/null
	fi
}

compile_lvm() {
	compile_device_mapper
	if [ ! -f "${LVM_BINCACHE}" ]
	then
		[ -f "${LVM_SRCTAR}" ] ||
			gen_die "Could not find LVM source tarball: ${LVM_SRCTAR}! Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf ${LVM_DIR} > /dev/null
		/bin/tar -zxpf ${LVM_SRCTAR} ||
			gen_die 'Could not extract LVM source tarball!'
		[ -d "${LVM_DIR}" ] ||
			gen_die 'LVM directory ${LVM_DIR} is invalid!'
		rm -rf "${TEMP}/device-mapper" > /dev/null
		/bin/tar -jxpf "${DEVICE_MAPPER_BINCACHE}" -C "${TEMP}" ||
			gen_die "Could not extract device-mapper binary cache!";
		
		cd "${LVM_DIR}"
		print_info 1 'lvm: >> Configuring...'
			LDFLAGS="-L${TEMP}/device-mapper/lib" \
			CFLAGS="-I${TEMP}/device-mapper/include" \
			CPPFLAGS="-I${TEMP}/device-mapper/include" \
			./configure --enable-static_link --prefix=${TEMP}/lvm >> ${LOGFILE} 2>&1 ||
				gen_die 'Configure of lvm failed!'
		print_info 1 'lvm: >> Compiling...'
			compile_generic '' utils
			compile_generic 'install' utils

		cd "${TEMP}/lvm"
		print_info 1 '      >> Copying to bincache...'
		strip "sbin/lvm.static" ||
			gen_die 'Could not strip lvm.static!'
		/bin/tar -cjf "${LVM_BINCACHE}" sbin/lvm.static ||
			gen_die 'Could not create binary cache'

		cd "${TEMP}"
		rm -rf "${TEMP}/device-mapper" > /dev/null
		rm -rf "${LVM_DIR}" lvm
	fi
}

compile_dmraid() {
	compile_device_mapper
	if [ ! -f "${DMRAID_BINCACHE}" ]
	then
		[ -f "${DMRAID_SRCTAR}" ] ||
			gen_die "Could not find DMRAID source tarball: ${DMRAID_SRCTAR}! Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf ${DMRAID_DIR} > /dev/null
		/bin/tar -jxpf ${DMRAID_SRCTAR} ||
			gen_die 'Could not extract DMRAID source tarball!'
		[ -d "${DMRAID_DIR}" ] ||
			gen_die 'DMRAID directory ${DMRAID_DIR} is invalid!'
		rm -rf "${TEMP}/device-mapper" > /dev/null
		/bin/tar -jxpf "${DEVICE_MAPPER_BINCACHE}" -C "${TEMP}" ||
			gen_die "Could not extract device-mapper binary cache!";
		
		cd "${DMRAID_DIR}"
		print_info 1 'dmraid: >> Configuring...'
		
		LDFLAGS="-L${TEMP}/device-mapper/lib" \
		CFLAGS="-I${TEMP}/device-mapper/include" \
		CPPFLAGS="-I${TEMP}/device-mapper/include" \
		./configure --enable-static_link --prefix=${TEMP}/dmraid >> ${LOGFILE} 2>&1 ||
			gen_die 'Configure of dmraid failed!'

		# We dont necessarily have selinux installed yet... look into
		# selinux global support in the future.
		sed -i tools/Makefile -e "s|DMRAIDLIBS += -lselinux||g"
		###echo "DMRAIDLIBS += -lselinux -lsepol" >> tools/Makefile
		mkdir -p "${TEMP}/dmraid"
		print_info 1 'dmraid: >> Compiling...'
		# Force dmraid to be built with -j1 for bug #188273
		MAKEOPTS=-j1 compile_generic '' utils
		#compile_generic 'install' utils
		mkdir ${TEMP}/dmraid/sbin
		install -m 0755 -s tools/dmraid "${TEMP}/dmraid/sbin/dmraid"
		print_info 1 '      >> Copying to bincache...'
		cd "${TEMP}/dmraid"
		/bin/tar -cjf "${DMRAID_BINCACHE}" sbin/dmraid ||
			gen_die 'Could not create binary cache'

		cd "${TEMP}"
		rm -rf "${TEMP}/device-mapper" > /dev/null
		rm -rf "${DMRAID_DIR}" dmraid
	fi
}

compile_device_mapper() {
	if [ ! -f "${DEVICE_MAPPER_BINCACHE}" ]
	then
		[ ! -f "${DEVICE_MAPPER_SRCTAR}" ] &&
			gen_die "Could not find device-mapper source tarball: ${DEVICE_MAPPER_SRCTAR}. Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf "${DEVICE_MAPPER_DIR}"
		/bin/tar -zxpf "${DEVICE_MAPPER_SRCTAR}"
		[ ! -d "${DEVICE_MAPPER_DIR}" ] &&
			gen_die "device-mapper directory ${DEVICE_MAPPER_DIR} invalid"
		cd "${DEVICE_MAPPER_DIR}"
		./configure --prefix=${TEMP}/device-mapper --enable-static_link \
			--disable-selinux >> ${LOGFILE} 2>&1 ||
			gen_die 'Configuring device-mapper failed!'
		print_info 1 'device-mapper: >> Compiling...'
		compile_generic '' utils
		compile_generic 'install' utils
		print_info 1 '        >> Copying to cache...'
		cd "${TEMP}"
		rm -rf "${TEMP}/device-mapper/man" ||
			gen_die 'Could not remove manual pages!'
		strip "${TEMP}/device-mapper/sbin/dmsetup" ||
			gen_die 'Could not strip dmsetup binary!'
		/bin/tar -jcpf "${DEVICE_MAPPER_BINCACHE}" device-mapper ||
			gen_die 'Could not tar up the device-mapper binary!'
		[ -f "${DEVICE_MAPPER_BINCACHE}" ] ||
			gen_die 'device-mapper cache not created!'
		cd "${TEMP}"
		rm -rf "${DEVICE_MAPPER_DIR}" > /dev/null
		rm -rf "${TEMP}/device-mapper" > /dev/null
	fi
}

compile_e2fsprogs() {
	if [ ! -f "${BLKID_BINCACHE}" ]
	then
		[ ! -f "${E2FSPROGS_SRCTAR}" ] &&
			gen_die "Could not find e2fsprogs source tarball: ${E2FSPROGS_SRCTAR}. Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf "${E2FSPROGS_DIR}"
		tar -zxpf "${E2FSPROGS_SRCTAR}"
		[ ! -d "${E2FSPROGS_DIR}" ] &&
			gen_die "e2fsprogs directory ${E2FSPROGS_DIR} invalid"
		cd "${E2FSPROGS_DIR}"
		print_info 1 'e2fsprogs: >> Configuring...'
		./configure  --with-ldopts=-static >> ${LOGFILE} 2>&1 ||
			gen_die 'Configuring e2fsprogs failed!'
		print_info 1 'e2fsprogs: >> Compiling...'
		MAKE=${UTILS_MAKE} compile_generic "" ""
		print_info 1 'blkid: >> Copying to cache...'
		[ -f "${TEMP}/${E2FSPROGS_DIR}/misc/blkid" ] ||
			gen_die 'Blkid executable does not exist!'
		strip "${TEMP}/${E2FSPROGS_DIR}/misc/blkid" ||
			gen_die 'Could not strip blkid binary!'
		bzip2 "${TEMP}/${E2FSPROGS_DIR}/misc/blkid" ||
			gen_die 'bzip2 compression of blkid failed!'
		mv "${TEMP}/${E2FSPROGS_DIR}/misc/blkid.bz2" "${BLKID_BINCACHE}" ||
			gen_die 'Could not copy the blkid binary to the package directory, does the directory exist?'

		cd "${TEMP}"
		rm -rf "${E2FSPROGS_DIR}" > /dev/null
	fi
}

compile_fuse() {
	if [ ! -f "${FUSE_BINCACHE}" ]
	then
		[ ! -f "${FUSE_SRCTAR}" ] &&
			gen_die "Could not find fuse source tarball: ${FUSE_SRCTAR}. Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf "${FUSE_DIR}"
		tar -zxpf "${FUSE_SRCTAR}"
		[ ! -d "${FUSE_DIR}" ] &&
			gen_die "fuse directory ${FUSE_DIR} invalid"
		cd "${FUSE_DIR}"
		print_info 1 'fuse: >> Configuring...'
		./configure  --disable-kernel-module --disable-example >> ${LOGFILE} 2>&1 ||
			gen_die 'Configuring fuse failed!'
		print_info 1 'fuse: >> Compiling...'
		MAKE=${UTILS_MAKE} compile_generic "" ""

		# Since we're linking statically against libfuse, we don't need to cache the .so
#		print_info 1 'libfuse: >> Copying to cache...'
#		[ -f "${TEMP}/${FUSE_DIR}/lib/.libs/libfuse.so" ] ||
#			gen_die 'libfuse.so does not exist!'
#		strip "${TEMP}/${FUSE_DIR}/lib/.libs/libfuse.so" ||
#			gen_die 'Could not strip libfuse.so!'
#		cd "${TEMP}/${FUSE_DIR}/lib/.libs"
#		tar -cjf "${FUSE_BINCACHE}" libfuse*so* ||
#			gen_die 'Could not create fuse bincache!'

		cd "${TEMP}"
#		rm -rf "${FUSE_DIR}" > /dev/null
	fi
}

compile_unionfs_fuse() {
	if [ ! -f "${UNIONFS_FUSE_BINCACHE}" ]
	then

		# We'll call compile_fuse() from here, since it's not needed directly by anything else
		compile_fuse

		[ ! -f "${UNIONFS_FUSE_SRCTAR}" ] &&
			gen_die "Could not find unionfs-fuse source tarball: ${UNIONFS_FUSE_SRCTAR}. Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf "${UNIONFS_FUSE_DIR}"
		tar -jxpf "${UNIONFS_FUSE_SRCTAR}"
		[ ! -d "${UNIONFS_FUSE_DIR}" ] &&
			gen_die "unionfs-fuse directory ${UNIONFS_FUSE_DIR} invalid"
		cd "${UNIONFS_FUSE_DIR}"
		print_info 1 'unionfs-fuse: >> Compiling...'
		sed -i "/^\(CFLAGS\|CPPFLAGS\)/s:^\\(.*\\)$:\\1 -static -I${TEMP}/${FUSE_DIR}/include -L${TEMP}/${FUSE_DIR}/lib/.libs:" Makefile src/Makefile
		sed -i "/^LIB = /s:^LIB = \(.*\)$:LIB = -static -L${TEMP}/${FUSE_DIR}/lib/.libs \1 -ldl -lrt:" Makefile src/Makefile
		MAKE=${UTILS_MAKE} compile_generic "" ""
		print_info 1 'unionfs-fuse: >> Copying to cache...'
		[ -f "${TEMP}/${UNIONFS_FUSE_DIR}/src/unionfs" ] ||
			gen_die 'unionfs binary does not exist!'
		strip "${TEMP}/${UNIONFS_FUSE_DIR}/src/unionfs" ||
			gen_die 'Could not strip unionfs binary!'
		bzip2 "${TEMP}/${UNIONFS_FUSE_DIR}/src/unionfs" ||
			gen_die 'bzip2 compression of unionfs binary failed!'
		mv "${TEMP}/${UNIONFS_FUSE_DIR}/src/unionfs.bz2" "${UNIONFS_FUSE_BINCACHE}" ||
			gen_die 'Could not copy the unionfs binary to the package directory, does the directory exist?'

		cd "${TEMP}"
		rm -rf "${UNIONFS_FUSE_DIR}" > /dev/null
	fi
}

compile_iscsi() {
	if [ ! -f "${ISCSI_BINCACHE}" ]
	then
		[ ! -f "${ISCSI_SRCTAR}" ] &&
			gen_die "Could not find iSCSI source tarball: ${ISCSI_SRCTAR}. Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf "${ISCSI_DIR}"
		tar -zxpf "${ISCSI_SRCTAR}"
		[ ! -d "${ISCSI_DIR}" ] &&
			gen_die "ISCSI directory ${ISCSI_DIR} invalid"
				print_info 1 'iSCSI: >> Compiling...'
		cd "${TEMP}/${ISCSI_DIR}"

		# Only build userspace
		MAKE=${UTILS_MAKE} compile_generic "user" ""
	
		# if kernel modules exist, copy them to initramfs, otherwise it will be compiled into the kernel
		mkdir -p "${TEMP}/initramfs-iscsi-temp/lib/modules/${RELEASE}/kernel/drivers/scsi/"
		for modname in iscsi_tcp libiscsi scsi_transport_iscsi
		do
			if [ -e "${CMD_KERNEL_DIR}/drivers/scsi/${modname}.ko" ]
			then
				cp ${CMD_KERNEL_DIR}/drivers/scsi/${modname}.ko "${TEMP}/initramfs-iscsi-temp/lib/modules/${RELEASE}/kernel/drivers/scsi/"
			fi
		done

	        cd "${TEMP}/initramfs-iscsi-temp/"
		print_info 1 'iscsistart: >> Copying to cache...'
		[ -f "${TEMP}/${ISCSI_DIR}/usr/iscsistart" ] ||
			gen_die 'iscsistart executable does not exist!'
		strip "${TEMP}/${ISCSI_DIR}/usr/iscsistart" ||
			gen_die 'Could not strip iscsistart binary!'
		bzip2 "${TEMP}/${ISCSI_DIR}/usr/iscsistart" ||
			gen_die 'bzip2 compression of iscsistart failed!'
		mv "${TEMP}/${ISCSI_DIR}/usr/iscsistart.bz2" "${ISCSI_BINCACHE}" ||
			gen_die 'Could not copy the iscsistart binary to the package directory, does the directory exist?'

		cd "${TEMP}"
		rm -rf "${ISCSI_DIR}" > /dev/null
	fi
}

