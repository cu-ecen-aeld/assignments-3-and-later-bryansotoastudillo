#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

#install dependencies
#sudo apt install -y flex bison libssl-dev qemu-system-arm

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi
# after checking OUTDIR, we can know where the rootfs is
ROOTFS=${OUTDIR}/rootfs

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j12 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    printf "\033[0;33m DONE build kernel \033[0m\n"
fi

echo "Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

mkdir -p ${ROOTFS}
cd "${ROOTFS}"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log
printf "\033[0;33mBase directories are created\033[0m\n"

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    printf "\033[0;32mCheck out to version ${BUSYBOX_VERSION} of busybox\033[0m\n"
else
    cd busybox
fi

# Make and install busybox
printf "\033[0;32m Make and install busybox \033[0m\n"
make distclean
make defconfig
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${ROOTFS} install 

cd "$ROOTFS"
echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# Add library dependencies to rootfs
printf "\033[0;32m Add library dependencies to rootfs \033[0m\n"
TOOLCHAIN_DIR=empty
if grep -q docker /proc/self/cgroup; then
    # Running INSIDE Docker container
    GCC_ARM_VERSION=13.3.rel1
    # check the version in https://github.com/cu-ecen-aeld/aesd-autotest-docker/blob/master/docker/Dockerfile
    TOOLCHAIN_DIR=/usr/local/arm-cross-compiler/install/arm-gnu-toolchain-$GCC_ARM_VERSION-x86_64-aarch64-none-linux-gnu
    cp ${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib/ld-linux-aarch64.so.1  ./lib/ld-linux-aarch64.so.1
    cp ${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libc.so.6      ./lib64/
    cp ${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libm.so.6      ./lib64/
    cp ${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libresolv.so.2 ./lib64/
else
    # Running outside Docker container
    TOOLCHAIN_DIR=/home/ubuntu/Documents/arm/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu
    # Program interpreter placed in “lib” directory
    cp ${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib/ld-2.33.so        ./lib/ld-linux-aarch64.so.1
    # Libraries placed in lib64 directory (since arch is 64 bit)
    cp ${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libc.so.6      ./lib64/libc.so.6
    cp ${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libm.so.6      ./lib64/libm.so.6
    cp ${TOOLCHAIN_DIR}/aarch64-none-linux-gnu/libc/lib64/libresolv.so.2 ./lib64/libresolv.so.2
fi
printf "\033[0;33m Toolchain dir: ${TOOLCHAIN_DIR} \033[0m\n"

# Make device nodes
printf "\033[0;32m Make device nodes \033[0m\n"
sudo mknod -m 666 dev/null    c 1 3
sudo mknod -m 600 dev/console c 5 1

# Clean and build the writer utility
printf "\033[0;32m Clean and build the writer utility \033[0m\n"
cd "$FINDER_APP_DIR"
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} clean
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc) all

# Copy the finder related scripts and executables to the /home directory
# on the target rootfs
printf "\033[0;32m Copy related files to target rootfs \033[0m\n"
# Copy the writer application to home directory of rootfs
cp writer ${ROOTFS}/home
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} clean
# Copy finder.sh, conf/username.txt, conf/assignment.txt, and finder-test.sh to home directory of rootfs
cp finder.sh finder-test.sh ${ROOTFS}/home
rsync -R conf/username.txt ${ROOTFS}/home
rsync -R conf/assignment.txt ${ROOTFS}/home
# Remove the usage of make in finder-test.sh since there is no make utility in the target device
sed -i '51,53s/^/#/' ${ROOTFS}/home/finder-test.sh
# Modify the finder-test.sh script to reference conf/assignment.txt instead of ../conf/assignment.txt
sed -i 's|\.\./conf/assignment\.txt|conf/assignment.txt|g' ${ROOTFS}/home/finder-test.sh
# Copy the autorun-qemu.sh script into the home directory of rootfs
cp autorun-qemu.sh ${ROOTFS}/home

# Chown the root directory
printf "\033[0;32m Chown the root directory \033[0m\n"
cd "$ROOTFS"
sudo chown -R root:root *

# Create initramfs.cpio.gz
printf "\033[0;32m Create initramfs.cpio.gz \033[0m\n"
cd "${ROOTFS}"
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
cd "${OUTDIR}"
gzip -f initramfs.cpio
printf "\033[0;31m END \033[0m\n"
exit 0
