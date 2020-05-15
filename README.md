# cloudsend.sh
Bash script that uses curl to send files to a nextcloud/owncloud shared folder.  

---

**Also check my [cloudmanager app](https://github.com/tavinus/cloudmanager) for a full nextcloud/owncloud webdav client.**  

---

### Shares with passwords
**Cloudsend v2 changed the way password parsing works.**  
Cloudsend 0.x.x used the `-p` parameter for the Environment password (changed to `-e` in v2+).  
Please use EITHER `-e` OR `-p`, but not both. The last to be called will be used.  
  
 - **Env Pass** *>* Set the variable `CLOUDSEND_PASSWORD='MySecretPass'` and use the option `-e`
 - **Param Pass** *>* Send the password as a parameter with `-p <password>`

#### To set the env var password
To set the variable you can either do it system-wide (not secure)
```
export CLOUDSEND_PASSWORD='MySecretPass'
```
Or you can define at the time of the call, appending as in the `--help` examples.  
  
There are many ways to use the pass in a variable, but the idea is that the password var is defined only in the context of the bash instance that it is running.  

### Input Globbing
You can use input globbing (wildcards) by setting the `-g` option.  
This will ignore input file checking and pass the glob to curl to be used.  
You *MUST NOT* rename files when globbing, input file names will be used.  
  
**Glob examples:**
 - `'{file1.txt,file2.txt,file3.txt}'`
 - `'img[1-100].png'`

**More info on globbing**  
https://ec.haxx.se/cmdline/cmdline-globbing  

### Read from stdin (pipes)
You can send piped content by using `-` or `.` as the input file name *(curl specs)*.  
You *MUST* set a destination file name to use stdin as input ( `-r <name>` ).  
  
**From curl's manual:**  
Use the file name `-` (a single dash) to use stdin instead of a given file.  
Alternately, the file name `.` (a single period) may be specified instead of `-` to use  
stdin in non-blocking mode to allow reading server output while stdin is being uploaded.  

### Sending entire folder
It is not natively supported, but there are many ways to accomplish this.  
Using a simple loop, ls, find, etc.  

**Folder send with `find` example:**
```
find ./ -maxdepth 1 -type f -exec ./cloudsend.sh {} https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG -p yourPassword \;
```
*This sends everything on the current shell folder.*
 - change the first `./` to change the input folder (eg. '/home/myname/myfolder')
 - `-maxdepth 1` will read current folder only, more levels go deeper, supressing goes all levels.

### Help info
```
$ ./cloudsend.sh --help
CloudSender v2.1.2

Parameters:
  -h | --help              Print this help and exits
  -q | --quiet             Disables verbose messages
  -V | --version           Prints version and exits
  -r | --rename <file.xxx> Change the destination file name
  -g | --glob              Disable input file checking to use curl globs
  -k | --insecure          Uses curl with -k option (https insecure)
  -p | --password <pass>   Uses <pass> as shared folder password
  -e | --envpass           Uses env var $CLOUDSEND_PASSWORD as share password
                           You can 'export CLOUDSEND_PASSWORD' at your system, or set it at the call
                           Please remeber to also call -e to use the password set

Notes:
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

Send folder examples:
  find ./ -maxdepth 1 -type f -exec ./cloudsend.sh {} https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG -p yourPassword \;
  find /home/myname/myfolder -type f -exec ./cloudsend.sh {} https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG -p yourPassword \;

Uses:
  ./cloudsend.sh [options] <filepath> <folderLink>
  ./cloudsend.sh [options] -p <password> <filepath> <folderLink>
  CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -e [options] <filepath> <folderLink>
  cat file | ./cloudsend.sh [options] - <folderLink> -r destFileName

Examples:
  ./cloudsend.sh './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -p 'MySecretPass' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -p 'MySecretPass' -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
   CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -e './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
```

### Questions
*Whats is "https://cloud.mydomain.net/s/fLDzToZF4MLvG28"?  
What is a "folderlink"?  
Where do i get it from?  
Specially the "s/fLDzToZF4MLvG28" part?*  
  
**You have to share a Folder writable and use the generated link**  
  
![Shared Folder Screenshot](https://user-images.githubusercontent.com/8039413/81998321-9a4fca00-9628-11ea-8fbc-7e5c7d0faaf0.png)

