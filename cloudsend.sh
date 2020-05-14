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
# NOTE: Cloudsend 2 changed the way password is handled and 
# is NOT compatible with cloudsend 1 calls. The -e parameter
# now does what -p parameter did (environment passwords), 
# while the -p parameter receives the password directly.
#
############################################################


CS_VERSION="2.0.0"

TRUE=0
FALSE=1

CLOUDURL=""
FOLDERTOKEN=""

PUBSUFFIX="public.php/webdav"
HEADER='X-Requested-With: XMLHttpRequest'

CLOUDSEND_PARAMS=()
INSECURE=''
OUTFILE=''

RENAMING=$FALSE
QUIETMODE=$FALSE



################################################################
#### CURL CALL EXAMPLE

# https://cloud.mydomain.net/s/fLDzToZF4MLvG28
# curl -k -T myFile.ext -u "fLDzToZF4MLvG28:" -H 'X-Requested-With: XMLHttpRequest' https://cloud.mydomain.net/public.php/webdav/myFile.ext




################################################################
#### MESSAGES

# Logs message to stdout
log() {
	# [ "$VERBOSE" == " -s" ] || printf "%s\n" "$1"
	isQuietMode || printf "%s\n" "$1"
}

# Prints program name and version
printVersion() {
        printf "%s\n" "CloudSender v$CS_VERSION"
}

# Prints error messages and exits
initError() {
        printVersion >&2
        printf "%s\n" "Init Error! $1" >&2
        printf "%s\n" "Try: $0 --help" >&2
        exit 5
}

# Prints usage information (help)
usage() {
        printVersion
        printf "%s" "
Parameters:
  -h | --help              Print this help and exits
  -q | --quiet             Disables verbose messages
  -V | --version           Prints version and exits
  -r | --rename <file.xxx> Change the destination file name
  -k | --insecure          Uses curl with -k option (https insecure)
  -p | --password <pass>   Uses <pass> as shared folder password
  -e | --envpass           Uses env var \$CLOUDSEND_PASSWORD as share password
                           You can 'export CLOUDSEND_PASSWORD' at your system, or set it at the call.
                           Please remeber to also call -e to use the password set.

Notes:
  Cloudsend 2 changed the way password works.
  Cloudsend 0.x.x used the '-p' parameter for the Environment password (changed to -e in v2+)
  Please use EITHER -e OR -p, but not both. The last to be called will be used.

    Env Pass > Set the variable CLOUDSEND_PASSWORD='MySecretPass' and use the option '-e'
  Param Pass > Send the password as a parameter with '-p <password>'

Uses:
  ./cloudsend.sh [options] <filepath> <folderLink>
  ./cloudsend.sh -p <password> <filepath> <folderLink>
  CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -e [options] <filepath> <folderLink>

Examples:
  ./cloudsend.sh './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -p 'MySecretPass' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -p 'MySecretPass' -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
   CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -e './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
"
}





################################################################
#### GET OPTIONS

# Checks only for quiet/verbose mode and ignores all else
parseQuietMode(){
        while :; do
                case "$1" in
                        -q|--quiet)
                                QUIETMODE=$TRUE
                                VERBOSE=" -s" ; break ;;
                        *)
                                isEmpty "$1" && break || shift ;;
                esac
        done

}

# Parses CLI options and parameters
parseOptions() {
        while :; do
                case "$1" in
                        -h|--help)
                                usage ; exit 0 ;;
                        -V|--version)
                                printVersion ; exit 0 ;;
                        -q|--quiet)
                                shift ;; # already checked
                        -k|--insecure)
                                INSECURE=' -k'
                                log " > Insecure mode ON"
                                shift ;;
                        -e|--envpass|--environment)
                                #PASSWORD=${CLOUDSEND_PASSWORD}
                                loadPassword "${CLOUDSEND_PASSWORD}"
                                log " > Using password from environment"
                                shift ;;
                        -p|--password)
                                loadPassword "$2"
                                log " > Using password from parameter"
                                shift ; shift ;;
                        -r|--rename)
                                loadOutFile "${2}"
                                log " > Destination file will be renamed to \"$OUTFILE\""
                                RENAMING=$TRUE
                                shift ; shift ;;
                        *)
                                if isEmpty "$1"; then
                                        break ;
                                else
                                        CLOUDSEND_PARAMS=("${CLOUDSEND_PARAMS[@]}" "$1")
                                        shift ;
                                fi
                                        
                esac
        done
        
        #FILENAME="$1"
        CLOUDURL=''
        FILENAME="${CLOUDSEND_PARAMS[0]}"
        CLOUDSHARE="${CLOUDSEND_PARAMS[1]}"

        # if we have index.php in the URL, process accordingly
        if [[ "$CLOUDSHARE" == *"index.php"* ]]; then
                CLOUDURL="${CLOUDSHARE%/index.php/s/*}"
        else
                CLOUDURL="${CLOUDSHARE%/s/*}"
        fi

        FOLDERTOKEN="${CLOUDSHARE##*/s/}"

        if ! isFile "$FILENAME"; then
                initError "Invalid input file: $FILENAME"
        fi

        if isEmpty "$CLOUDURL"; then
                initError "Empty URL! Nowhere to send..."
        fi

        if isEmpty "$FOLDERTOKEN"; then
                initError "Empty Folder Token! Nowhere to send..."
        fi

}

# Parses password to var or exits
loadPassword() {
        if [ -z "$@" ]; then
                initError "Trying to set an empty password"
        fi
        PASSWORD="$@"
}

# Parses destination file name to var or exits
loadOutFile() {
        if [ -z "$@" ]; then
                initError "Trying to set an empty destination file name"
        fi
        OUTFILE="$@"
}




################################################################
#### VALIDATORS

# Dependency check
checkCurl() {
        CURLBIN="$(command -v curl 2>/dev/null)"
        isExecutable "$CURLBIN" && return $TRUE
        CURLBIN='/usr/bin/curl'
        isExecutable "$CURLBIN" && return $TRUE
        CURLBIN='/usr/local/bin/curl'
        isExecutable "$CURLBIN" && return $TRUE
        CURLBIN='/usr/share/curl'
        isExecutable "$CURLBIN" && return $TRUE
        initError "No curl found on system! Please install curl and try again!"
        exit 6
}


# Returns $TRUE if $1 is a file, $FALSE otherwise
isFile() {
        [[ -f "$1" ]] && return $TRUE
        return $FALSE
}


# Returns $TRUE if $1 is executable, $FALSE otherwise
isExecutable() {
        [[ -x "$1" ]] && return $TRUE
        return $FALSE
}


# Returns $TRUE if $1 is empty, $FALSE otherwise
isEmpty() {
        [[ -z "$1" ]] && return $TRUE
        return $FALSE
}


# Returns $TRUE if $1 is not empty, $FALSE otherwise
isNotEmpty() {
        [[ -z "$1" ]] && return $FALSE
        return $TRUE
}




################################################################
#### FLAG CHECKERS

isRenaming() {
        return $RENAMING
}

isQuietMode() {
        return $QUIETMODE
}




################################################################
#### RUNNERS

# Logs succes or failure from curl
logResult() {
        local fileString="$(/usr/bin/basename $FILENAME)"
        isRenaming && fileString="$(/usr/bin/basename $FILENAME) (renamed as $OUTFILE)"
        if [ $1 -eq 0 ]; then
                log " > Success! File was sent > $fileString"
                exit 0
        fi
        log " > Error when sending file > $fileString"
        exit $1
}

# Execute curl send
sendFile() {
        # If we are not renaming, use the input file name
        if isEmpty "$OUTFILE"; then
                OUTFILE="$(/usr/bin/basename $FILENAME)"
        fi
        
        # Send file
        "$CURLBIN"$INSECURE$VERBOSE -T "$FILENAME" -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX/$OUTFILE"
        logResult $?
}




##########################
# RUN

parseQuietMode "${@}"
parseOptions "${@}"
checkCurl
sendFile



exit 88 ; # should never get here
























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
