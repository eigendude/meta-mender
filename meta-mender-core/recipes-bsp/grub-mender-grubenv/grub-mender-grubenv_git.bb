include grub-mender-grubenv.inc

SRC_URI = "git://github.com/mendersoftware/grub-mender-grubenv;protocol=https;branch=master"

SRCREV = "aa7e8f8c76c6aca6dca1820aaa42dc2cbf9762a1"
PV = "1.3.0+git${SRCREV}"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=7fd64609fe1bce47db0e8f6e3cc6a11d"
