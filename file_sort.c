// By Thibaut LOMBARD (LombardWeb)
// file_sort.sh Permit to find all files (recursively) exceeding an especific size in Mb and can sort them by date, filename or size

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <libgen.h>
#include <stdbool.h>
#include <errno.h>
#include <limits.h>

#define MAX_FILES 10000
#define PATH_MAX_LEN 4096
#define DATE_STR_LEN 64

// Structure to hold file info
typedef struct {
 char date[DATE_STR_LEN];
 double size_mb;
 char filename[PATH_MAX_LEN];
 char extension[PATH_MAX_LEN];
 char rel_path[PATH_MAX_LEN];
 char abs_path[PATH_MAX_LEN];
} FileInfo;

// Global variables
FileInfo files[MAX_FILES];
int file_count = 0;
bool has_errors = false;

// Function to get extension
void get_extension(const char *filename, char *extension) {
 const char *dot = strrchr(filename, '.');
 if (dot && dot != filename) {
  strcpy(extension, dot + 1);
 } else {
  strcpy(extension, "no_extension");
 }
}

// Function to count total files for progress
long count_files(const char *dir_path) {
 long count = 0;
 DIR *dir = opendir(dir_path);
 if (!dir) return 0;

 struct dirent *entry;
 char full_path[PATH_MAX_LEN];
 while ((entry = readdir(dir)) != NULL) {
  if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;
  snprintf(full_path, PATH_MAX_LEN, "%s/%s", dir_path, entry->d_name);
  struct stat st;
  if (stat(full_path, &st) == -1) continue;
  if (S_ISDIR(st.st_mode)) {
   count += count_files(full_path);
  } else if (S_ISREG(st.st_mode)) {
   count++;
  }
 }
 closedir(dir);
 return count;
}

// Function to process directory recursively
void process_directory(const char *dir_path, const char *base_path, double min_size_mb, long total_files, long *processed_files, FILE *debug_file, bool verbose) {
 DIR *dir = opendir(dir_path);
 if (!dir) {
  if (verbose) fprintf(debug_file, "Error: Could not open directory '%s': %s\n", dir_path, strerror(errno));
  has_errors = true;
  return;
 }

 struct dirent *entry;
 char full_path[PATH_MAX_LEN];
 while ((entry = readdir(dir)) != NULL) {
  if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;

  snprintf(full_path, PATH_MAX_LEN, "%s/%s", dir_path, entry->d_name);
  struct stat st;
  if (stat(full_path, &st) == -1) {
   if (verbose) fprintf(debug_file, "Error: Could not read stats of '%s': %s\n", full_path, strerror(errno));
   has_errors = true;
   continue;
  }

  if (S_ISDIR(st.st_mode)) {
   process_directory(full_path, base_path, min_size_mb, total_files, processed_files, debug_file, verbose);
  } else if (S_ISREG(st.st_mode)) {
   (*processed_files)++;
   double size_mb = st.st_size / 1048576.0;
   if (size_mb > min_size_mb) {
    if (file_count >= MAX_FILES) {
     fprintf(stderr, "Error: Too many files, increase MAX_FILES\n");
     exit(1);
    }

    // Date
    strftime(files[file_count].date, DATE_STR_LEN, "%Y-%m-%d %H:%M:%S %z", localtime(&st.st_mtime));
    files[file_count].size_mb = size_mb;

    // Filename
    strcpy(files[file_count].filename, entry->d_name);

    // Extension
    get_extension(entry->d_name, files[file_count].extension);

    // Relative path
    snprintf(files[file_count].rel_path, PATH_MAX_LEN, "%s", full_path + strlen(base_path) + 1);

    // Absolute path
    realpath(full_path, files[file_count].abs_path);

    // Shell output
    printf("File #%d:\n", file_count);
    printf("  Date: %s\n", files[file_count].date);
    printf("  Size: %.2f MB\n", files[file_count].size_mb);
    printf("  Extension: %s\n", files[file_count].extension);
    printf("  Relative Path: %s\n", files[file_count].rel_path);
    printf("  Absolute Path: %s\n", files[file_count].abs_path);
    printf("-------------------\n");

    file_count++;
   }

   // Progress bar simulation
   if (total_files > 0) {
    float progress = (*processed_files * 100.0) / total_files;
    fprintf(stderr, "\rProgress: %.1f%%", progress);
    fflush(stderr);
   }
  }
 }
 closedir(dir);
}

// Comparison functions for sorting
int compare_by_date_desc(const void *a, const void *b) {
 return strcmp(((FileInfo *)b)->date, ((FileInfo *)a)->date);
}

int compare_by_date_asc(const void *a, const void *b) {
 return strcmp(((FileInfo *)a)->date, ((FileInfo *)b)->date);
}

int compare_by_filename_desc(const void *a, const void *b) {
 return strcmp(((FileInfo *)b)->filename, ((FileInfo *)a)->filename);
}

int compare_by_filename_asc(const void *a, const void *b) {
 return strcmp(((FileInfo *)a)->filename, ((FileInfo *)b)->filename);
}

int compare_by_size_desc(const void *a, const void *b) {
 return ((FileInfo *)b)->size_mb > ((FileInfo *)a)->size_mb ? 1 : -1;
}

int compare_by_size_asc(const void *a, const void *b) {
 return ((FileInfo *)a)->size_mb > ((FileInfo *)b)->size_mb ? 1 : -1;
}

int main(int argc, char *argv[]) {
 if (argc < 3) {
  printf("Usage: %s <size_in_mb> <directory_path> [-v|--verbose] [--sort-by <date|filename|size>] [--sort-order <asc|desc>]\n", argv[0]);
  return 1;
 }

 double min_size_mb = atof(argv[1]);
 if (min_size_mb <= 0) {
  printf("Error: Size must be a positive number (in MB)\n");
  return 1;
 }

 char *search_dir = argv[2];
 bool verbose = false;
 char *sort_by = "size";
 char *sort_order = "desc";

 for (int i = 3; i < argc; i++) {
  if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--verbose") == 0) {
   verbose = true;
  } else if (strcmp(argv[i], "--sort-by") == 0 && i + 1 < argc) {
   if (strcmp(argv[i + 1], "date") == 0 || strcmp(argv[i + 1], "filename") == 0 || strcmp(argv[i + 1], "size") == 0) {
    sort_by = argv[++i];
   } else {
    printf("Error: --sort-by must be 'date', 'filename', or 'size'\n");
    return 1;
   }
  } else if (strcmp(argv[i], "--sort-order") == 0 && i + 1 < argc) {
   if (strcmp(argv[i + 1], "asc") == 0 || strcmp(argv[i + 1], "desc") == 0) {
    sort_order = argv[++i];
   } else {
    printf("Error: --sort-order must be 'asc' or 'desc'\n");
    return 1;
   }
  }
 }

 if (access(search_dir, F_OK) != 0) {
  printf("Error: Directory '%s' does not exist\n", search_dir);
  return 1;
 }

 // Log files
 char debug_file_path[] = "debug.log";
 char result_file_path[PATH_MAX_LEN];
 time_t now = time(NULL);
 struct tm *t = localtime(&now);
 snprintf(result_file_path, PATH_MAX_LEN, "%s_result_%04d%02d%02d_%02d%02d%02d.log", basename(argv[0]), 
    t->tm_year + 1900, t->tm_mon + 1, t->tm_mday, t->tm_hour, t->tm_min, t->tm_sec);

 // Remove existing log files
 remove(debug_file_path);
 char pattern[PATH_MAX_LEN];
 snprintf(pattern, PATH_MAX_LEN, "%s_result_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].log", basename(argv[0]));
 DIR *dir = opendir(".");
 struct dirent *entry;
 while ((entry = readdir(dir)) != NULL) {
  if (strstr(entry->d_name, pattern)) remove(entry->d_name);
 }
 closedir(dir);

 FILE *debug_file = verbose ? fopen(debug_file_path, "w") : NULL;
 if (verbose && !debug_file) {
  perror("Error opening debug.log");
  return 1;
 }

 // Count total files
 long total_files = count_files(search_dir);
 long processed_files = 0;

 // Process directory
 process_directory(search_dir, search_dir, min_size_mb, total_files, &processed_files, debug_file, verbose);
 fprintf(stderr, "\n");  // Newline after progress bar

 // Sort files
 if (file_count > 0) {
  if (strcmp(sort_by, "date") == 0) {
   qsort(files, file_count, sizeof(FileInfo), strcmp(sort_order, "desc") ? compare_by_date_desc : compare_by_date_asc);
  } else if (strcmp(sort_by, "filename") == 0) {
   qsort(files, file_count, sizeof(FileInfo), strcmp(sort_order, "desc") ? compare_by_filename_desc : compare_by_filename_asc);
  } else {
   qsort(files, file_count, sizeof(FileInfo), strcmp(sort_order, "desc") ? compare_by_size_desc : compare_by_size_asc);
  }
 }

 // Write to result file if verbose
 if (verbose && file_count > 0) {
  FILE *result_file = fopen(result_file_path, "w");
  if (!result_file) {
   perror("Error opening result file");
   if (debug_file) fclose(debug_file);
   return 1;
  }
  fprintf(result_file, "Starting search for files larger than %.2fMB in %s\n", min_size_mb, search_dir);
  fprintf(result_file, "%-30s | %-10s | %-40s | %-10s | %-40s | %s\n", "Date", "Size", "Filename", "Extension", "Relative Path", "Absolute Path");
  fprintf(result_file, "%-30s | %-10s | %-40s | %-10s | %-40s | %s\n", "------------------------------", "----------", "----------------------------------------", "----------", "----------------------------------------", "----------------------------------------");
  for (int i = 0; i < file_count; i++) {
   fprintf(result_file, "%-30s | %-10.2f | %-40s | %-10s | %-40s | %s\n", 
     files[i].date, files[i].size_mb, files[i].filename, files[i].extension, files[i].rel_path, files[i].abs_path);
  }
  fprintf(result_file, "Total files found: %d\n", file_count);
  fclose(result_file);
 }

 // Clean up debug file
 if (debug_file) {
  if (!has_errors && ftell(debug_file) == 0) {
   fclose(debug_file);
   remove(debug_file_path);
  } else {
   fclose(debug_file);
  }
 }

 // Final output
 printf("Found %d files larger than %.2fMB in %s\n", file_count, min_size_mb, search_dir);
 if (verbose && file_count > 0) printf("Results written to: %s\n", result_file_path);
 if (has_errors && verbose) printf("Debug output written to: %s\n", debug_file_path);

 return 0;
}
