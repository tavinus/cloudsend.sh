#!/usr/bin/env bash

############################################################
#
# cloudsend.sh
# https://github.com/tavinus/cloudsend.sh
#
# Uses curl to send files to a shared
# Nextcloud/Owncloud folder
#
# Usage: ./cloudsend.sh <file> <folderLink>
# Help:  ./cloudsend.sh -h
#
# Gustavo Arnosti Neves
# https://github.com/tavinus
#
# Contributors:
# @MG2R @gessel
#
# Get this script to current folder with:
# curl -O 'https://raw.githubusercontent.com/tavinus/cloudsend.sh/master/cloudsend.sh' && chmod +x cloudsend.sh
#
############################################################


CS_VERSION="0.1.7"

CLOUDURL=""
FOLDERTOKEN=""

PUBSUFFIX="public.php/webdav"
HEADER='X-Requested-With: XMLHttpRequest'
INSECURE=''
OUTFILE=''

# https://cloud.mydomain.net/s/fLDzToZF4MLvG28
# curl -k -T myFile.ext -u "fLDzToZF4MLvG28:" -H 'X-Requested-With: XMLHttpRequest' https://cloud.mydomain.net/public.php/webdav/myFile.ext

log() {
	[ "$VERBOSE" == " -s" ] || printf "%s\n" "$1"
}

printVersion() {
        printf "%s\n" "CloudSender v$CS_VERSION"
}

initError() {
        printVersion >&2
        printf "%s\n" "Init Error! $1" >&2
        printf "%s\n" "Try: $0 --help" >&2
        exit 1
}

usage() {
        printVersion
        printf "\n%s%s\n" "Parameters:" "
  -h | --help      Print this help and exits
  -q | --quiet     Be quiet
  -V | --version   Prints version and exits
  -r | --rename    Changed the uploaded file name
  -k | --insecure  Uses curl with -k option (https insecure)
  -p | --password  Uses env var \$CLOUDSEND_PASSWORD as share password
                   You can 'export CLOUDSEND_PASSWORD' at your system, or set it at the call.
                   Please remeber to also call -p to use the password set."
        printf "\n%s\n%s\n" "Note:" "  Parameters must come before <filepath> <folderLink>"
        printf "\n%s\n%s\n%s\n" "Use:" "  $0 [parameters] <filepath> <folderLink>" "  CLOUDSEND_PASSWORD='MySecretPass' $0 -p <filepath> <folderLink>"
        printf "\n%s\n%s\n%s\n%s\n" "Example:" "  $0 './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'" "  $0 -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'" "   CLOUDSEND_PASSWORD='MySecretPass' $0 -p './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'"
}

##########################
# Process parameters


if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
fi

if [ "$1" = "-V" ] || [ "$1" = "--version" ]; then
        printVersion
        exit 0
fi

if [ "$1" = "-q" ] || [ "$1" = "--quiet" ]; then
        VERBOSE=" -s"
	shift
fi

if [ "$1" = "-k" ] || [ "$1" = "--insecure" ]; then
        INSECURE=' -k'
        log " > Insecure mode ON"
        shift
fi

if [ "$1" = "-p" ] || [ "$1" = "--password" ]; then
        PASSWORD=${CLOUDSEND_PASSWORD}
        log " > Using password from env"
        shift
fi

if [ "$1" = "-r" ] || [ "$1" = "--rename" ]; then
        shift
        OUTFILE=${1}
        if [ -z "$OUTFILE" ]; then
                initError "Output file name is empty!"
        fi
        log " > Output file will be renamed to \"$OUTFILE\""
        shift
fi


##########################
# Validate input

FILENAME="$1"

CLOUDURL=''
# if we have index.php in the URL, process accordingly
if [[ $2 == *"index.php"* ]]; then
        CLOUDURL="${2%/index.php/s/*}"
else
        CLOUDURL="${2%/s/*}"
fi

FOLDERTOKEN="${2##*/s/}"

if [ ! -f "$FILENAME" ]; then
        initError "Invalid input file: $FILENAME"
fi

if [ -z "$CLOUDURL" ]; then
        initError "Empty URL! Nowhere to send..."
fi

if [ -z "$FOLDERTOKEN" ]; then
        initError "Empty Folder Token! Nowhere to send..."
fi


##########################
# Check for curl

CURLBIN='/usr/bin/curl'
if [ ! -x "$CURLBIN" ]; then
        CURLBIN="$(which curl 2>/dev/null)"
        if [ ! -x "$CURLBIN" ]; then
                initError "No curl found on system!"
        fi
fi


##########################
# Extract base filename

if [ -z "$OUTFILE" ]; then
        OUTFILE="$(/usr/bin/basename $FILENAME)"
fi
#BFILENAME=$(/usr/bin/basename $FILENAME)


##########################
# Send file

#echo "$CURLBIN"$INSECURE$VERBOSE -T "$FILENAME" -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX/$OUTFILE"
"$CURLBIN"$INSECURE$VERBOSE -T "$FILENAME" -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX/$OUTFILE"
