#!/bin/sh

# script that gets and updates IPv4 and IPv6 bogon lists from Team Cymru

# enable for debugging
#set -x

# set group permissions
umask 022

WORKDIR=${HOME}/data/bogons
DSTDIR=${HOME}/etc
DST_BOGONS=${DSTDIR}/fullbogons-ipv4.txt
DST_BOGONS6=${DSTDIR}/fullbogons-ipv6.txt
SRC_BOGONS=https://team-cymru.org/Services/Bogons/fullbogons-ipv4.txt
SRC_BOGONS6=https://team-cymru.org/Services/Bogons/fullbogons-ipv6.txt
PID=$$
PIDFILE=${WORKDIR}/bogons.pid
DISABLED=${WORKDIR}/bogons.DISABLED
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

# BOGONS
TMPFILE=${WORKDIR}/`basename ${DST_BOGONS}`.${PID}
SRCFILE=${SRC_BOGONS}
DSTFILE=${DST_BOGONS}
${CURL} -k -s -S -o ${TMPFILE} ${SRCFILE}
if [ "$?" -ne 0 ]
then
    error "curl ${SRCFILE} failed"
fi
cp ${TMPFILE} ${DSTFILE} || error "cp ${TMPFILE} failed"
rm ${TMPFILE}

# BOGONS6
TMPFILE=${WORKDIR}/`basename ${DST_BOGONS6}`.${PID}
SRCFILE=${SRC_BOGONS6}
DSTFILE=${DST_BOGONS6}
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
