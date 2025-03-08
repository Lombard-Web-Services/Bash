// by Thibaut LOMBARD (LombardWeb)
// this executable script (once compiled) permit to set metadata of modification date, and create date to the date of today
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <stdarg.h>  // Added for va_list

#define MAX_PATH 4096
#define MAX_CMD 8192

// Global flags
int verbose = 0;
int heuristic = 0;

// Arrays of tags
const char *metadata_tags[] = {
 "MediaCreateDate",
 "MediaModifyDate",
 "CreateDate",
 "ModifyDate",
 "TrackCreateDate",
 "TrackModifyDate",
 NULL
};

const char *filesystem_tags[] = {
 "FileModifyDate",
 "FileAccessDate",
 "FileInodeChangeDate",
 NULL
};

// Verbose output function (renamed from vprintf to verbose_print)
void verbose_print(const char *format, ...) {
 if (verbose) {
  va_list args;
  va_start(args, format);
  vfprintf(stdout, format, args);  // Using vfprintf instead of vprintf
  va_end(args);
 }
}

// Check if exiftool exists
int check_exiftool() {
 return system("command -v exiftool >/dev/null 2>&1") == 0;
}

// Execute command and return status
int execute_command(const char *cmd) {
 if (verbose) {
  printf("Executing: %s\n", cmd);
 }
 return system(cmd);
}

// Check if tag exists in file
int tag_exists(const char *file, const char *tag) {
 char cmd[MAX_CMD];
 snprintf(cmd, MAX_CMD, "exiftool -\"%s\" \"%s\" | grep -q \"%s\"", tag, file, tag);
 return system(cmd) == 0;
}

// Process a single file
void process_file(const char *file) {
 struct stat st;
 if (stat(file, &st) != 0 || !S_ISREG(st.st_mode)) {
  return;  // Skip if not a regular file
 }

 // Get current time
 time_t now = time(NULL);
 struct tm *tm = localtime(&now);
 char date_str[20];
 strftime(date_str, sizeof(date_str), "%Y:%m:%d %H:%M:%S", tm);

 verbose_print("Processing: %s\n", file);
 verbose_print("Using date: %s\n", date_str);

 char cmd[MAX_CMD];

 if (heuristic) {
  // Heuristic mode
  FILE *fp;
  snprintf(cmd, MAX_CMD, "exiftool -a -G1 \"%s\"", file);
  fp = popen(cmd, "r");
  if (fp) {
   char line[1024];
   while (fgets(line, sizeof(line), fp)) {
    if (strcasestr(line, "date")) {
     char *colon = strchr(line, ':');
     if (colon) {
      *colon = '\0';
      char *tag = line;
      char *value = colon + 1;
      // Clean up tag and value
      while (*tag == ' ' || tag[0] == '[') tag++;
      while (*value == ' ') value++;
      char *tag_end = tag + strlen(tag) - 1;
      while (*tag_end == ' ') *tag_end-- = '\0';
      char *val_end = value + strlen(value) - 1;
      while (*val_end == '\n' || *val_end == ' ') *val_end-- = '\0';

      // Check if value looks like a date
      if (strstr(value, ":") || strstr(value, "-") || strstr(value, "/")) {
       if (strlen(value) >= 8) {  // Rough date length check
        verbose_print("Updating heuristic tag %s for %s\n", tag, file);
        snprintf(cmd, MAX_CMD, "exiftool -overwrite_original -\"%s=%s\" \"%s\" >/dev/null 2>&1", 
          tag, date_str, file);
        if (execute_command(cmd) == 0) {
         verbose_print("Successfully updated %s\n", tag);
        } else {
         verbose_print("Failed to update %s\n", tag);
        }
       }
      }
     }
    }
   }
   pclose(fp);
  }
 } else {
  // Normal mode: process specific metadata tags
  for (int i = 0; metadata_tags[i]; i++) {
   if (tag_exists(file, metadata_tags[i])) {
    verbose_print("Updating %s for %s\n", metadata_tags[i], file);
    snprintf(cmd, MAX_CMD, "exiftool -overwrite_original -\"%s=%s\" \"%s\" >/dev/null 2>&1", 
      metadata_tags[i], date_str, file);
    if (execute_command(cmd) == 0) {
     verbose_print("Successfully updated %s\n", metadata_tags[i]);
    } else {
     verbose_print("Failed to update %s\n", metadata_tags[i]);
    }
   } else {
    verbose_print("Skipping %s - not present in file\n", metadata_tags[i]);
   }
  }
 }

 // Process filesystem tags
 for (int i = 0; filesystem_tags[i]; i++) {
  verbose_print("Updating %s for %s\n", filesystem_tags[i], file);
  snprintf(cmd, MAX_CMD, "exiftool -P -\"%s=%s\" \"%s\" >/dev/null 2>&1", 
    filesystem_tags[i], date_str, file);
  if (execute_command(cmd) == 0) {
   verbose_print("Successfully updated %s\n", filesystem_tags[i]);
  } else {
   verbose_print("Failed to update %s\n", filesystem_tags[i]);
  }
 }
 verbose_print("------------------------\n");
}

// Process directory recursively
void process_directory(const char *dir) {
 DIR *dp = opendir(dir);
 if (!dp) {
  fprintf(stderr, "Error: Cannot open directory %s\n", dir);
  return;
 }

 verbose_print("Processing directory recursively: %s\n", dir);

 struct dirent *entry;
 char path[MAX_PATH];
 while ((entry = readdir(dp))) {
  if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
   continue;
  }
  
  snprintf(path, MAX_PATH, "%s/%s", dir, entry->d_name);
  struct stat st;
  if (stat(path, &st) == 0) {
   if (S_ISREG(st.st_mode)) {
    process_file(path);
   } else if (S_ISDIR(st.st_mode)) {
    process_directory(path);
   }
  }
 }
 closedir(dp);
}

int main(int argc, char *argv[]) {
 if (!check_exiftool()) {
  fprintf(stderr, "Error: exiftool is not installed. Please install it first.\n");
  fprintf(stderr, "On Debian/Ubuntu: sudo apt-get install libimage-exiftool-perl\n");
  fprintf(stderr, "On Red Hat/Fedora: sudo dnf install perl-Image-ExifTool\n");
  return 1;
 }

 // Parse arguments
 char *target = NULL;
 for (int i = 1; i < argc; i++) {
  if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--verbose") == 0) {
   verbose = 1;
  } else if (strcmp(argv[i], "--heuristic") == 0) {
   heuristic = 1;
  } else if (!target) {
   target = argv[i];
  } else {
   fprintf(stderr, "Error: Too many arguments\n");
   fprintf(stderr, "Usage: %s [-v|--verbose] [--heuristic] <file/directory>\n", argv[0]);
   return 1;
  }
 }

 if (!target) {
  char date_str[20];
  time_t now = time(NULL);
  struct tm *tm = localtime(&now);
  strftime(date_str, sizeof(date_str), "%Y:%m:%d %H:%M:%S", tm);
  fprintf(stderr, "Usage: %s [-v|--verbose] [--heuristic] <file/directory>\n", argv[0]);
  fprintf(stderr, "Will use current date: %s\n", date_str);
  return 1;
 }

 struct stat st;
 if (stat(target, &st) != 0) {
  fprintf(stderr, "Error: %s is not a valid file or directory\n", target);
  return 1;
 }

 if (S_ISREG(st.st_mode)) {
  process_file(target);
 } else if (S_ISDIR(st.st_mode)) {
  process_directory(target);
 } else {
  fprintf(stderr, "Error: %s is not a valid file or directory\n", target);
  return 1;
 }

 verbose_print("Processing complete!\n");
 return 0;
}
