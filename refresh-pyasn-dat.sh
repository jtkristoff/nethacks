#!/bin/sh

# This script runs the PyASN utility to download a current MRT RIB from
# RouteViews.  It stores the file in an archive directory, updates a soft
# link to this current file.  This file is heavily dependent on the the
# PyASN utility and a couple of customizations that remove extraneous
# output and spits out the current file name for linking.  Also note,
# the downloaded file is expected to be bzip2 compressed.  So yes, this
# is a little fragile if something upstream changes.  Some checks are
# included so that it should fail if anything goes horribly wrong.

# uncomment for debugging
#set -x

DATADIR=${HOME}/data/pyasn
DOWNLOAD=~/.local/bin/pyasn_util_download.py
DOWNLOAD_ARGS="--latestv46"
CONVERT=~/.local/bin/pyasn_util_convert.py
CONVERT_ARGS="--no-progress"
YYYYMM=`date +%Y%m`

# non-critical error
warning() {
    echo ${1:-"Unknown error, continuing..."} >&2
}
# critical failure
fatal() {
    echo ${1:-"Unknown failure, exiting..."} >&2
    exit 1
}

# store in archive directory
if test ! -d ${DATADIR}/${YYYYMM}
then
    mkdir -p ${DATADIR}/${YYYYMM} || fatal "Unable to mkdir ${DATADIR}/${YYYYMM}"
fi

# downloads to current directory
cd ${DATADIR}/${YYYYMM}

# spits out filename to stdout
RIB_FILE=`${DOWNLOAD} ${DOWNLOAD_ARGS}`
if [ $? -ne 0 ]
then
    fatal "failed to download: ${DOWNLOAD}  ${DOWNLOAD_ARGS}"
fi

# an additional check that this is a compressed file as expected
bunzip2 -t ${RIB_FILE}
if [ $? -ne 0 ]
then
    fatal "failed to verify decompression: ${RIB_FILE}"
fi

# convert MRT RIB to PyASN .dat file
DAT_FILE=`basename ${RIB_FILE} .bz2`.dat
${CONVERT} ${CONVERT_ARGS} --single ${RIB_FILE} ${DAT_FILE}
if [ $? -ne 0 ]
then
    fatal "failed to convert rib to pyasn .dat: ${CONVERT} ${CONVERT_ARGS} --single ${RIB_FILE} ${DAT_FILE}"
fi

# set the soft links
cd ${DATADIR}
ln -sf ${YYYYMM}/${DAT_FILE} pyasn.current.dat
ln -sf ${YYYYMM}/${RIB_FILE} rib.current.bz2

exit 0
