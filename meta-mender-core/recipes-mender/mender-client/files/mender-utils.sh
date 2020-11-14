#!/bin/sh

################################################################################
#
# Utility library for functions used by mender scripts
#
################################################################################

# Reads the "root" parameter passed in the kernel command line
function read_root_device() {
    root_device=

    [ -z "${CMDLINE+x}" ] && CMDLINE=`cat /proc/cmdline`
    for arg in ${CMDLINE}; do
        # Set optarg to option parameter, and '' if no parameter was given
        optarg=`expr "x$arg" : 'x[^=]*=\(.*\)' || echo ''`
        case $arg in
            root=*)
                root_device=$optarg
                ;;
        esac
    done

    #
    # Fall back to grepping mount if kernel is booted with a PARTUUID partition
    # identifier, e.g.:
    #
    #   root=PARTUUID=976ff3fd-e86a-4a42-942b-eb7527ae9590
    #
    if [[ $root_device =~ "PARTUUID" ]]; then
        root_device=$(mount | grep ' / ' | cut -d' ' -f 1)
    fi

    echo $root_device
}
