#!/bin/bash
########################################
##  By LombardWeb (Thibaut LOMBARD)   ##  
##  Link to your phone and compress   ##
##        GNU License GPL3.O          ##
########################################
#./BetC.sh DCIM/ out -j 700 -m 10 -r yes

# Vérifier si les outils requis sont installés
command -v convert >/dev/null 2>&1 || { echo "ImageMagick est requis"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "FFmpeg est requis"; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum est requis"; exit 1; }
command -v adb >/dev/null 2>&1 || { echo "adb est requis pour l'option Android"; }
command -v zip >/dev/null 2>&1 || { echo "zip est requis pour l'option de compression"; }

# Fonction d'aide
usage() {
 echo "Usage: $0 source_directory destination_directory [-j jpg_size_kb] [-m mp4_size_mb] [-g yes|no] [-a yes|no] [-z yes|no] [-r yes|no]"
 echo "  -j: Taille max pour JPG en KB (défaut: 700)"
 echo "  -m: Taille max pour MP4 en MB (défaut: 10)"
 echo "  -g: Utiliser le GPU pour FFmpeg (yes/no, défaut: no)"
 echo "  -a: Récupérer depuis un appareil Android (yes/no, défaut: no)"
 echo "  -z: Compresser le répertoire de destination (yes/no, défaut: no)"
 echo "  -r: Supprimer les fichiers/dossiers indésirables (yes/no, défaut: no)"
 exit 1
}

# Valeurs par défaut
JPG_SIZE_KB=700
MP4_SIZE_MB=10
USE_GPU="no"
USE_ANDROID="no"
ZIP_DEST="no"
REMOVE_JUNK="no"

# Vérifier si les arguments minimum sont fournis
if [ $# -lt 2 ]; then
 usage
fi

SOURCE_DIR="$1"
DEST_DIR="$2"
shift 2

# Analyser les arguments de la ligne de commande
while [ $# -gt 0 ]; do
 case "$1" in
  -j) JPG_SIZE_KB="$2"; shift 2 ;;
  -m) MP4_SIZE_MB="$2"; shift 2 ;;
  -g) USE_GPU="$2"; [ "$USE_GPU" != "yes" ] && [ "$USE_GPU" != "no" ] && { echo "Option GPU invalide"; usage; }; shift 2 ;;
  -a) USE_ANDROID="$2"; [ "$USE_ANDROID" != "yes" ] && [ "$USE_ANDROID" != "no" ] && { echo "Option Android invalide"; usage; }; shift 2 ;;
  -z) ZIP_DEST="$2"; [ "$ZIP_DEST" != "yes" ] && [ "$ZIP_DEST" != "no" ] && { echo "Option zip invalide"; usage; }; shift 2 ;;
  -r) REMOVE_JUNK="$2"; [ "$REMOVE_JUNK" != "yes" ] && [ "$REMOVE_JUNK" != "no" ] && { echo "Option suppression indésirables invalide"; usage; }; shift 2 ;;
  *) echo "Option inconnue: $1"; usage ;;
 esac
done

# Gérer la récupération depuis Android si activée
if [ "$USE_ANDROID" = "yes" ]; then
 if ! command -v adb >/dev/null 2>&1; then
  echo "adb est requis pour l'option Android mais non trouvé"
  exit 1
 fi
 echo "Récupération depuis l'appareil Android: $SOURCE_DIR vers $DEST_DIR..."
 adb pull "$SOURCE_DIR" "$DEST_DIR" || { echo "Échec de la récupération depuis Android"; exit 1; }
 SOURCE_DIR="$DEST_DIR"  # Après récupération, SOURCE_DIR devient la destination locale
fi

# Vérifier si le répertoire source existe
if [ ! -d "$SOURCE_DIR" ]; then
 echo "Le répertoire source '$SOURCE_DIR' n'existe pas"
 exit 1
fi

# Créer le répertoire de destination si non créé par adb pull
mkdir -p "$DEST_DIR" || { echo "Échec de la création du répertoire de destination"; exit 1; }

# Déclarer les tableaux associatifs (pour le tri uniquement)
declare -A files_by_ext
declare -A sizes_by_ext
declare -A hashes_by_ext
declare -A modtimes_by_ext

# Préfixe FFmpeg pour GPU
FFMPEG_PREFIX="ffmpeg"
if [ "$USE_GPU" = "yes" ]; then
 FFMPEG_PREFIX="__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia ffmpeg -hwaccel cuda"
fi

# Fonction pour traiter un fichier individuellement
process_single_file() {
 local file="$1"
 local src_dir="$2"
 local dest_dir="$3"
 
 # Obtenir les détails du fichier
 ext="${file##*.}"
 ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
 size=$(du -k "$file" | cut -f1)
 hash=$(sha256sum "$file" | cut -d' ' -f1)
 modtime=$(stat -c '%y' "$file")
 
 # Ignorer si pas d'extension ou si l'extension est le nom complet
 [[ "$file" == *"."* ]] || return
 [[ "$ext" != "${file##*/}" ]] || return
 
 # Stocker dans les tableaux (pour le tri uniquement)
 files_by_ext["$ext"]+="${file}"$'\n'
 sizes_by_ext["$ext"]+="${size}"$'\n'
 hashes_by_ext["$ext"]+="${hash}"$'\n'
 modtimes_by_ext["$ext"]+="${modtime}"$'\n'
 
 # Calculer le chemin de destination
 relative_path="${file#$src_dir/}"
 dest_file="$dest_dir/$relative_path"
 dest_dir_path=$(dirname "$dest_file")
 mkdir -p "$dest_dir_path"
 
 # Vérifier et convertir avec une structure case
 case "$ext" in
  jpg|jpeg)
   if [ "$size" -gt "$JPG_SIZE_KB" ]; then
    echo "Conversion de $file (${size}KB) vers une taille réduite (<${JPG_SIZE_KB}KB)..."
     # Variante de conversion sur la qualité :
     #convert "$file" -quality 85 -resize 80% "$dest_file" || {
     convert "$file" -define jpeg:extent="$JPG_SIZE_KB"kb "$dest_file" || {
     echo "Échec de la conversion de $file"
     cp "$file" "$dest_file"
    }
   else
    cp "$file" "$dest_file" || echo "Échec de la copie de $file"
   fi
   ;;
  mp4)
   max_size=$((MP4_SIZE_MB * 1024))
   if [ "$size" -gt "$max_size" ]; then
    echo "Conversion de $file (${size}KB) vers une taille réduite (<${MP4_SIZE_MB}MB)..."
    # Exécuter FFmpeg et attendre explicitement sa fin
    #$FFMPEG_PREFIX ffmpeg -i "$file" -filter_complex 'fps=24,scale=854:480' -c:v libx264 -pix_fmt yuv420p -c:a mp3 "$dest_file"
    to_eval_encode_video="echo '$FFMPEG_PREFIX -i $file -c:v libx264 -pix_fmt yuv420p -vf fps=24,scale=854:480 -c:a mp3 $dest_file'"
    echo "debug : executing $to_eval_encode_video"
    eval "$to_eval_encode_video" 
    $FFMPEG_PREFIX -i $file -c:v libx264 -pix_fmt yuv420p -vf fps=24,scale=854:480 -c:a mp3 $dest_file -y </dev/null 2>/dev/null
    # test de fonctionnement
    #ffmpeg -i "$file" -c:v libx264 -pix_fmt yuv420p -vf fps=24,scale=854:480 -c:a mp3 "$dest_file" -y </dev/null 2>/dev/null
    ffmpeg_pid=$!  # Capturer le PID du dernier processus en arrière-plan (bien que non nécessaire ici car pas en arrière-plan)
    wait $ffmpeg_pid  # Attendre spécifiquement la fin de FFmpeg
    # Vérifier l'état après que FFmpeg soit terminé
    if [ $? -ne 0 ]; then
     echo "Échec de la conversion de $file"
     cp "$file" "$dest_file"
    fi
   else
    cp "$file" "$dest_file" || echo "Échec de la copie de $file"
   fi
   ;;
  *)
   cp "$file" "$dest_file" || echo "Échec de la copie de $file"
   ;;
 esac
}

# Fonction pour traiter les fichiers
process_files() {
 local src_dir="$1"
 local dest_dir="$2"
 
 echo "Traitement des fichiers depuis $src_dir..."
 
 # Trouver tous les fichiers et les traiter un par un
 find "$src_dir" -type f -print0 | while IFS= read -r -d '' file; do
  process_single_file "$file" "$src_dir" "$dest_dir"
 done
}

# Fonction pour supprimer les fichiers et dossiers indésirables
remove_junk() {
 local dir="$1"
 if [ "$REMOVE_JUNK" = "yes" ]; then
  echo "Suppression des fichiers et dossiers indésirables de $dir..."
  find "$dir" -type f -name ".*" -exec rm -f {} \; && echo "Fichiers indésirables supprimés"
  find "$dir" -type d -name ".*" -exec rm -rf {} \; && echo "Dossiers indésirables supprimés"
 fi
}

# Fonction pour compresser le répertoire de destination
zip_destination() {
 local dir="$1"
 if [ "$ZIP_DEST" = "yes" ]; then
  if ! command -v zip >/dev/null 2>&1; then
   echo "zip est requis pour l'option de compression mais non trouvé"
   exit 1
  fi
  local zip_file="${dir}_$(date +%Y%m%d_%H%M%S).zip"
  echo "Compression de $dir en $zip_file..."
  cd "$(dirname "$dir")" && zip -r "$zip_file" "$(basename "$dir")" || {
   echo "Échec de la compression de $dir"
  }
  echo "Créé $zip_file"
 fi
}

# Exécution principale
echo "Début du traitement des fichiers..."
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo "Seuil JPG: ${JPG_SIZE_KB}KB"
echo "Seuil MP4: ${MP4_SIZE_MB}MB"
echo "Utilisation GPU: $USE_GPU"
echo "Utilisation Android: $USE_ANDROID"
echo "Compression destination: $ZIP_DEST"
echo "Suppression indésirables: $REMOVE_JUNK"

process_files "$SOURCE_DIR" "$DEST_DIR"
remove_junk "$DEST_DIR"
zip_destination "$DEST_DIR"

echo "Traitement terminé."
