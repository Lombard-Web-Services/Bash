# Bash
Some tools I have programmed in Bash

## BetC.sh Backup & Compress
A script that permit to backup all the files of a mobile phone folder and transfer them on local directory , and compress those which have a specific size in Kb for images and in Mb for videos by re-encoding. The script is able to pack JPG and MP4 files in  zip , keeping the directory listing, to connect to android via Android debug bridge, to use Nvidia GPU for faster processing, and remove junk files and folders. All of this in one line.

### Usage
```sh
Usage: ./BetC.sh source_directory destination_directory [-j jpg_size_kb] [-m mp4_size_mb] [-g yes|no] [-a yes|no] [-z yes|no] [-r yes|no]
  -j: Taille max pour JPG en KB (défaut: 700)
  -m: Taille max pour MP4 en MB (défaut: 10)
  -g: Utiliser le GPU pour FFmpeg (yes/no, défaut: no)
  -a: Récupérer depuis un appareil Android (yes/no, défaut: no)
  -z: Compresser le répertoire de destination (yes/no, défaut: no)
  -r: Supprimer les fichiers/dossiers indésirables (yes/no, défaut: no)

Example: ./BetC.sh DCIM/ out -j 700 -m 10 -r yes
```
### Features
Listing :
* Backup a folder from android device to local directory 
* Compress (re-encode) files such as JPG or MP4 with ffmpeg and convert
* Can create a zip at the end
* Can remove Junk
* Can be adjusted by size Kb for images, Mb for videos
* Do not compress files by given size
* GPU compliant for ffmpeg

## meta_transfer.sh transfer metadata instantly from one place to another
meta_transfer.sh is a script that permit to transfer metadata instantly from one place to another. This script use only exiftool and bash. Source file(s) contained into the directory(ies) must have the same name than the destination files.

#### Metadata 
The metadata that the script transfers if it's found are the following .
```sh
"File Modification Date/Time"
"File Access Date/Time"           
"File Inode Change Date/Time"
"Shutter Speed"
"Create Date"
"Date/Time Original"
"Modify Date"
"Circle Of Confusion"
"Field Of View"
"Focal Length"
"Hyperfocal Distance"
"Light Value"
"Scale Factor To 35 mm Equivalent"
"Aperture"
"GPS Coordinates"
"Android Version"
"Android Manufacturer"
"Android Model"
"Track Create Date"
"Track Modify Date"
"Media Create Date"
"Media Modify Date" 
"GPS Latitude"
"GPS Longitude"
"Rotation"
"GPS Position"
```
## meta_refresh refresh modification date and create date to now
This script permit to refresh the date of creation and modification date of each files recursively to the actual date.

#### Usage 
compile meta_refresh.c or execute meta_refresh.sh
```sh
Usage: ./meta_refresh [-v|--verbose] [--heuristic] <file/directory>
Will use current date: 2025:03:08 18:43:13
```

### options
* Verbose permit to show debug messages
* heuristic permit to watch for metadata containing "date" and modify them on the fly


### Credits 
Grok 3.0

