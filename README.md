# cloudsend.sh
Bash script that uses curl to send files to a nextcloud/owncloud shared folder.

### Shares with passwords
To upload to a share with password set you need to 
 - Set environment variable `$CLOUDSEND_PASSWORD` 
**AND** 
 - Use the `-p | --password` flag on call  
  
### To set the env var password
To set the variable you can either do it system-wide (not too secure)
```
export CLOUDSEND_PASSWORD='MySecretPass'
```
Or you can define at the time of the call, appending as in the `--help` examples.  
  
There are many ways to implement it this way, but the idea is that the password var is defined only in the context of the bash instance that it is running.  
  
Also, be aware that the password will probably end up at your bash history file if you call it from a terminal, but will not show up on the process listings, like on ps, top, htop.  

### Help info
```
$ ./cloudsend.sh --help
CloudSender v0.1.7

Parameters:
  -h | --help      Print this help and exits
  -q | --quiet     Be quiet
  -V | --version   Prints version and exits
  -r | --rename    Changed the uploaded file name
  -k | --insecure  Uses curl with -k option (https insecure)
  -p | --password  Uses env var $CLOUDSEND_PASSWORD as share password
                   You can 'export CLOUDSEND_PASSWORD' at your system, or set it at the call.
                   Please remeber to also call -p to use the password set.

Note:
  Parameters must come before <filepath> <folderLink>

Use:
  ./cloudsend.sh [parameters] <filepath> <folderLink>
  CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -p <filepath> <folderLink>

Example:
  ./cloudsend.sh './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
  ./cloudsend.sh -r 'RenamedFile.txt' './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'
   CLOUDSEND_PASSWORD='MySecretPass' ./cloudsend.sh -p './myfile.txt' 'https://cloud.mydomain.net/s/fLDzToZF4MLvG28'

```

### Questions
##### Whats is "https://cloud.mydomain.net/s/fLDzToZF4MLvG28"? What is a "folderlink" ? Where do i get it from? Specially the "s/fLDzToZF4MLvG28" part?
You have to share a Folder writable and use the generated link
![Shared Folder Screenshot](https://user-images.githubusercontent.com/10356892/52477908-e1d4e400-2ba3-11e9-8658-0b4ac2c43114.png)

