// By Thibaut LOMBARD (LombardWeb)
// Replace a given string by another Recursively
// Compile : gcc -o replace replace.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <stdbool.h>

#define MAX_PATH 4096
#define BUFFER_SIZE 8192

// Global variables for command-line arguments
char *search_string = NULL;
char *replace_string = NULL;
char *directory = NULL;
bool verbose = false;
char *operation = "comb_replace";

// Function to display usage
void usage(const char *prog_name) {
 fprintf(stderr, "Usage: %s \"search_string\" \"replace_string\" [-i directory] [-v] [--opt {str_replace|fld_replace|comb_replace}]\n", prog_name);
 fprintf(stderr, "Examples:\n");
 fprintf(stderr, "  %s \"old\" \"new\"     # Default: comb_replace in current directory\n", prog_name);
 fprintf(stderr, "  %s \"old\" \"new\" -i /path -v    # comb_replace in specified directory with verbose output\n", prog_name);
 fprintf(stderr, "  %s \"old\" \"new\" -i /path --opt str_replace\n", prog_name);
 exit(EXIT_FAILURE);
}

// Function to replace string in buffer
int replace_in_buffer(char *buffer, size_t buffer_size, const char *search, const char *replace, FILE *verbose_output) {
 int replacements = 0;
 char *pos = buffer;
 size_t search_len = strlen(search);
 size_t replace_len = strlen(replace);
 
 while ((pos = strstr(pos, search)) != NULL) {
  size_t tail_len = strlen(pos + search_len);
  if (pos + replace_len + tail_len - buffer >= buffer_size) {
   break; // Prevent buffer overflow
  }
  memmove(pos + replace_len, pos + search_len, tail_len + 1);
  memcpy(pos, replace, replace_len);
  replacements++;
  pos += replace_len;
  if (verbose && verbose_output) {
   fprintf(verbose_output, "Replacing '%s' with '%s' in current buffer position\n", search, replace);
  }
 }
 return replacements;
}

// Function to process a single file's contents
void replace_in_file(const char *filepath) {
 FILE *file = fopen(filepath, "r+");
 if (!file) {
  if (verbose) fprintf(stderr, "Cannot open file %s: %s\n", filepath, strerror(errno));
  return;
 }

 fseek(file, 0, SEEK_END);
 long file_size = ftell(file);
 if (file_size > BUFFER_SIZE - 1) {
  if (verbose) fprintf(stderr, "File %s too large for buffer\n", filepath);
  fclose(file);
  return;
 }
 rewind(file);

 char *buffer = malloc(file_size + 1);
 if (!buffer) {
  if (verbose) fprintf(stderr, "Memory allocation failed for %s\n", filepath);
  fclose(file);
  return;
 }

 size_t read_size = fread(buffer, 1, file_size, file);
 buffer[read_size] = '\0';

 FILE *temp_verbose = verbose ? tmpfile() : NULL;
 int replacements = replace_in_buffer(buffer, BUFFER_SIZE, search_string, replace_string, temp_verbose);

 if (replacements > 0) {
  rewind(file);
  ftruncate(fileno(file), 0);
  fwrite(buffer, 1, strlen(buffer), file);
  if (verbose) {
   printf("String replacement summary in %s:\n", filepath);
   rewind(temp_verbose);
   char line[1024];
   while (fgets(line, sizeof(line), temp_verbose) != NULL) {
    printf("%s", line);
   }
   printf("Total replacements made: %d\n", replacements);
  }
 }

 free(buffer);
 if (temp_verbose) fclose(temp_verbose);
 fclose(file);
}

// Function to replace string in a name and return new name
char *construct_new_name(const char *old_name, const char *search, const char *replace) {
 char *new_name = malloc(MAX_PATH);
 if (!new_name) {
  if (verbose) fprintf(stderr, "Memory allocation failed\n");
  return NULL;
 }
 strncpy(new_name, old_name, MAX_PATH - 1);
 new_name[MAX_PATH - 1] = '\0';

 char *pos = new_name;
 size_t search_len = strlen(search);
 size_t replace_len = strlen(replace);
 while ((pos = strstr(pos, search)) != NULL) {
  size_t tail_len = strlen(pos + search_len);
  size_t new_len = (pos - new_name) + replace_len + tail_len;
  if (new_len >= MAX_PATH) {
   if (verbose) fprintf(stderr, "New name too long for %s\n", old_name);
   free(new_name);
   return NULL;
  }
  memmove(pos + replace_len, pos + search_len, tail_len + 1);
  memcpy(pos, replace, replace_len);
  pos += replace_len;
 }
 return new_name;
}

// Function to rename a file or directory
void rename_path(const char *old_path, const char *parent_dir) {
 const char *basename = strrchr(old_path, '/');
 basename = basename ? basename + 1 : old_path;

 if (strstr(basename, search_string)) {
  char *new_basename = construct_new_name(basename, search_string, replace_string);
  if (!new_basename) return;

  char new_path[MAX_PATH];
  size_t parent_len = strlen(parent_dir);
  size_t new_base_len = strlen(new_basename);
  if (parent_len + new_base_len + 1 >= MAX_PATH) { // +1 for '/'
   if (verbose) fprintf(stderr, "Path too long: %s/%s\n", parent_dir, new_basename);
   free(new_basename);
   return;
  }
  
  snprintf(new_path, MAX_PATH, "%s/%s", parent_dir, new_basename);
  if (rename(old_path, new_path) == 0) {
   if (verbose) {
    printf("Renamed: %s -> %s\n", old_path, new_path);
   }
  } else if (verbose) {
   fprintf(stderr, "Failed to rename %s to %s: %s\n", old_path, new_path, strerror(errno));
  }
  free(new_basename);
 }
}

// Function to process directory recursively
void process_directory(const char *dir_path) {
 DIR *dir = opendir(dir_path);
 if (!dir) {
  if (verbose) fprintf(stderr, "Cannot open directory %s: %s\n", dir_path, strerror(errno));
  return;
 }

 struct dirent *entry;
 while ((entry = readdir(dir)) != NULL) {
  if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
   continue;
  }

  char full_path[MAX_PATH];
  if (strlen(dir_path) + strlen(entry->d_name) + 1 >= MAX_PATH) {
   if (verbose) fprintf(stderr, "Path too long: %s/%s\n", dir_path, entry->d_name);
   continue;
  }
  snprintf(full_path, MAX_PATH, "%s/%s", dir_path, entry->d_name);

  struct stat st;
  if (stat(full_path, &st) == -1) {
   if (verbose) fprintf(stderr, "Cannot stat %s: %s\n", full_path, strerror(errno));
   continue;
  }

  if (S_ISREG(st.st_mode) && (strcmp(operation, "str_replace") == 0 || strcmp(operation, "comb_replace") == 0)) {
   replace_in_file(full_path);
  } else if (S_ISDIR(st.st_mode)) {
   process_directory(full_path); // Recurse into subdirectory
  }

  if (strcmp(operation, "fld_replace") == 0 || strcmp(operation, "comb_replace") == 0) {
   rename_path(full_path, dir_path);
  }
 }
 closedir(dir);
}

int main(int argc, char *argv[]) {
 if (argc < 3) usage(argv[0]);

 search_string = argv[1];
 replace_string = argv[2];
 directory = getcwd(NULL, 0); // Default to current directory

 // Parse arguments
 for (int i = 3; i < argc; i++) {
  if (strcmp(argv[i], "-i") == 0) {
   if (++i >= argc) usage(argv[0]);
   free(directory);
   directory = realpath(argv[i], NULL);
   if (!directory) {
    fprintf(stderr, "Error: Invalid directory %s\n", argv[i]);
    exit(EXIT_FAILURE);
   }
  } else if (strcmp(argv[i], "-v") == 0) {
   verbose = true;
  } else if (strcmp(argv[i], "--opt") == 0) {
   if (++i >= argc) usage(argv[0]);
   if (strcmp(argv[i], "str_replace") == 0 || strcmp(argv[i], "fld_replace") == 0 || strcmp(argv[i], "comb_replace") == 0) {
    operation = argv[i];
   } else {
    fprintf(stderr, "Error: Invalid operation. Use str_replace, fld_replace, or comb_replace\n");
    exit(EXIT_FAILURE);
   }
  } else {
   fprintf(stderr, "Unknown option: %s\n", argv[i]);
   usage(argv[0]);
  }
 }

 if (verbose) {
  printf("Processing directory: %s\n", directory);
 }

 process_directory(directory);

 free(directory);
 return EXIT_SUCCESS;
}
