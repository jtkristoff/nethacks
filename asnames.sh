#!/bin/sh

# $Id: $
# script that gets and updates AS numbers and names from RIPE

# enable for debugging
#set -x

# set group permissions
umask 022

WORKDIR=${HOME}/data/asnames
DSTDIR=${HOME}/etc
DST_ASNAMES=${DSTDIR}/asnames.txt
SRC_ASNAMES=https://ftp.ripe.net/ripe/asnames/asn.txt
PID=$$
PIDFILE=${WORKDIR}/asnames.pid
DISABLED=${WORKDIR}/asnames.DISABLED
PURGE_TIME=7
CURL=/usr/bin/curl

warning() {
    echo ${1:-${DEFAULT_WARNING}} >&2
}

error() {
    echo ${1:-${DEFAULT_ERROR}} >&2
    exit 1
}

# quit if we are already running
if test -r ${PIDFILE}
then
    if [ "$(ps -p `cat ${PIDFILE}` | wc -l)" -gt 1 ]
    then
        error "script already running"
    else
        # orphaned pid file
        rm ${PIDFILE}
    fi
fi

# quit if we are disabled
if test -r ${DISABLED}
then
    error "script disabled, remove file to enable: ${DISABLED}"
fi

# make sure work directories exist
if test ! -d ${WORKDIR}
then
    mkdir -p ${WORKDIR}  || error "mkdir: ${WORKDIR}"
fi
if test ! -d ${DSTDIR}
then
    mkdir -p ${DSTDIR} || error "mkdir: ${DSTDIR}"
fi

echo $$ > ${PIDFILE}
if test ! -r ${PIDFILE}
then
    error "pidfile creation error: ${PIDFILE}"
fi

# ASNAMES
TMPFILE=${WORKDIR}/`basename ${DST_ASNAMES}`.${PID}
SRCFILE=${SRC_ASNAMES}
DSTFILE=${DST_ASNAMES}
${CURL} -k -s -S -o ${TMPFILE} ${SRCFILE}
if [ "$?" -ne 0 ]
then
    error "curl ${SRCFILE} failed"
fi
cp ${TMPFILE} ${DSTFILE} || error "cp ${TMPFILE} failed"
rm ${TMPFILE}

# remove old work files if any exist
find ${WORKDIR} -type f -mtime +${PURGE_TIME} -print | xargs rm -f

# clean up and exit
rm ${PIDFILE}
exit 0
