#!/usr/bin/env bash

################################################################
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
# @MG2R @gessel @deajan
#
# Get this script to current folder with:
# curl -O 'https://raw.githubusercontent.com/tavinus/cloudsend.sh/master/cloudsend.sh' && chmod +x cloudsend.sh
#
# NOTE: Cloudsend 2 changed the way password is handled and 
# is NOT compatible with cloudsend 1 calls. The -e parameter
# now does what -p parameter did (environment passwords), 
# while the -p parameter receives the password directly.
#
################################################################


################################################################
#### CURL CALL EXAMPLE
# https://cloud.mydomain.net/s/fLDzToZF4MLvG28
# curl -k -A "myuseragent" -e myreferer -T myFile.ext -u "fLDzToZF4MLvG28:" -H 'X-Requested-With: XMLHttpRequest' https://cloud.mydomain.net/public.php/webdav/myFile.ext
################################################################





################################################################
#### CONSTANTS AND VARIABLES
################################################################

CS_VERSION="2.3.9"

# Makes code more readable
TRUE=0
FALSE=1

# Base URL variables
CLOUDURL=""
FOLDERTOKEN=""
ROOTPATH=""
TARGETPATH=''
FULLPATH=''
FULLPATHENC=''

# Calls constants
PUBSUFFIX="public.php/webdav"
HEADER='X-Requested-With: XMLHttpRequest'

# Execution parameters
CLOUDSEND_PARAMS=()
INSECURE=''
OUTFILE=''
LIMITCMD=''
RATELIMIT=''
GLOBCMD=''
VERBOSE=' --progress-bar'
USERAGENT=''
REFERER=''

# Execution modes
DELETEMODE=$FALSE
MAKEDIR=$FALSE
RENAMING=$FALSE
QUIETMODE=$FALSE
GLOBBING=$FALSE
LIMITTING=$FALSE

# File/Folder listings
DIRLIST=()
FILELIST=()

# Exit handling
CURLEXIT=0
CURLRESPONSES=""
ABORTONERRORS=$FALSE

# Color config
NOCOLOR=$FALSE
COLORCLOUDSEND=216
COLORCONFIG=173
COLORHEADER=75
COLORITEM=215
COLORSUCCESS=85
COLORERROR=197

# For progress bars config (set columns)
TPUTBIN="$(command -v tput 2>/dev/null)"
TERMCOLSMAX=79         # max download bar size
TERMCOLS=$TERMCOLSMAX  # sets download bar size
unset COLUMNS          # unset $COLUMNS so Bash can update it

# Basic dependency binaries
CURLBIN=""
BASENAMEBIN="$(command -v basename 2>/dev/null)"
FINDBIN="$(command -v find 2>/dev/null)"
SEDBIN="$(command -v sed 2>/dev/null)"
GREPBIN="$(command -v grep 2>/dev/null)"
CATBIN="$(command -v cat 2>/dev/null)"






################################################################
#### MAIN RUNNER
################################################################

# Main runner
main() {
        # Create base target dir for -T option
        hasTargetFolder && ! isDeleting && createBaseTarget

        if isDeleting; then
                logHeader "DELETING TARGET"
                deleteTarget "$FILENAME"
        elif isMakeDir; then
                createTreeRemote "$FILENAME"
        elif ! isGlobbing && isDir "$FILENAME"; then
                sendDir
        else
                if isGlobbing; then
                        logHeader "SENDING CURL GLOB"
                        log "$(printItem "$FILENAME") > "
                elif isPiped "$FILENAME"; then
                        logHeader "SENDING PIPED CONTENT"
                        log "$(printItem "$FILENAME") (pipe) > "
                else
                        logHeader "SENDING SINGLE FILE"
                        log "$(printItem "$("$BASENAMEBIN" "$FILENAME")") > "
                fi
                sendFile "$FILENAME"
        fi
}






################################################################
#### OPTIONS PARSERS
################################################################

# Checks only for quiet/verbose mode and ignores all else
parseQuietMode(){
        while :; do
                case "$1" in
                        -h|--help)
                                usage ; exit 0 ;;
                        -V|--version)
                                printVersion ; exit 0 ;;
                        -N|--no-color|--nocolor)
                                NOCOLOR=$TRUE
                                shift ;;
                        -q|--quiet)
                                QUIETMODE=$TRUE
                                VERBOSE=" -s" ; shift ;;
                        *)
                                isEmpty "$1" && break || shift ;;
                esac
        done

}


# Parses CLI options and parameters
parseOptions() {
        log "$(printColorBoldUnderline $COLORCLOUDSEND "Tavinus Cloud Sender v$CS_VERSION")"$'\n'
        while :; do
                case "$1" in
                        -q|--quiet)
                                shift ;; # already checked
                        -N|--no-color|--nocolor)
                                NOCOLOR=$TRUE
                                logConfig "> Color mode OFF"
                                shift ;;
                        -k|--insecure)
                                INSECURE=' -k'
                                logConfig "> Insecure mode ON"
                                shift ;;
                        -e|--envpass|--environment)
                                loadPassword "${CLOUDSEND_PASSWORD}"
                                logConfig "> Using password from Environment"
                                shift ;;
                        -p|--password)
                                loadPassword "$2"
                                logConfig "> Using password from Parameter"
                                shift ; shift ;;
                        -C|--mkdir)
                                MAKEDIR=$TRUE
                                logConfig "> Makedir mode is ON"
                                shift ;;
                        -D|--delete)
                                DELETEMODE=$TRUE
                                logConfig "> Delete mode is ON"
                                shift ;;
                        -T|--target|--base)
                                loadTarget "${2}"
                                logConfig "> Base Target folder set to: \"$TARGETPATH\""
                                shift ; shift ;;
                        -r|--rename)
                                loadOutFile "${2}"
                                logConfig "> Destination file will be renamed to \"$OUTFILE\""
                                RENAMING=$TRUE
                                shift ; shift ;;
                        -g|--glob)
                                GLOBBING=$TRUE
                                GLOBCMD=' -g'
                                logConfig "> GLOB mode ON, input file checkings disabled"
                                shift ;;
                        -a|--abort-on-errors)
                                ABORTONERRORS=$TRUE
                                logConfig "> Abort on errors ON, will stop execution on DAV errors"
                                shift ;;
                        -l|--limit-rate)
                                loadLimit "${2}"
                                LIMITTING=$TRUE
                                logConfig "> Rate limit set to $RATELIMIT"
                                shift ; shift ;;
                        -A|--user-agent)
                                USERAGENT="${2}"
                                logConfig "> Using custom User Agent"
                                shift ; shift ;;
                        -E|--referer)
                                REFERER=" -e ${2}"
                                logConfig "> Using custom Referer"
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
        
        CLOUDURL=''
        FILENAME="${CLOUDSEND_PARAMS[0]}"
        CLOUDSHARE="${CLOUDSEND_PARAMS[1]}"

        # if we have index.php in the URL, process accordingly
        if [[ "$CLOUDSHARE" == *"index.php"* ]]; then
                CLOUDURL="${CLOUDSHARE%/index.php/s/*}"
        else
                CLOUDURL="${CLOUDSHARE%/s/*}"
        fi

        # get token and sub folder
        FOLDERTOKEN="${CLOUDSHARE##*/s/}"
        ROOTPATH="${FOLDERTOKEN##*\?path=}"
        FOLDERTOKEN="${FOLDERTOKEN%\?*}"

        # check if we have a inner-path from the URL
        if [[ "$FOLDERTOKEN" == "$ROOTPATH" ]]; then
                ROOTPATH=""
        else
                ROOTPATH="$(decodeLink "$ROOTPATH")"
                logConfig "> Root Target folder set from URL: \"$ROOTPATH\""
        fi

        # populate Full Path for operations
        FULLPATH="/${ROOTPATH#/}"
        if hasTargetFolder ; then
                hasRootFolder && FULLPATH="/${ROOTPATH#/}/${TARGETPATH#/}" || FULLPATH="/${TARGETPATH#/}"
        fi
        FULLPATHENC="$(escapeChars "$FULLPATH")"

        if isGlobbing; then
                if isRenaming; then
                        initError $'Cannot rename output files when using globbing on input.\nAll files would get the same output name and then be overwritten.\nSend individual files if you need renaming.'
                elif isPiped "$FILENAME"; then
                        initError $'Cannot use globbing and send piped input at the same time.\nDo either one or the other.'
                fi
        else
                if ! isFile "$FILENAME" && ! isDir "$FILENAME" && ! isPiped "$FILENAME" && ! isDeleting && ! isMakeDir ; then
                        initError "Invalid input file/folder: $FILENAME"
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


# Parses Rate limitting
loadLimit() {
        if [ -z "$@" ]; then
                initError "Trying to set an empty rate limit"
        fi
        RATELIMIT="$@"
        LIMITCMD=' --limit-rate '"$RATELIMIT"
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


# Sets a base target folder
loadTarget() {
        if [ -z "$@" ]; then
                initError "Trying to set an empty destination base path"
        fi
        TARGETPATH="/${@#/}" # remove / if exists, and then adds it
}






################################################################
#### USAGE
################################################################

# Prints usage information (help)
usage() {
        printVersion
        printf "%s" "
Parameters:
  -h | --help              Print this help and exits
  -q | --quiet             Disables verbose messages
  -V | --version           Prints version and exits
  -N | --no-color          Disables colored output
  -D | --delete            Delete file/folder in remote share
  -T | --target <dir>      Rebase work into a target folder (instead of root)
  -C | --mkdir             Create a directory tree in the remote share
  -r | --rename <file.xxx> Change the destination file name
  -g | --glob              Disable input file checking to use curl globs
  -k | --insecure          Uses curl with -k option (https insecure)
  -A | --user-agent        Specify user agent to use with curl -A option
  -E | --referer           Specify referer to use with curl -e option
  -l | --limit-rate        Uses curl limit-rate (eg 100k, 1M)
  -a | --abort-on-errors   Aborts on Webdav response errors
  -p | --password <pass>   Uses <pass> as shared folder password
  -e | --envpass           Uses env var \$CLOUDSEND_PASSWORD as share password
                           You can 'export CLOUDSEND_PASSWORD' at your system, or set it at the call
                           Please remeber to also call -e to use the password set

Use:
  ./cloudsend.sh [options] <inputPath> <folderLink>
  CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -e [options] <inputPath> <folderLink>

Passwords:
  Cloudsend 2 changed the way password works
  Cloudsend 0.x.x used the '-p' parameter for the Environment password (changed to -e in v2+)
  Please use EITHER -e OR -p, but not both. The last to be called will be used

    Env Pass > Set the variable CLOUDSEND_PASSWORD='MySecretPass' and use the option '-e'
  Param Pass > Send the password as a parameter with '-p <password>'

Folders:
  Cloudsend 2.2.0 introduces folder tree sending. Just use a directory as <inputPath>.
  It will traverse all files and folders, create the needed folders and send all files.
  Each folder creation and file sending will require a curl call.

Target Folder:
  Cloudsend 2.3.2 introduces the target folder setting. It will create the folder in the remote
  host and send all files and folders into it. It also works as a base folder for the other operations
  like deletion and folder creation. Accepts nested folders.
  ./cloudsend.sh -T 'f1/f2/f3' -p myPass 'folder|file' 'https://cloud.domain/index.php/s/vbi2za9esfrgvXC'

Create Folder:
  Available since version 2.3.2. Just pass the folder name to be created as if it was the
  file/folder being sent and add the -C | --mkdir parameter. Runs recursively. 
  ./cloudsend.sh -C -p myPass 'new folder/new2' 'https://cloud.domain/index.php/s/vbi2za9esfrgvXC'

Delete:
  Available since version 2.3.1. Just pass the file/folder to be deleted as if it was the
  file/folder being sent and add the -D | --delete parameter.
  ./cloudsend.sh -D -p myPass 'folder/file' 'https://cloud.domain/index.php/s/vbi2za9esfrgvXC'

Input Globbing:
  You can use input globbing (wildcards) by setting the -g option
  This will ignore input file checking and pass the glob to curl to be used
  You MUST NOT rename files when globbing, input file names will be used
  You MUST NOT send folders when globbing, only files are allowed
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
  ./cloudsend.sh 'my Folder' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh --limit-rate 200K -p 'MySecretPass' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -p 'MySecretPass' -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -g -p 'MySecretPass' '{file1,file2,file3}' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  cat file | ./cloudsend.sh - 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28' -r destFileName

"
}






################################################################
#### DEPENDENCY CHECKS
################################################################

# Dependency checks
checkDeps() {
        findCurl
        checkDependency "$BASENAMEBIN" "basename"
        checkDependency "$FINDBIN" "find"
        checkDependency "$SEDBIN" "sed"
        checkDependency "$GREPBIN" "grep"
        checkDependency "$CATBIN" "cat"
}


# Dependency checks
checkDependency() {
        isExecutable "$1" || initError "No \"$2\" found on system! Please install $2 and try again!"
}


# Dependency check
findCurl() {
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






################################################################
#### DOWNLOAD BAR SIZE HACK
################################################################

# Adjust Columns so the progess bar shows correctly
# Curl "space bar" has bugs that only show in special cases,
# depending on the column size of the terminal. I had lots
# of problems with this spanning multiple lines, so I fixed it
# with a max of 80 columns if it is bigger (seems to solve).
# https://github.com/curl/curl/issues/4849
getScreenSize() {
        # Migrated from stty to tput since stty was not working
        # inside the bash script

        # echo "$("$TPUTBIN" cols 2>/dev/null)"

        if isExecutable "$TPUTBIN"; then
                TERMCOLS="$("$TPUTBIN" cols 2>/dev/null)"
        fi

        # sanity
        if isEmpty "$TERMCOLS" || [[ $TERMCOLS -gt $TERMCOLSMAX ]]; then
                TERMCOLS=$TERMCOLSMAX
        fi
}






################################################################
#### SEND FILE
################################################################

# Execute curl send file
sendFile() {
        if isGlobbing; then
                OUTFILE=''
        elif isEmpty "$OUTFILE"; then # If we are not renaming, use the input file name
                OUTFILE="$("$BASENAMEBIN" "$1")"
        fi
        eout="$(escapeChars "$OUTFILE")"

        getScreenSize

        # Send file
        if hasUserAgent; then
                resp="$(COLUMNS=$TERMCOLS "$CURLBIN"$LIMITCMD$INSECURE$REFERER$VERBOSE$GLOBCMD -A "$USERAGENT" -T "$1" -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX$FULLPATHENC/$eout")"
                stat=$?
        else
                                resp="$(COLUMNS=$TERMCOLS "$CURLBIN"$LIMITCMD$INSECURE$REFERER$VERBOSE$GLOBCMD -T "$1" -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX$FULLPATHENC/$eout")"
                stat=$?
        fi
        #echo "$CURLBIN"$LIMITCMD$INSECURE$REFERER$VERBOSE$GLOBCMD -T "$1" -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX$FULLPATHENC/$eout"
        isNotEmpty "$resp" && curlAddResponse "SEND FILE ERROR FOR \"$1\""$'\n'"$resp"
        curlAddExitCode $stat
        checkAbort # exits if DAV errors AND not ignoring them
}






################################################################
#### SEND DIRECTORY
################################################################

# Traverse a folder and send its files and subfolders
sendDir() {
        isEmpty "$FILENAME" && initError 'Error! Cannot send folder with empty name.'
        isDir "$FILENAME" || initError 'Error! sendFolder() > "'"$FILENAME"'" is not a Folder.'

        # Load lists of folders and files to be sent
        DIRLIST=()
        FILELIST=()
        readarray -t DIRLIST < <(find "$FILENAME" -type d -printf '%P\n')
        readarray -t FILELIST < <(find "$FILENAME" -type f -printf '%P\n')
        #echo '<<DIRLIST>>' ; echo "${DIRLIST[@]}" ; echo '<<FILELIST>>' ; echo "${FILELIST[@]}"

        fbn="$("$BASENAMEBIN" "$FILENAME")"

        # MacOS / BSD readlink does not have the -f option
        # Get bash implementation from pdfScale.sh if needed
        # For now PWD seems to be enough
        if [[ "$fbn" == '.' ]]; then 
                fbn="$PWD"
                fbn="$("$BASENAMEBIN" "$fbn")"
        fi

        logHeader "CREATING FOLDER TREE AT DESTINATION"

        # Create main/root folder that is being sent
        createDir "$fbn"
        
        # Create whole directory tree at destination
        for d in "${DIRLIST[@]}"; do
                if ! isEmpty "$d"; then
                        createDir "$fbn/$d"
                fi
        done

        logHeader "SENDING ALL FILES FROM FOLDER TREE"
        
        # Send all files to their destinations
        for f in "${FILELIST[@]}"; do 
                if ! isEmpty "$f"; then
                        OUTFILE="$fbn/$f"
                        log "$(printItem "$OUTFILE") > "
                        sendFile "$FILENAME/$f"
                fi
        done
}


# Create a directory on remote
# $1 - Name of the dir to be created
# $2 - Disables verbose if not empty
# $3 - Changes pathing to $ROOTPATH if set to 'base'
createDir() {
        isEmpty "$1" && initError 'Error! Cannot create folder with empty name.'
        #getScreenSize

        [[ -z "$2" ]] && logSameLine "$(printItem "$1") > "
        eout="$(escapeChars "$1")"
        cstat="$(createDirRun "$eout" "$3" 2>&1)"

        if ! isEmpty "$cstat" ; then
                if [[ $cstat == *"already exists"* ]]; then
                        log "$(printSuccess "OK") (exists)"
                else
                        curlAddResponse "CREATE DIR ERROR FOR \"$1\""$'\n'"$cstat"
                        log "$(printError "$(getCurlError "$cstat")")"

                fi
        else
                log "$(printSuccess "OK") (created)"
        fi

        checkAbort # exits if DAV errors AND not ignoring them
}


# Runs the actual curl call with -X MKCOL to create a directory
# $1 - Name of the dir to be created
# $2 - Changes pathing to $ROOTPATH if set to 'base'
createDirRun() {
        local _path="$FULLPATHENC"
        [[ "$2" == "base" ]] && _path="/$(encodeLink "$ROOTPATH")"  # if we are creating the base target folders

        if "$CURLBIN"$INSECURE$REFERER -A "$USERAGENT" --silent -X PROPFIND -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX$_path/$1" | "$CATBIN" ; then
                echo "Directory $_path/$1 already exists."
                return 0
        fi

        if hasUserAgent; then
                "$CURLBIN"$INSECURE$REFERER -A "$USERAGENT" --silent -X MKCOL -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX$_path/$1" | "$CATBIN" ; test ${PIPESTATUS[0]} -eq 0
        else
                "$CURLBIN"$INSECURE$REFERER --silent -X MKCOL -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX$_path/$1" | "$CATBIN" ; test ${PIPESTATUS[0]} -eq 0
        fi
        ecode=$?
        curlAddExitCode $ecode
        return $ecode
}






################################################################
#### MKDIR
################################################################

# Creates a folder tree on remote
createTreeRemote() {
        local m="CREATING FOLDERS ON TARGET"
        [[ ! -z "$2" ]] && m="$2"
        logHeader "$m"
        local _tree=()
        IFS='/' read -a _tree <<< "$1"
        local _treeTrack=""
        for d in "${_tree[@]}"; do
                if ! isEmpty "$d"; then
                        _treeTrack="$_treeTrack/$d"
                        logSameLine "$(printItem "${_treeTrack#/}") > "
                        createDir "${_treeTrack#/}" "quiet" "$3"
                fi
        done
}






################################################################
#### BASE TARGET
################################################################

# Creates the base target folder
createBaseTarget() {
        createTreeRemote "$TARGETPATH" "CREATING BASE TARGET FOLDERS" "base"
}






################################################################
#### DELETE
################################################################

# Tries to delete $1 from the destination
deleteTarget() {
        isEmpty "$1" && initError 'Error! Cannot delete target with empty name.'
        #getScreenSize
        logSameLine "$(printItem "$1") > "
        eout="$(escapeChars "$1")"
        cstat="$(deleteRun "$eout" 2>&1)"
        if ! isEmpty "$cstat"; then
                curlAddResponse "DELETE ITEM ERROR FOR \"$1\""$'\n'"$cstat"
                log "$(printError "$(getCurlError "$cstat")")"
        else
                log "$(printSuccess "OK") (deleted)"
        fi
        checkAbort # exits if DAV errors AND not ignoring them
}


# Runs curl to delete file/folder at destination
deleteRun() {
        if hasUserAgent; then
                "$CURLBIN"$INSECURE$REFERER -A "$USERAGENT" --silent -X DELETE -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX$FULLPATHENC/$1" | "$CATBIN" ; test ${PIPESTATUS[0]} -eq 0
        else
                                "$CURLBIN"$INSECURE$REFERER --silent -X DELETE -u "$FOLDERTOKEN":"$PASSWORD" -H "$HEADER" "$CLOUDURL/$PUBSUFFIX$FULLPATHENC/$1" | "$CATBIN" ; test ${PIPESTATUS[0]} -eq 0
        fi
        ecode=$?
        curlAddExitCode $ecode
        return $ecode
}






################################################################
#### FLAG CHECKERS
################################################################

# Should we print with color and formatting?
noColor() {
        return $NOCOLOR
}


# If we are deleting a file/folder, return $TRUE, else $FALSE
isDeleting() {
        return $DELETEMODE
}


# If we are creating a file/folder, return $TRUE, else $FALSE
isMakeDir() {
        return $MAKEDIR
}


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


# If we should abort when curl returns a XML response, return $TRUE, else $FALSE
abortOnDavErrors() {
        return $ABORTONERRORS
}


# If have a dav error, return $TRUE, else $FALSE
hasDavErrors() {
        isEmpty "$CURLRESPONSES" && return $FALSE
        return $TRUE
}


# Aborts execution if we have a dav error and have open -a set
checkAbort() {
        abortOnDavErrors && hasDavErrors && logResult
}


# If we have a custom user-agent set
hasUserAgent() {
        [[ -z "$USERAGENT" ]] && return $FALSE
        return $TRUE
}


# If we have a root folder from URL set
hasRootFolder() {
        [[ -z "$ROOTPATH" ]] || [[ '/' == "$ROOTPATH" ]]  && return $FALSE
        return $TRUE
}


# If we have a custom base target folder set
hasTargetFolder() {
        [[ -z "$TARGETPATH" ]] && return $FALSE
        return $TRUE
}






################################################################
#### VALIDATORS
################################################################

# Returns $TRUE if $1 is a file, $FALSE otherwise
isFile() {
        [[ -f "$1" ]] && return $TRUE
        return $FALSE
}


# Returns $TRUE if $1 is a directory, $FALSE otherwise
isDir() {
        [[ -d "$1" ]] && return $TRUE
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
#### LOG MESSAGES
################################################################

# Logs message to stdout
log() {
	isQuietMode || printf "%s\n" "${@}"
}


# Logs config message to stdout
logConfig() {
	isQuietMode && return $TRUE
        log "$(printColor $COLORCONFIG "$@")"
}


# Logs message to stdout
logSameLine() {
	isQuietMode || printf "%s" "$@"
}


# Prints program name and version
printVersion() {
        printf "%s\n" "Tavinus Cloud Sender v$CS_VERSION"
}


# Prints error messages and exits
initError() {
        #printVersion >&2
        printf "\n%s\n" "$(printError "Init Error! $1")" >&2
        printf "%s\n" "Try: $0 --help" >&2
        exit 5
}


# Print each section header
logHeader() {
        local s=${#1}                        # string size
        ((s+=2))                             # padding
        local l="$(drawLine $s '\u203E')"    # lower line
        local u="$(drawLine $s '\u2017')"    # upper line
        local t="$(printColorBold $COLORHEADER "$1")"
        log $'\n'"$u"$'\n'" $t"$'\n'"$l"
}


# Prints main target download URL
logURL() {
        isGlobbing || isDeleting && return $TRUE
        logHeader "MAIN TARGET URLs"
        
        local _fname="${FILENAME#/}"        # input name
        isRenaming && _fname="${OUTFILE#/}" # or renaming
        _fname="${_fname%/}"                # trim '/' from end
        local _fbase="$($BASENAMEBIN "$_fname")"

        local _fpath="${FULLPATH#/}"        # trim '/' from start
        _fpath="${_fpath%/}"                # trim '/' from end

        # creates base url with encoded html chars for ' ' and '/'
        # ampersands are not encoded, text before ?path is not encoded
        local _url_down="$CLOUDURL/index.php/s/$FOLDERTOKEN/download?path="
        local _url_open="$CLOUDURL/index.php/s/$FOLDERTOKEN?path="

        local _url_suffix=''         # suffix for both links

        if isDir "$FILENAME"; then   # uploaded dir link
                _url_suffix="/$_fbase"
        elif isMakeDir ; then        # created dir link
                _url_suffix="/$_fname"
        else                         # uploaded file link
                _url_suffix="&files=$_fbase" 
        fi

         # prints the urls to the user
        log "$(printItem "Download URL:") >"
        log "$_url_down$_fpath$_url_suffix"
        log "$_url_down$(encodeLink "$_fpath$_url_suffix")"$'\n'

        log "$(printItem "Access URL:") >"
        log "$_url_open$_fpath$_url_suffix"
        log "$_url_open$(encodeLink "$_fpath$_url_suffix")"
}


# Logs succes or failure from curl
logResult() {
        logURL   # prints URL if not globbing or deleting

        local fileString=("Send" "$("$BASENAMEBIN" "$FILENAME")")
        isRenaming && fileString=("Send" "$("$BASENAMEBIN" "$FILENAME") (renamed as $OUTFILE)")
        isMakeDir && fileString=("Makedir" "$FILENAME")
        isDeleting && fileString=("Delete" "$("$BASENAMEBIN" "$FILENAME")")

        local t='File'
        isDir "$FILENAME" || isMakeDir && t='Directory'
        isDeleting && t='Unknown'

        logHeader "SUMMARY"

        local b='/'
        hasTargetFolder && b="$TARGETPATH"

        local r='/'
        hasRootFolder && r="/${ROOTPATH#/}"

        local f="$FULLPATH"
                  
        if [ $CURLEXIT -eq 0 ]; then

                logStatusSuccess "Curl" "NO Errors"

                if isEmpty "$CURLRESPONSES"; then
                        logStatusSuccess "CurlExit" "$CURLEXIT"
                        logStatusSuccess "WebDav" "NO Errors"
                        logStatusSuccess "Status" "${fileString[0]} Completed"
                else
                        logStatusSuccess "CurlExit" "$CURLEXIT"
                        logStatusFailure "WebDav" "Errors Detected"
                        logStatusFailure "Status" "${fileString[0]} Completed with Warnings"
                fi

                logStatusNeutral "Root" "${r}"
                logStatusNeutral "Base" "${b}"
                logStatusNeutral "Full" "${f}"
                logStatusNeutral "Target" "${fileString[1]}"
                logStatusNeutral "Type" "${t}"

                if isNotEmpty "$CURLRESPONSES"; then
                        logHeader "CURL LOG"
                        log "$CURLRESPONSES"
                fi

                exit 0
        fi

        logStatusFailure "Curl" "Errors detected"
        logStatusFailure "CurlExit" "$CURLEXIT"
        logStatusFailure "WebDav" "No info"
        logStatusFailure "Status" "${fileString[0]} Failed"
        logStatusNeutral "Root" "${r}"
        logStatusNeutral "Base" "${b}"
        logStatusNeutral "Full" "${f}"
        logStatusNeutral "Target" "${fileString[1]}"
        logStatusNeutral "Type" "${t}"

        exit $CURLEXIT
}


# Prints a log success status info to screen
logStatusSuccess() {
        log "$(printStatus "$1") : $(printSuccess "$2")"
}


# Prints a log error status info to screen
logStatusFailure() {
        log "$(printStatus "$1") : $(printError "$2")"
}


# Prints a log nreutral status info to screen
logStatusNeutral() {
        log "$(printStatus "$1") : ${2}"
}






################################################################
#### CURL ERROR HANDLING
################################################################

# Curl summed exit codes
# Will be 0 if no curl call had errors
curlAddExitCode() {
        ((CURLEXIT=CURLEXIT+$1))
}


# Curl appended messages
# Will probably be empty if curl was able to perfom as intended
curlAddResponse() {
        if isNotEmpty "$1"; then
                isEmpty "$CURLRESPONSES" && CURLRESPONSES="$1" || CURLRESPONSES="$CURLRESPONSES"$'\n--------------------------------------------------\n'"$1"
        fi
}


# Parses curl error/exception from response XML
getCurlError() {
        local msg="$(echo "$1" | "$GREPBIN" '<s:message>' | "$SEDBIN" -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//')"
        isEmpty "$msg" && msg="$(echo "$cstat" | "$GREPBIN" '<s:exception>' | "$SEDBIN" -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//')"
        printf "%s" "$msg"
}






################################################################
#### STRING SANITIZATION
################################################################

# Escape specific chars needed
escapeChars() {
        local string="${1}"
        local strlen=${#string}
        local encoded=""
        local pos c o

        for (( pos=0 ; pos<strlen ; pos++ )); do
                c=${string:$pos:1}
                case "$c" in
                        " " ) o='%20' ;;
                        '#' ) o='%23' ;;
                        * ) o="${c}" ;;
                esac
                encoded+="${o}"
        done
        echo "${encoded}"    # You can either set a return variable (FASTER) 
        #REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p

}


# Just change " " and "/" to their html chars
encodeLink() {
	isEmpty "$1" && return 9
	echo "$(echo "$1" | "$SEDBIN" 's/\//\%2f/g ; s/\ /\%20/g')"
}


# Just change " " and "/" from their html chars to normal chars
decodeLink() {
	isEmpty "$1" && return 9
	echo "$(echo "$1" | "$SEDBIN" 's/\%2F/\//g ; s/\%2f/\//g ; s/\%20/\ /g')"
}


# Decode '%2F' into '/'
decodeSlash() {
	isEmpty "$1" && return 9
	echo "$(echo "$1" | "$SEDBIN" 's/\%2f/\//g ; s/\%2F/\//g')"
}


# Decode '/' into '%2F' 
encodeSlash() {
	isEmpty "$1" && return 9
	echo "$(echo "$1" | "$SEDBIN" 's/\//\%2f/g')"
}






################################################################
#### COLOR AND GRAPHICS
################################################################

# Draws a line with $1 size
drawLine() {
        local cols=$1
        local color='\u203E'
        isNotEmpty "$2" && color="$2"
        while ((cols-- > 0)); do
                #printf '\u2500'
                printf "$color"
        done
}


# Prints text in Bold
printBold() {
        noColor && echo -n "$1" || printf "\e[1m$1\e[0m"
}


# Prints text in Italic
printItalic() {
        noColor && echo -n "$1" || printf "\e[3m$1\e[0m"
}


# Prints text in Bold Italic
printBoldItalic() {
        noColor && echo -n "$1" || printf "\e[3m\e[1m$1\e[0m"
}


# Prints text Underlined
printUnderline() {
        noColor && echo -n "$1" || printf "\e[4m$1\e[0m"
}


# Prints text with a strike
printStrike() {
        noColor && echo -n "$1" || printf "\e[9m$1\e[0m"
}


# Prints text in Color - from 0 to 255
printColor() {
        noColor && echo -n "$2" || printf "\e[38;5;""$1""m$2\e[0m"
}


# Prints bold text in Color
printColorBold() {
        noColor && echo -n "$2" || printf "\e[1m\e[38;5;""$1""m$2\e[0m"
}


# Prints bold underlined text in color
printColorBoldUnderline() {
        noColor && echo -n "$2" || printf "\e[4m\e[1m\e[38;5;""$1""m$2\e[0m"
}


# Prints succes item
printSuccess() {
        printColor $COLORSUCCESS "$1"
}


# Prints Error item
printError() {
        printColor $COLORERROR "$1"
}


# Prints a verbose item
printItem() {
        printColor $COLORITEM "$1"
}


# Formats a status header
printStatus() {
        printItem "$(printf "%8s" "$1")"
}











################################################################
#### RUN STARTS ################################################
################################################################
parseQuietMode "${@}"
parseOptions "${@}"
checkDeps
main
logResult
################################################################
#### RUN ENDS ##################################################
################################################################











################################################################
exit 88 ; # should never get here
################################################################
