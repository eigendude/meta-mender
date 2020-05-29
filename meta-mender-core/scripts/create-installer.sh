#!/bin/sh

################################################################################
#
# Script to create an installer in the root of the boot partition.
#
# TODO: Currently this script is for a specific use case. It assumes a boot
# partition, and there is no support for swap partitions. It may possibly make
# more assumptions. It should be made more general.
#
################################################################################

# Enable strict shell mode
set -o errexit
set -o nounset

################################################################################
#
# Install script creator parameters
#
# See environment parameters below for additional parameters.
#
################################################################################

# The disk image
IMAGE=${IMAGE}

# The bitbake working directory
WORKDIR=${WORKDIR}

# Name of the installer script placed in the boot partition
INSTALL_SCRIPT_NAME=${INSTALL_SCRIPT_NAME}

# TODO: Verify disk geometry parameters are multiples of mebibytes. For now,
# this seems to be the case.
#
# Mebibytes are desireable because on Yocto, dd is provided by busybox, and
# unlike coreutils, all writes are done synchronously. Writing in 512-byte
# sections is extremely slow; 1MiB sections is much faster.

# Derive disk geometry in MiB
BOOT_PART_START_MB=$(( ${BOOT_PARTITION_START} / (1024 * 1024) ))
PART_A_START_MB=$(( ${PARTITION_A_START} / (1024 * 1024) ))
PART_B_START_MB=$(( ${PARTITION_B_START} / (1024 * 1024) ))

BOOT_PART_SIZE_MB=$(( ${PART_A_START_MB} - ${BOOT_PART_START_MB} ))
PART_A_SIZE_MB=$(( ${PART_B_START_MB} - ${PART_A_START_MB} ))

# Constant defining the size of 512-byte sectors
SECTOR_SIZE=512

################################################################################
#
# Start of install script
#
################################################################################

# Create installer
cat > "${WORKDIR}/${INSTALL_SCRIPT_NAME}" <<EOF
#!/bin/sh

################################################################################
#
# System installer
#
################################################################################

# Enable strict shell mode
set -o errexit
set -o nounset

################################################################################
#
# Environment parameters
#
################################################################################

# Runtime device path of the system disk
STORAGE_DEVICE=${STORAGE_DEVICE}

# Runtime device path of the install disk
INSTALL_DEVICE=${INSTALL_DEVICE}

# Partition table type used to partition the install disk
PARTITION_TABLE_TYPE=${PARTITION_TABLE_TYPE}

# Label of the install disk data partition
DATA_PARTITION_LABEL=${DATA_PARTITION_LABEL}

# Runtime mount point of the data partition
DATA_MOUNT=${DATA_MOUNT}

# Runtime mount point of the installed boot partition
INSTALL_BOOT_MOUNT=${INSTALL_BOOT_MOUNT}

# Runtime mount point of the installed data partition
INSTALL_DATA_MOUNT=${INSTALL_DATA_MOUNT}

# Check if install disk is provided
if [ -z "\${INSTALL_DEVICE}" ]; then
  echo "To use this script, set MENDER_INSTALL_DEVICE in your bitbake project"
  exit 1
fi

# Disk geometry defined by the build system
BOOT_PARTITION_START=${BOOT_PARTITION_START}
BOOT_PARTITION_END=${BOOT_PARTITION_END}
PARTITION_A_START=${PARTITION_A_START}
PARTITION_A_END=${PARTITION_A_END}
PARTITION_B_START=${PARTITION_B_START}
PARTITION_B_END=${PARTITION_B_END}
DATA_PARTITION_START=${DATA_PARTITION_START}
DATA_PARTITION_END=${DATA_PARTITION_END}

# Disk geometry in MiB
BOOT_PART_START_MB=${BOOT_PART_START_MB}
BOOT_PART_SIZE_MB=${BOOT_PART_SIZE_MB}
PART_A_START_MB=${PART_A_START_MB}
PART_A_SIZE_MB=${PART_A_SIZE_MB}
PART_B_START_MB=${PART_B_START_MB}

# Constant defining the size of 512-byte sectors
SECTOR_SIZE=${SECTOR_SIZE}

# Disk geometry in units of 512-byte sectors
BOOT_PART_START_SECTORS=$(( ${BOOT_PARTITION_START} / ${SECTOR_SIZE} ))
BOOT_PART_END_SECTORS=$(( ${BOOT_PARTITION_END} / ${SECTOR_SIZE} ))
PART_A_START_SECTORS=$(( ${PARTITION_A_START} / ${SECTOR_SIZE} ))
PART_A_END_SECTORS=$(( ${PARTITION_A_END} / ${SECTOR_SIZE} ))
PART_B_START_SECTORS=$(( ${PARTITION_B_START} / ${SECTOR_SIZE} ))
PART_B_END_SECTORS=$(( ${PARTITION_B_END} / ${SECTOR_SIZE} ))
DATA_PART_START_SECTORS=$(( ${DATA_PARTITION_START} / ${SECTOR_SIZE} ))
DATA_PART_END_SECTORS=$(( ${DATA_PARTITION_END} / ${SECTOR_SIZE} ))

################################################################################
#
# Install procedure
#
################################################################################

#
# Wake the eMMC. Before adding this, writing the disk label would produce the
# following kernel errors and break the install:
#
# [   38.274535] mmc1: cache flush error -110
# [   38.279509] print_req_error: I/O error, dev mmcblk1, sector 0
#
dd if="\${INSTALL_DEVICE}" of="/dev/null" bs=512 count=1

# Copy the bootloaded and SPL, if present, embedded in the space before the
# boot partition
dd if="\${STORAGE_DEVICE}" \\
  of="\${INSTALL_DEVICE}" \\
  bs=1M \\
  count=\${BOOT_PART_START_MB}

# Write a partition table to the disk
parted -s "\${INSTALL_DEVICE}" mklabel "\${PARTITION_TABLE_TYPE}"
sync

# Create boot partition 1
parted -s "\${INSTALL_DEVICE}" -a min unit s mkpart primary fat32 "\${BOOT_PART_START_SECTORS}" "\${BOOT_PART_END_SECTORS}"
sync
parted -s "\${INSTALL_DEVICE}" set 1 boot on
sync

# Create partition A
parted -s "\${INSTALL_DEVICE}" -a min unit s mkpart primary ext4 "\${PART_A_START_SECTORS}" "\${PART_A_END_SECTORS}"
sync

# Create partition B
parted -s "\${INSTALL_DEVICE}" -a min unit s mkpart primary ext4 "\${PART_B_START_SECTORS}" "\${PART_B_END_SECTORS}"
sync

# Create data partition
parted -s "\${INSTALL_DEVICE}" -a min unit s mkpart primary ext4 "\${DATA_PART_START_SECTORS}" "\${DATA_PART_END_SECTORS}"
sync

# Copy boot partition
dd if="\${STORAGE_DEVICE}" \\
  of="\${INSTALL_DEVICE}" \\
  bs=1M \\
  skip=\${BOOT_PART_START_MB} \\
  seek=\${BOOT_PART_START_MB} \\
  count=\${BOOT_PART_SIZE_MB}

# Check boot partition (doesn't work for GPT partitions)
if [ "\${PARTITION_TABLE_TYPE}" == "msdos" ]; then
  fsck.fat -a "\${INSTALL_DEVICE}p1" || true
fi

# Until U-Boot can pass disk context to GRUB, we need to manually update
# grub.cfg to pass the correct disk to the kernel
mkdir -p "\${INSTALL_BOOT_MOUNT}"
mount "\${INSTALL_DEVICE}p1" "\${INSTALL_BOOT_MOUNT}"
INSTALL_GRUB_CFG="\${INSTALL_BOOT_MOUNT}/EFI/BOOT/grub.cfg"
sed -i "s#\${STORAGE_DEVICE}#\${INSTALL_DEVICE}#g" "\${INSTALL_GRUB_CFG}"
umount "\${INSTALL_BOOT_MOUNT}"
rm -rf "\${INSTALL_BOOT_MOUNT}"

# Copy partition B twice (assumes we are booted from partition A)
for dest in \${PART_A_START_MB} \${PART_B_START_MB}; do
  dd if="\${STORAGE_DEVICE}" \\
    of="\${INSTALL_DEVICE}" \\
    bs=1M \\
    skip=\${PART_B_START_MB} \\
    seek=\${dest} \\
    count=\${PART_A_SIZE_MB}
done

# Check A/B filesystems
e2fsck -n "\${INSTALL_DEVICE}p2"
e2fsck -n "\${INSTALL_DEVICE}p3"

# Create filesystem on data partition
mke2fs -F -q -t ext4 -m 0 "\${INSTALL_DEVICE}p4"
tune2fs -L "\${DATA_PARTITION_LABEL}" "\${INSTALL_DEVICE}p4"
sync
e2fsck -n "\${INSTALL_DEVICE}p4"

# Copy files to data partition
mkdir -p "\${INSTALL_DATA_MOUNT}"
mount "\${INSTALL_DEVICE}p4" "\${INSTALL_DATA_MOUNT}"
cp -r "\${DATA_MOUNT}"/* "\${INSTALL_DATA_MOUNT}"
umount "\${INSTALL_DATA_MOUNT}"
rm -rf "\${INSTALL_DATA_MOUNT}"
sync
EOF

################################################################################
#
# End of install script
#
################################################################################

# Extract boot partition
dd if="${IMAGE}" \
  of="${WORKDIR}/boot_partition.fat" \
  bs=1M \
  skip=${BOOT_PART_START_MB} \
  count=${BOOT_PART_SIZE_MB}

# Copy installer to extracted boot partition
mcopy -i "${WORKDIR}/boot_partition.fat" -s "${WORKDIR}/${INSTALL_SCRIPT_NAME}" ::/

# Merge boot partition back to disk image
dd if="${WORKDIR}/boot_partition.fat" \
  of="${IMAGE}" \
  bs=1M \
  seek=${BOOT_PART_START_MB} \
  count=${BOOT_PART_SIZE_MB} \
  conv=notrunc
