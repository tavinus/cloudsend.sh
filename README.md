# Tavinus CloudSender2
Bash script that uses curl to send files and folders to a [nextcloud](https://nextcloud.com) / [owncloud](https://owncloud.org) publicly shared folder.  

  
---------------------------------------------- 
#### If you want to support this project, you can do it here :coffee: :beer:   
    
[![paypal-image](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=AJNPRBY9EDXJJ&source=url)  
  
---
  
***The logic is***
```
cloudsend <file/folder/glob> <PublicURL>
```
[The Origins are here](https://gist.github.com/tavinus/93bdbc051728748787dc22a58dfe58d8), 
Thanks for everyone that contributed on [the original GIST](https://gist.github.com/tavinus/93bdbc051728748787dc22a58dfe58d8)

---

**Also check my [cloudmanager app](https://github.com/tavinus/cloudmanager) for a full nextcloud/owncloud webdav client.**  

---

### Shares with passwords
**Cloudsend v2 changed the way password parsing works.**  
Cloudsend 0.x.x used the `-p` parameter for the Environment password (changed to `-e` in v2+).  
Please use EITHER `-e` OR `-p`, but not both. The last to be called will be used.  
  
 - **Env Pass** *>* Set the variable `CLOUDSEND_PASSWORD='MySecretPass'` and use the option `-e`
 - **Param Pass** *>* Send the password as a parameter with `-p <password>`

### Input Globbing
You can use input globbing (wildcards) by setting the `-g` option.  
This will ignore input file checking and pass the glob to curl to be used.  
You *MUST NOT* rename files when globbing, input file names will be used.  
You *MUST NOT* send folders when globbing, only files are allowed.  
  
**Glob examples:**
 - `'{file1.txt,file2.txt,file3.txt}'`
 - `'img[1-100].png'`

**More info on globbing**  
https://github.com/tavinus/cloudsend.sh/wiki/Input-Globbing 

### Read from stdin (pipes)
You can send piped content by using `-` or `.` as the input file name *(curl specs)*.  
You *MUST* set a destination file name to use stdin as input ( `-r <name>` ).  
  
**From curl's manual:**  
Use the file name `-` (a single dash) to use stdin instead of a given file.  
Alternately, the file name `.` (a single period) may be specified instead of `-` to use  
stdin in non-blocking mode to allow reading server output while stdin is being uploaded.  

### Sending entire folder
From v2.2.0 `cloudsend.sh` can send folders. It will traverse the folder tree, create  
each folder and send each file. **Just use a folder path as input.**  
  
![cloudsend_masked](https://github.com/user-attachments/assets/83bddfd9-ecde-4e8c-9af2-e3b20d9dea8b)
  
#### Other ways to send folders:

*This sends every **FILE** in the current shell folder.*
 - change the first `./` to change the input folder ( *eg.* `'/home/myname/myfolder'` )
 - `-maxdepth 1` will read current folder only, more levels go deeper, supressing goes all levels
```bash
find ./ -maxdepth 1 -type f -exec ./cloudsend.sh {} https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG -p yourPassword \;
```

----

*This sends every **FILE** inside `/home/myname/myfolder`, including ALL subfolders.*
```bash
find /home/myname/myfolder -type f -exec ./cloudsend.sh {} https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG -p yourPassword \;
```

----

*This sends a gziped tarball of the current shell folder.*  
```bash
tar cf - "$(pwd)" | gzip -9 -c | ./cloudsend.sh - 'https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG' -r myfolder.tar.gz
```

----

*This sends a gziped tarball of `/home/myname/myfolder`.*  
```bash
tar cf - /home/myname/myfolder | gzip -9 -c | ./cloudsend.sh - 'https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG' -r myfolder.tar.gz
```

----

*This sends a recursive zip file of `/home/myname/myfolder`.*  
```bash
zip -q -r -9 - /home/myname/myfolder | ./cloudsend.sh - 'https://cloud.mydomain.tld/s/TxWdsNX2Ln3X5kxG' -r myfolder.zip
```

----

### Deleting Files/Folders
Since version 2.3.1 you can delete files and folders at the remote server.  
Just use the option `-D|--delete` and pass the file/folder to be deleted as if it was the file being sent.  
  
*This example deteles `A Folder` from the remote server with all its subfolders and files.*  
```
$ ./cloudsend.sh -D -p MYSUPERPASS 'A Folder' 'https://mycrazyserver.com/index.php/s/fb16za9esovgkDB'
Tavinus Cloud Sender v2.3.4

> Delete mode is ON
> Using password from Parameter

‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗
 DELETING TARGET
‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
A Folder > OK (deleted)

‗‗‗‗‗‗‗‗‗
 SUMMARY
‾‾‾‾‾‾‾‾‾
    Curl : NO Errors
CurlExit : 0
  WebDav : NO Errors
  Status : Delete Completed
    Base : /
  Target : A Folder
    Type : Unknown
```

----

### Create Folder
Since version 2.3.2 you can create folders in the remote server with the `-c|--mkdir` parameter. It can be a single folder or a tree.  
  
Just pass the folder to be created as if it was the file being sent.  
```
$ ./cloudsend.sh -C -p MYSUPERPASS 'A Folder/And Another' 'https://mycrazyserver.com/index.php/s/fb16za9esovgkDB'
Tavinus Cloud Sender v2.3.4

> Makedir mode is ON
> Using password from Parameter

‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗
 CREATING FOLDERS ON TARGET
‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
A Folder > OK (exists)
A Folder/And Another > OK (created)

‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗‗
 MAIN TARGET DOWNLOAD URL
‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
https://cloud.zn.arq.br/index.php/s/fbi6zz9esorgkXB/download?path=%2FAnd
Another

‗‗‗‗‗‗‗‗‗
 SUMMARY
‾‾‾‾‾‾‾‾‾
    Curl : NO Errors
CurlExit : 0
  WebDav : NO Errors
  Status : Makedir Completed
    Base : /
  Target : A Folder/And Another
    Type : Directory
```

----

### Target Folder
Since version 2.3.2 you can set a target folder for remote operations with the `-T|--target` parameter. It can be a single folder or a tree.  
  
The target tree will be created before running the operations, unless you are running the delete command.  
  
All commands will use the target folder as the base folder (delete, send, create folder, etc).  

----

### Help info
```
$ ./cloudsend.sh --help
Tavinus Cloud Sender v2.3.4

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
  -e | --envpass           Uses env var $CLOUDSEND_PASSWORD as share password
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
  Available since version 2.3.2. Just pass the folder name to be deleted as if it was the
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
```

---

### Questions
*Whats is "https://cloud.mydomain.net/s/fLDzToZF4MLvG28"?  
What is a "folderlink"?  
Where do i get it from?  
Specially the "s/fLDzToZF4MLvG28" part?*  
  
**You have to share a Folder writable and use the generated link**  
  
![Shared Folder Screenshot](https://user-images.githubusercontent.com/8039413/81998321-9a4fca00-9628-11ea-8fbc-7e5c7d0faaf0.png)

---

### Troubleshooting
From [Nextcloud 21 Documentation](https://docs.nextcloud.com/server/21/user_manual/en/files/access_webdav.html#accessing-public-shares-over-webdav)  
![image](https://user-images.githubusercontent.com/8039413/116769994-b05fc180-aa16-11eb-80bc-e37ff45d1c38.png)

  
  

