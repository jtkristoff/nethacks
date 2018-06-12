#!/bin/sh

# gpg-ring-check
# examine a GnuPG public key ring for expiring, expired, revoked keys
# $Revision: 71 $
# $Date: 2011-12-02 14:31:07 -0600 (Fri, 02 Dec 2011) $
#
# Dragon Research Group (DRG) - <http://dragonresearchgroup.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# enable for debugging
#set -x

# default location for GnuPG public key ring file
pubringfile=~/.gnupg/pubring.gpg

# look for revoked keys
check_revoked () {
    keys=`gpg --with-colons \
              --list-keys \
              --no-default-keyring \
              --keyring $pubringfile |
              grep "^pub:r:" |
              cut -d":" -f6,10 |
              tr ':' '\t' |
              sort -nr`

    if [ -n "$keys" ]
    then
        echo "# REVOKED KEYS on $pubringfile"
        echo "# Date:         Key"
        echo "$keys"
    fi
}

# look for expired keys
check_expired () {
    keys=`gpg --with-colons \
              --list-keys \
              --no-default-keyring \
              --keyring $pubringfile |
              grep "^pub:e:" |
              cut -d":" -f6,10 |
              tr ':' '\t' |
              sort -nr`

    if [ -n "$keys" ]
    then
        echo "# EXPIRED KEYS on $pubringfile"
        echo "# Date:         Key"
        echo "$keys"
    fi
}

# look for expiring keys in x days
# What about to create a temp file with gpg output
# and delete this file after the function is completed?
check_expiring () {
    expiry=$1
    today=`date +%s`
    exp_date=`expr 86400 \* $expiry \+ $today`
    header=

    while read line
    do 
       key_exp_date=`echo $line | cut -d ":" -f 7`
       key_not_expired=`echo $line | cut -d ":" -f 2`
       key_exp_date2=`echo $key_exp_date | sed -n '/^[0-9]*\-[0-9]*\-[0-9]*$/p'`

       # XXX: portable?
       if [ -n "$key_exp_date2" ] && [ "$key_not_expired" != 'e' ]
       then
          unix_exp_date=`date -d $key_exp_date2 +%s`

	  if [ "$unix_exp_date" -lt "$exp_date" ]
          then
              # XXX: too hacky
              if [ x"$header" = x ]
              then
                  echo "# EXPIRING KEYS on $pubringfile"
                  echo "# Date:         Key"
                  header=1
              fi
              echo -n "$key_exp_date      "
              echo `echo $line | cut -d":" -f10`
          fi

       fi
    done <<-EOF_KEYS
       `gpg --with-colons \
            --list-keys \
            --no-default-keyring \
            --keyring $pubringfile |
            grep ^pub |
            sort -k6 -r -t:`
EOF_KEYS
}

# validate the pubring file path
check_file ()
{
    # XXX: why is this test necesary?
    # ANSWER: Because it's required an absolute (starting with /) 
    # or relative path (./)
    # If the user doesn't give in this way, this function
    # puts a './' in the file path

    testpath=`echo $pubringfile | sed -n '/^\.\/\|^\//p'` 

    if [ -z "$testpath" ]
    then
        pubringfile="./$pubringfile"
    fi

    if [ ! -e $pubringfile ]
    then
        echo "File $pubringfile does not exist!"
        exit 1
    fi
}

usage()
{
    echo "Usage: $0 [-a days] [-f pubring_file] [-x days] [-r] [-d] [-h]"
    echo "-a days        : perform all checks on begining X days from now"
    echo "-f pubring     : file path to pubring.gpg [default is ~/.gnupg/pubring.gpg]"
    echo "-x days        : check for keys expiring X days from now"
    echo "-r             : check for revoked keys"
    echo "-d             : check for expired keys"
    echo "-h             : Print this help screen"
}

# checks to perform
_chk_all=
_chk_expired=
_chk_expiring=
_chk_revoked=

while getopts "a:df:hrx:" OPT
do
    case $OPT in
        a) _chk_expiring=$OPTARG
           _chk_all=1
           ;;

        d) _chk_expired=1
           ;;

        r) _chk_revoked=1
           ;;

        x) # don't overwrite var if already set
           _chk_expiring=${_chk_expiring:=$OPTARG}
           ;;

        f) pubringfile=$OPTARG
           ;;

        h) usage
           exit 0
           ;;

        *) usage
           exit 1
           ;;
    esac
done

# make sure at least one check is enabled
CHECKS=${_chk_all}${_chk_expired}${_chk_revoked}${_chk_expiring}
if [ -z "$CHECKS" ]
then
   usage
   exit 1
fi   

check_file

_chk_expiring=`echo $_chk_expiring | sed -n '/^[0-9]*$/p'`

if [ -n "$_chk_all" ]
then 
   if [ -n "$_chk_expiring" ]
   then 
       check_expired
       check_revoked
       check_expiring $_chk_expiring
   else
       usage
       exit 1
   fi
   # do not perform any other tests again
   exit 0
fi

if [ -n "$_chk_expiring" ]
then 
       check_expiring $_chk_expiring
fi

if [ -n "$_chk_expired" ]
then
    check_expired
fi

if [ -n "$_chk_revoked" ]
then
    check_revoked
fi

exit 0
