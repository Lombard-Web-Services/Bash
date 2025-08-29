# 🐚 Bash 

Some tools I have programmed in Bash

## 💾 BetC.sh Backup & Compress 

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

## 📥 meta_transfer.sh 

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
## ⏰ meta_refresh 

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

## 📂 file_sort 

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
* download is the directory path (relative or absolute)
* 10 is for files which size exceed 10Mb

Note : only arguments such as  <size_in_mb> and <directory_path> are mandatory.

## ☕ java_webserver_setup.sh 

**java_webserver_setup.sh** is a  java web server setup for linux supporting html javascript and database storage. This script generate automatically : directories, Maven Configuration (pom.xml),Main Application (MyWebServerApplication.java), REST Controller (DataController.java), HTML File (src/main/resources/static/index.html), JavaScript File (src/main/resources/static/script.js), Database Config (src/main/resources/application.properties)

### Structure
Here is the structure where the files are created from the WD (working directory)
```
my-web-server/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── example/
│   │   │           ├── MyWebServerApplication.java  (Main app)
│   │   │           └── controller/
│   │   │               └── DataController.java     (REST API)
│   │   └── resources/
│   │       ├── static/
│   │       │   ├── index.html                  (HTML file)
│   │       │   └── script.js                     (JavaScript file)
│   │       └── application.properties          (Database config)
├── pom.xml                                     (Maven dependencies)
└── run-server.sh                                     (Bash script)
```

### Db config
Database Config (src/main/resources/application.properties)
Configures the H2 database (runs in-memory for now).
```
spring.datasource.url=jdbc:h2:mem:testdb
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=
spring.h2.console.enabled=true
```
You can later add more features such as :
* MySQL/PostgreSQL by updating pom.xml and application.properties.
* Adding CRUD operations in DataController.java with a database (e.g., using Spring Data JPA).
* Adding Spring Security for authentication.

### Usage 
Make It Executable:
Run: 
```sh
chmod +x java_webserver_setup.sh
```
Execute:
```sh
./java_webserver_setup.sh
```

## 🔒 DKIM & PKCS12 Keygen 🔑

dkim_pkcs12_keygen.sh is a shell script that permit to generate a 2048 DKIM Key (DNS) and PKCS12 keys (Imap) for mailcow external letsencrypt certificates.

### Usage
Create execution rights with chmod +x **dkim_pkcs12_keygen.sh** , configure the directories of the certificates in the script, and execute.
```sh
./dkim_pkcs12_keygen.sh
Debug: Generating private key...
Debug: Extracting public key...
Debug: Creating DNS TXT record...
v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
Debug: Write keys and DNS record to ./dkim_keys/? (yes/no):
```

## 🔁 Replace 

Replace is a program **./replace** that permit to replace a string recursively. 2 versions of this program exist, one version coded in C lang which do not use the library sed , grep , find, and  rename another in bash script using these libraries.

### Usage: 
3 options could be selected : 
* str_replace to replace a string in files recursively 
* fld_replace to replace folder(s) names and filenames recursively
* comb_replace that use  str_replace and fld_replace at the same place

Set -v for verbose output.

```sh
Usage: ./replace "search_string" "replace_string" [-i directory] [-v] [--opt {str_replace|fld_replace|comb_replace}]
Examples:
  ./replace "old" "new"              # Default: comb_replace in current directory
  ./replace "old" "new" -i /path -v      # comb_replace in specified directory with verbose output
  ./replace "old" "new" -i /path --opt str_replace

```
## 📸 Fullpage Screenshot OCR 

**fullpage_screenshot_OCR.sh** is a program that permit to take a fullpage screenshot and output the results as text or csv. The program use wkhtmltoimage to generate the full page screenshot and tesseractOCR to perform the optical character recognition to further generate a csv.

### Usage : 
Firstly give executable rights to the file with chmod +x fullpage_screenshot_OCR.sh and you can execute the command as below.

```sh
Usage: ./fullpage_screenshot_OCR.sh -u <URL> [-c] [-t] [-j] [-d <delimiter>] [-p <png_file>] [-s <csv_file>] [-x <txt_file>]
  -u <URL>   : Specify the URL to capture (required)
  -c   : Save output as CSV with specified delimiter
  -t   : Save output as raw TXT without post-processing
  -j   : Enable JavaScript in wkhtmltoimage (default: disabled)
  -d <delimiter>: Set CSV delimiter (default: ';')
  -p <png_file> : Specify PNG screenshot filename (default: derived from URL)
  -s <csv_file> : Specify CSV output filename (default: derived from URL)
  -x <txt_file> : Specify TXT output filename (default: derived from URL)
At least one of -c or -t must be specified.
```
### v2 fullpage_screenshot_OCR_v2.sh
Some improvement has been added into the v2, the program is refactored, **fullpage_screenshot_OCR_v2.sh**, it can now work with headless chromium, Dom content retreival, screen-width and screen-height as option, delay, and network features.

### Usage
As the first version , chmod +x before use. Use the scripts as user and non root user.

```sh
Usage: ./fullpage_screenshot.sh -u <URL> [options]
  -u <URL>   : Specify the URL to capture (required)
  -r <tool>  : Screenshot tool: 'wkhtmltoimage' or 'chromium' (default: 'wkhtmltoimage')
  -w <width> : Screen width in pixels (default: 1280)
  -h <height>: Screen height in pixels (default: 1920)
  -j         : Enable JavaScript execution (default: disabled)
  -e <delay> : Delay in milliseconds for JS execution (optional, supports decimals)
  -l <lang>  : OCR language (default: 'eng')
  -d <delim> : CSV delimiter (default: ';')
  -f <folder>: Output folder (default: 'generated')
  -p <ip:port>: Enable SOCKS5 proxy for Chromium (e.g., '127.0.0.1:9050')
Output modes (exactly one required, or none for default):
  -s         : Screenshot only
  -c         : Screenshot + CSV OCR
  -t         : Screenshot + TXT OCR
  -C         : CSV OCR only (delete screenshot after)
  -T         : TXT OCR only (delete screenshot after)
  -m         : DOM content only (Chromium only)
  -a         : Screenshot + TXT OCR + CSV OCR
Default (no mode specified): Screenshot + TXT OCR + CSV OCR + DOM (Chromium only)
```
## 💻 PEtransfer 

**PEtransfer** is a c program that permit to transfer the PEheader from one executable file to another. Keeping the icon resource, and the section table as option (for testing purpose).   
### Usage :
Compile this program with gcc, (MinGW  or Visual Studio).
```sh
gcc -o PEtransfer pe_transfer.c
```
To transfer with the section table add the -s flag.
```sh
PEtransfer source.exe target.exe
```
---

## ⚖️ Credits & License 📚

**License:** 

![Logo de la licence CC BY-NC-ND](CC_BY-NC-ND.png)

**Author:** Thibaut LOMBARD

**GitHub:** [https://github.com/Lombard-Web-Services/Bash](https://github.com/Lombard-Web-Services/Bash)

### 📖 License Details 📜
Some work marked as GNU license stays in GPL3, others which are not marked are in Creative Commons.
This work is licensed under the **Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License**. To view a copy of this license, visit [http://creativecommons.org/licenses/by-nc-nd/4.0/](http://creativecommons.org/licenses/by-nc-nd/4.0/) or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.

The main conditions of this license are:
* **Attribution (BY):** You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
* **NonCommercial (NC):** You may not use the material for commercial purposes.
* **NoDerivatives (ND):** If you remix, transform, or build upon the material, you may not distribute the modified material.
