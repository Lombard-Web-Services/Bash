#!/bin/bash
# By thibaut LOMBARD
# Calcul le nombre de seconde de différence d'execution des 2 commandes (avec ou sans le prefixe GPU)
SECONDS=0
ffmpeg -loglevel quiet -i input.mp4 -c:v libx264 -pix_fmt yuv420p -vf fps=24,scale=854:480 -c:a mp3 output.mp4 
echo "1ere commande executée en $SECONDS secondes"
firststop=$SECONDS
SECONDS=0
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia ffmpeg -hwaccel cuda -loglevel quiet -i input.mp4 -c:v libx264 -pix_fmt yuv420p -vf fps=24,scale=854:480 -c:a mp3 output2.mp4
echo "2eme commande executée en $SECONDS secondes"
stop=$EPOCHREALTIME
echo "Difference $((SECONDS - firststop)). NB: Si le nombre est négatif la seconde commande est plus rapide que la premiere"
