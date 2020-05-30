do_install_append_mender-systemd() {
    # Versions of Mender client after 2.2 come with the service file called
    # "mender-client" by default, but we don't want to change this in a stable
    # Yocto branch, so for warrior and older we do this rename back to the old
    # name "mender".
    if [ -e ${D}${systemd_unitdir}/system/mender-client.service ]; then
        mv ${D}${systemd_unitdir}/system/mender-client.service ${D}${systemd_unitdir}/system/mender.service
    fi
}

def mender_is_2_2_or_older(d):
    # Due to some infinite recursion we can only check PV when using a non-git
    # recipe, and to detect this we check MENDER_BRANCH, which is only available
    # for Git recipes.
    version = d.getVar('MENDER_BRANCH')
    if not version:
        version = d.getVar('PV')
    if (
        version.startswith("1.")
        or version.startswith("2.0.")
        or version.startswith("2.1.")
        or version.startswith("2.2.")
    ):
        return True
    else:
        return False
# This is needed for all 2.3 and later client versions, on warrior and older.
SRC_URI_append_mender-systemd = "${@'' if mender_is_2_2_or_older(d) else ' file://0001-MEN-3277-Fix-check-update-and-send-inventory-options.patch'}"

#
# eMMC Installer
#

RDEPENDS_${PN}_append_beaglebone_mender-systemd = " sed"

SRC_URI_append_beaglebone_mender-systemd = " \
    file://mender-update-uboot.sh.in \
    file://mender-update-uboot.service \
"

FILES_${PN}_append_beaglebone_mender-systemd = " \
    ${bindir}/mender-update-uboot \
    ${systemd_unitdir}/system/mender-update-uboot.service \
    ${systemd_unitdir}/system/data.mount.wants/mender-update-uboot.service \
"

do_install_append_beaglebone_mender-systemd() {
    sed -i "s#@MENDER_STORAGE_DEVICE@#${MENDER_STORAGE_DEVICE}#g" \
        ${WORKDIR}/mender-update-uboot.sh.in

    sed -i "s#@MENDER_INSTALL_DEVICE@#${MENDER_INSTALL_DEVICE}#g" \
        ${WORKDIR}/mender-update-uboot.sh.in

    install -m 0755 ${WORKDIR}/mender-update-uboot.sh.in \
        ${D}/${bindir}/mender-update-uboot

    install -d ${D}/${systemd_unitdir}/system
    install -m 644 ${WORKDIR}/mender-update-uboot.service ${D}/${systemd_unitdir}/system/

    install -d ${D}${systemd_unitdir}/system/data.mount.wants/
    ln -sf ../mender-update-uboot.service ${D}${systemd_unitdir}/system/data.mount.wants/
}
