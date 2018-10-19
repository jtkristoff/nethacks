#!/bin/sh

# This script is designed to pcap on a single named interface.
# This script is typically run in a crontab.  It runs continuously
# so you only need to make sure it'll start-up if the system has
# been restarted.  An example crontab entry to ensure its running at
# least once per day at 0600:
#
#   0 6 * * *  /usr/local/bin/pcapr.sh -i eth0
#
# Requirements:
#   tcpdump     https://www.tcpdump.org/
#   pcap-split  https://github.com/wessels/pcap-tools

#  Uncomment for debugging.
#set -x

usage() {
    echo "$0 -i interface [ -d basedir ] [ -s snaplen ] [ 'libpcap bpf' ]"
}

# parse command line options
while getopts d:i:s: options
do
    case ${options} in
        d)    PREFIX=${OPTARG}
              ;;
        i)    IFACE=${OPTARG}
              ;;
        s)    SNAPLEN=${OPTARG}
              ;;
        *)    usage
              exit 1
              ;;
    esac
done
shift `expr ${OPTIND} - 1`

# required options
if [ -z ${IFACE} ]
then
    usage
    exit 1
fi

# other options
SNAPLEN=${SNAPLEN:-0}

#  tcpdump regex (required).  Default to DNS over UDP answers.
BPF=${1:-'src port 53 and udp[10:2]>>15 == 1'}

#  Default is probably safe unless you run as root. (required)
RUNAS=${USER:-pcapr}

#  Writeable files / directories. (required)
WORKDIR=${PREFIX:-${HOME}/pcapr}/${IFACE}
PCAPDIR=${WORKDIR}/pcap
FIFO=${WORKDIR}/fifo
TMPDIR=${WORKDIR}/tmp
PIDFILE=${WORKDIR}/pcapr.pid
DISABLED=${WORKDIR}/pcapr.DISABLED
SPLIT_FILE=${TMPDIR}/%Y%m%d%H%M-${IFACE}.pcap
SPLIT_PIDFILE=${WORKDIR}/split.pid
# we will adjust this if passed an iface option on the command line
TCPDUMP_PIDFILE=${WORKDIR}/tcpdump.pid
#
#  This should work for most installations. (required)
TCPDUMP=/usr/sbin/tcpdump
#
#  get pcap-split @ https://github.com/wessels/pcap-tools (required)
#
SPLIT=/usr/local/bin/pcap-split
#
#  pcap-split will pass a completed pcap file name as an argument
#  to a command at the end of an interval.  If not using bash, you
#  will may need to write a script that will move the file passed to
#  it to ${PCAPDIR}.  (required)
POST_SPLIT_CMD="/bin/mv --target-directory ${PCAPDIR}"
#
#  gzip in Linux tends to be in /bin, BSD in /usr/bin.  (required)
GZIP=/bin/gzip
#
#  pcap-split interval. Avoid changing. (required)
INTERVAL=900
#
# After how many days should we purge old pcap files? (required)
PURGE_DAYS=7
#
# Avoid changing.  (required)
DEFAULT_ERROR='Unknown error'
DEFAULT_WARNING='Unknowning warning'
#
#  Uncomment and set the path if you run tcpdump with sudo (optional)
#SUDO=/usr/bin/sudo
#
#  Under SELinux RBAC commands in sudo are invoked sesh.  This alters
#  how the process appears to the sudo user.  This is only common if
#  you are using RBAC commands and running under CentOS/RedHat
#  distributions.  Uncomment the following if SESH is used with sudo
#  on your system. (optional)
#SESH=YES

# UTC timestamps, ensure system time is NTP sync'd and reliable
TZ=UTC
export TZ

#  Set group permissions.  Generally want group write.
umask 002

# abnormal event subroutines, pass custom message as first param
warning() {
    echo ${1:-${DEFAULT_WARNING}} >&2
}
error() {
    echo ${1:-${DEFAULT_ERROR}} >&2 
    exit 1
}

# quit if we are disabled
if test -r ${DISABLED}
then
    error "script disabled, remove file to enable: ${DISABLED}"
fi

# make sure directories and fifo exist
if test ! -d ${WORKDIR}
then
    mkdir -p ${WORKDIR}  || error "mkdir: ${WORKDIR}"
fi
if test ! -d ${PCAPDIR}
then
    mkdir -p ${PCAPDIR} || error "mkdir: ${PCAPDIR}"
fi
if test ! -d ${TMPDIR}
then
    mkdir -p ${TMPDIR} || error "mkdir: ${TMPDIR}"
fi
if test ! -p ${FIFO}
then
    mkfifo ${FIFO} || error "mkfifo: ${FIFO}"
fi

# quit if we are already running
if test -r ${PIDFILE}
then
    if [ "$(ps -p `cat ${PIDFILE}` | wc -l)" -gt 1 ]
    then
        # This script should always be running, uncomment to be alerted:
        # error "script already running"
        exit 1
    else
        # orphaned pid file
        rm ${PIDFILE}
    fi
fi

# put our process id into a file
echo -n $$ > ${PIDFILE}
if test ! -r ${PIDFILE}
then
    error "pidfile creation error: ${PIDFILE}"
fi

# start up the pcap-split process (pipe output)
${SPLIT} -t ${INTERVAL} -f ${SPLIT_FILE} -k "${POST_SPLIT_CMD}" -z < ${FIFO} &
_RV=$?
sleep 1
if [ "${_RV}" -ne 0 ]
then
    error "pcap-split not started"
else
    echo -n $! > ${SPLIT_PIDFILE}
fi
_RV=

# start up the tcpdump process (pipe input)
# NOTE: -qq is from a custom patch to tcpdump that prevents some status
#       messages from being sent to stderr.  Use of this option should
#       not interfere with ordinary releases of tcpdump, but you will
#       probably get extraneous messages from crontab when the script
#       exits since tcpdump sends some messgaes to stderr by default.
if [ x"${SUDO}" = x ]
then
    ${TCPDUMP} -qq -s ${SNAPLEN} -Z ${RUNAS} -w- -i ${IFACE} ${BPF} > ${FIFO} &
else
    ${SUDO} ${TCPDUMP} -qq -s ${SNAPLEN} -Z ${RUNAS} -w- -i ${IFACE} ${BPF} > ${FIFO} &
fi
_RV=$?
sleep 1
if [ "${_RV}" -ne 0 ]
then
    error "pcap not started"
else
   if [ x"${SESH}" = xYES ]
   then
       ps --ppid $! -o pid= > ${TCPDUMP_PIDFILE}
   else
       echo -n $! > ${TCPDUMP_PIDFILE}
   fi
fi
_RV=

# this loop allows us to gracefully halt or perform periodic maintenance
while :
do
    sleep ${INTERVAL}
    # touch ${WORKDIR}/pcapr.DISABLED to halt
    if test -r ${DISABLED}
    then
        break
    fi
    # remove old files
    find ${PCAPDIR} -type f -mtime +${PURGE_DAYS} -print | xargs rm -f
    find ${TMPDIR}  -type f -mtime +${PURGE_DAYS} -print | xargs rm -f
done

# stop the tcpdump process
kill `cat ${TCPDUMP_PIDFILE}`
_RV=$?
sleep 1
if [ "${_RV}" -ne 0 ]
then
    echo "WARNING: pcap not killed!"
else
    rm ${TCPDUMP_PIDFILE} ||
        error "tcpdump pidfile removal error: ${TCPDUMP_PIDFILE}"
fi
_RV=

# pcap-split attached to fifo should have died automatically
rm ${FIFO} || error "fifo removal error: ${FIFO}"
rm ${SPLIT_PIDFILE} ||
    error "pcap-split pidfile removal error: ${SPLIT_PIDFILE}"

rm ${PIDFILE} || error "pid file removal error: ${PIDFILE}"

exit 0
