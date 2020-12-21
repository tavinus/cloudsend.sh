#!/usr/bin/env bash

############################################################
#
# Tavinus Cloud Sender 2
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





CS_VERSION="2.1.14"

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
GLOBBING=$FALSE
GLOBCMD=' -g'
VERBOSE=' --progress-bar'

STTYBIN="$(command -v stty 2>/dev/null)"
SCREENSIZE="40  80"





################################################################
#### CURL CALL EXAMPLE

# https://cloud.mydomain.net/s/fLDzToZF4MLvG28
# curl -k -T myFile.ext -u "fLDzToZF4MLvG28:" -H 'X-Requested-With: XMLHttpRequest' https://cloud.mydomain.net/public.php/webdav/myFile.ext





################################################################
#### MESSAGES
################################################################


# Logs message to stdout
log() {
	# [ "$VERBOSE" == " -s" ] || printf "%s\n" "$1"
	isQuietMode || printf "%s\n" "$@"
}


# Prints program name and version
printVersion() {
        printf "%s\n" "Tavinus Cloud Sender v$CS_VERSION"
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
  -g | --glob              Disable input file checking to use curl globs
  -k | --insecure          Uses curl with -k option (https insecure)
  -p | --password <pass>   Uses <pass> as shared folder password
  -e | --envpass           Uses env var \$CLOUDSEND_PASSWORD as share password
                           You can 'export CLOUDSEND_PASSWORD' at your system, or set it at the call
                           Please remeber to also call -e to use the password set

Use:
  ./cloudsend.sh [options] <filepath> <folderLink>
  CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -e [options] <filepath> <folderLink>

Passwords:
  Cloudsend 2 changed the way password works
  Cloudsend 0.x.x used the '-p' parameter for the Environment password (changed to -e in v2+)
  Please use EITHER -e OR -p, but not both. The last to be called will be used

    Env Pass > Set the variable CLOUDSEND_PASSWORD='MySecretPass' and use the option '-e'
  Param Pass > Send the password as a parameter with '-p <password>'

Input Globbing:
  You can use input globbing (wildcards) by setting the -g option
  This will ignore input file checking and pass the glob to curl to be used
  You MUST NOT rename files when globbing, input file names will be used
  Glob examples: '{file1.txt,file2.txt,file3.txt}'
                 'img[1-100].png'

Send from stdin (pipe):
  You can send piped content by using - or . as the input file name (curl specs)
  You MUST set a destination file name to use stdin as input (-r <name>)

  Use the file name '-' (a single dash) to use stdin instead of a given file
  Alternately, the file name '.' (a single period) may be specified instead of '-' to use
  stdin in non-blocking mode to allow reading server output while stdin is being uploaded

Examples:
  CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -e './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -p 'MySecretPass' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -p 'MySecretPass' -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -g -p 'MySecretPass' '{file1,file2,file3}' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  cat file | ./cloudsend.sh - 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28' -r destFileName

Send folder examples:
  find ./ -maxdepth 1 -type f -exec ./cloudsend.sh {} https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG -p yourPassword \;
  find /home/myname/myfolder -type f -exec ./cloudsend.sh {} https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG -p yourPassword \;
  tar cf - \"\$(pwd)\" | gzip -9 -c | ./cloudsend.sh - 'https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG' -r myfolder.tar.gz
  tar cf - /home/myname/myfolder | gzip -9 -c | ./cloudsend.sh - 'https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG' -r myfolder.tar.gz
  zip -q -r -9 - /home/myname/myfolder | ./cloudsend.sh - 'https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG' -r myfolder.zip
  
"
}





################################################################
#### GET OPTIONS
################################################################


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
                        -g|--glob)
                                GLOBBING=$TRUE
                                GLOBCMD=''
                                log " > Glob mode on, input file checkings disabled"
                                shift ;;
                        *)
                                if isEmpty "$1"; then
                                        break ;
                                else
                                        CLOUDSEND_PARAMS=("${CLOUDSEND_PARAMS[@]}" "$1")
                                        shift ;
                                fi
                                        
                esac
        done
        
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
        
        if isGlobbing; then
                if isRenaming; then
                        initError $'Cannot rename output files when using globbing on input.\nAll files would get the same output name and then be overwritten.\nSend individual files if you need renaming.'
                elif isPiped "$FILENAME"; then
                        initError $'Cannot use globbing and send piped input at the same time.\nDo either one or the other.'
                fi
        else
                if ! isFile "$FILENAME" && ! isPiped "$FILENAME"; then
                        initError "Invalid input file: $FILENAME"
                fi

                if isPiped "$FILENAME" && ! isRenaming; then
                        initError $'No output file name!\nYou need to set a destination name when reading from a pipe!\nPlease add -r <filename.ext> to your call.'
                fi
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
################################################################


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

# Adjust Columns so the progess bar shows correctly
getScreenSize() {
        if [ -x "$STTYBIN" ]; then
                SCREENSIZE="$($STTYBIN size)"
        fi
        #export LINES=${SCREENSIZE% *}
        #export COLUMNS=$((${SCREENSIZE#* } - 1))
        export COLUMNS=${SCREENSIZE#* }
        #echo "LINES..: $LINES"
        #echo "COLUMNS: $COLUMNS"
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


# Checks if the input file is stdin (either - or .)
isPiped() {
        if [ "$1" = '-' ] || [ "$1" = '.' ] ; then
                return $TRUE
        fi
        return $FALSE        
}





################################################################
#### FLAG CHECKERS
################################################################


# If we are renaming the output, return $TRUE, else $FALSE
isRenaming() {
        return $RENAMING
}


# If we are running in Quiet Mode, return $TRUE, else $FALSE
isQuietMode() {
        return $QUIETMODE
}


# If we are globbing the input, return $TRUE, else $FALSE
isGlobbing() {
        return $GLOBBING
}





################################################################
#### RUNNERS
################################################################


# Logs succes or failure from curl
logResult() {
        #echo "LOGRESULT: $1"
        local fileString="$(/usr/bin/basename "$FILENAME")"
        isRenaming && fileString="$(/usr/bin/basename "$FILENAME") (renamed as $OUTFILE)"
        if [ $1 -eq 0 ]; then
                log " > Curl exited without errors"$'\n'" > Attempt to send completed > $fileString"
                exit 0
        fi
        log " > Curl error when sending file > $fileString"
        exit $1
}


# Execute curl send
sendFile() {
        if isGlobbing; then
                OUTFILE=''
        elif isEmpty "$OUTFILE"; then # If we are not renaming, use the input file name
                OUTFILE="$(/usr/bin/basename "$FILENAME")"
        fi
        
        getScreenSize
        
        # Send file
        #echo "$CURLBIN"$INSECURE$VERBOSE -T "$FILENAME" -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX/$OUTFILE"
        "$CURLBIN"$INSECURE$VERBOSE$GLOBCMD -T "$FILENAME" -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX/$OUTFILE" | cat ; test ${PIPESTATUS[0]} -eq 0
        logResult $?
}





################################################################
#### RUN #######################################################
################################################################
parseQuietMode "${@}"
parseOptions "${@}"
checkCurl
sendFile
################################################################
#### RUN #######################################################
################################################################






################################################################
exit 88 ; # should never get here
################################################################
