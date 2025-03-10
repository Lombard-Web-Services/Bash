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

## file_sort find files by size & sort by date, size, filename
It's a program that permit to find all files exceeding an especific size in Mb, to sort them by date , filename or size.
### How to use
For finding all files exceeding 10 Mb in the download folder, and sort the result into file_sorter_result_[date].log
```sh
Usage:
file_sort <size_in_mb> <directory_path> [-v|--verbose] [--sort-by <date|filename|size>] [--sort-order <asc|desc>]
```
Command : 
```sh
./file_sort.sh 10 download/ --sort-by filename --sort-order asc -v
```
* The -v argument permit to output the log (verbose)
* --sort-order asc define the sorting by ascending order
* --sort-by filename permit to sort by filename
* download is the directory path (relative or not)
* 10 is for files which size exceed 10Mb

Note : only arguments such as  <size_in_mb> and <directory_path> are mandatory.

### Credits 
Grok 3.0

