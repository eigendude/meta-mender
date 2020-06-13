################################################################################
# A recipe that provides precompiled binaries for ARMv5 for:
# * The grub-efi-bootarm.efi EFI bootloader
#
# The motivation for this recipe is that GRUB doesn't compile correctly under
# some ARM configurations, most notable ARMv7. However an ARMv5 binary will run
# just fine even on ARMv7, but is difficult to compile using an ARMv7 toolchain.
# Hence this recipe.
#
# If a recompile is needed to update the supplied binaries, any ARMv5 target
# should work, but a pretty straightforward way is using meta-mender's
# vexpress-qemu MACHINE type and compiling grub-efi. Then grab the resulting
# binaries from the deploy directory, and replace the precompiled binaries
# supplied alongside this recipe.
################################################################################

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

LICENSE = "GPL-3.0"

S = "${WORKDIR}/src"

LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/GPL-3.0;md5=c79ff39f19dfec6d293b95dea7b07891"

PROVIDES = "grub-efi"
RPROVIDES_${PN} = "grub-efi"

URL_BASE ?= "https://d1b0l86ne08fsf.cloudfront.net/grub-mender-grubenv/grub-efi"
GRUB_MENDER_GRUBENV_REV = "aa7e8f8c76c6aca6dca1820aaa42dc2cbf9762a1"

SRC_URI_append_arm = " \
    ${URL_BASE}/${PV}-grub-mender-grubenv-${GRUB_MENDER_GRUBENV_REV}/arm/grub-efi-bootarm.efi;md5sum=7ec4b336f333f45abec86f6193326226 \
"

GRUB_BUILDIN = "boot linux ext2 fat serial part_msdos part_gpt normal \
                efi_gop iso9660 configfile search loadenv test \
                cat echo gcry_sha256 halt hashsum sleep reboot regexp \
                loadenv test"

COMPATIBLE_HOSTS = "arm"

inherit deploy

do_configure() {
    if [ "${KERNEL_IMAGETYPE}" = "uImage" ]; then
        bbfatal "GRUB is not compatible with KERNEL_IMAGETYPE = uImage. Please change it to either zImage or bzImage."
    fi
}

do_deploy() {
    install -m 644 ${WORKDIR}/grub-efi-bootarm.efi ${DEPLOYDIR}/
}
addtask do_deploy after do_patch

INSANE_SKIP_${PN} = "already-stripped"
