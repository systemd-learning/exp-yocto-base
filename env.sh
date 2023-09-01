#!/bin/sh

CWD=`pwd`
PROGNAME="env.sh"
PACKAGE_CLASSES=${PACKAGE_CLASSES:-package_rpm}

usage()
{
    echo -e "
Usage: MACHINE=<machine> DISTRO=<distro> source $PROGNAME <build-dir>
Usage:                                   source $PROGNAME <build-dir>
    <machine>    machine name
    <distro>     distro name
    <build-dir>  build directory

Examples:

- To create a new Yocto build directory:
  $ MACHINE=soc-demo-01 DISTRO=distro-demo-01 source $PROGNAME build

- To use an existing Yocto build directory:
  $ source $PROGNAME build
"
}

clean()
{
   unset LIST_MACHINES VALID_MACHINE
   unset CWD TEMPLATES SHORTOPTS LONGOPTS ARGS PROGNAME
   unset generated_config updated
   unset MACHINE DISTRO OEROOT
}

# get command line options
SHORTOPTS="h"
LONGOPTS="help"

ARGS=$(getopt --options $SHORTOPTS  \
  --longoptions $LONGOPTS --name $PROGNAME -- "$@" )
# Print the usage menu if invalid options are specified
if [ $? != 0 -o $# -lt 1 ]; then
   usage && clean
   return 1
fi

eval set -- "$ARGS"
while true;
do
    case $1 in
        -h|--help)
           usage
           clean
           return 0
           ;;
        --)
           shift
           break
           ;;
    esac
done

if [ "$(whoami)" = "root" ]; then
    echo "ERROR: do not use the BSP as root. Exiting..."
fi

if [ ! -e $1/conf/local.conf.sample ]; then
    build_dir_setup_enabled="true"
else
    build_dir_setup_enabled="false"
fi

if [ "$build_dir_setup_enabled" = "true" ] && [ -z "$MACHINE" ]; then
    usage
    echo -e "ERROR: You must set MACHINE when creating a new build directory."
    clean
    return 1
fi

if [ "$build_dir_setup_enabled" = "true" ] && [ -z "$DISTRO" ]; then
    usage
    echo -e "ERROR: You must set DISTRO when creating a new build directory."
    clean
    return 1
fi

OEROOT=$PWD/sources/poky
if [ -e $PWD/sources/oe-core ]; then
    OEROOT=$PWD/sources/oe-core
fi

. $OEROOT/oe-init-build-env $CWD/$1 > /dev/null

# if conf/local.conf not generated, no need to go further
if [ ! -e conf/local.conf ]; then
    clean && return 1
fi

# Clean up PATH, because if it includes tokens to current directories somehow,
# wrong binaries can be used instead of the expected ones during task execution
export PATH="`echo $PATH | sed 's/\(:.\|:\)*:/:/g;s/^.\?://;s/:.\?$//'`"

generated_config=
if [ "$build_dir_setup_enabled" = "true" ]; then
    mv conf/local.conf conf/local.conf.sample

    # Generate the local.conf based on the Yocto defaults
    TEMPLATES=$CWD/sources/base/conf 
    grep -v '^#\|^$' conf/local.conf.sample > conf/local.conf
    cat >> conf/local.conf <<EOF

DL_DIR ?= "\${DEMODIR}/downloads/"
EOF
    # Change settings according environment
    sed -e "s,MACHINE ??=.*,MACHINE ??= '$MACHINE',g" \
        -e "s,DISTRO ?=.*,DISTRO ?= '$DISTRO',g" \
        -e "s,PACKAGE_CLASSES ?=.*,PACKAGE_CLASSES ?= '$PACKAGE_CLASSES',g" \
        -i conf/local.conf

    cp $TEMPLATES/* conf/

    generated_config=1
fi

if [ -n "$generated_config" ]; then
    cat <<EOF
Your build environment has been configured with:

    MACHINE=$MACHINE
    DISTRO=$DISTRO
    EULA=$EULA
EOF
else
    echo "Your configuration files at $1 have not been touched."
fi

clean
