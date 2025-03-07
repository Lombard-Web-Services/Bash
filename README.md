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
List of some features added to the script.

#### Command Line Arguments:
* Requires source and destination directories
* Optional -j for JPG size in KB (default 700)
* Optional -m for MP4 size in MB (default 10)
#### File Processing:
* Copies all files to destination maintaining directory structure
* Converts JPG files > specified KB using ImageMagick
* Converts MP4 files > specified MB using FFmpeg
* Direct conversion to destination (no temporary files in source)

#### Array Storage:
 * Extension (files_by_ext)
 * Filename (implicit in path)
 * SHA256 hash (hashes_by_ext)
 * Filesize (sizes_by_ext)

#### Destination Directory:
* Maintains exact filename and extension from source
* Creates subdirectories as needed

#### GPU management
* simple and intuitive gpu management for Nvidia Graphic cards supporting CUDA
* ability to disable the functionnality

#### Mobile device Android phone/tablet Connection
* ability for this script to connect through Android debug bridge to pull the directory and to transfer its content instantly
* Adb bridge is faster than PTP protocol, or MTP protocol

#### Zip compression
* Winzip is used by most of platform
* at final stage you are able to zip the directory filesize reduced in a Zip file

## meta_transfer.sh Copy metadata from one place to another
meta_transfer.sh is a script that permit to transfer metadata instantly from one place to another. This script use only exiftool and bash. Source file(s) contained into the directory(ies) must have the same name than the destination files.

#### Metadata 
The metadata that the script modifies are the following.
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

#### Usage 
You can specify a directory or a file. 
```sh
Usage: ./meta_transfer.sh <source_file_or_directory> <destination_file_or_directory>
```

### Credits 
Grok 3.0

