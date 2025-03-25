// By Thibaut LOMBARD (Lombard Web)
// program that permit to transfer the PEheader of a windows executable to another.
// -s flag to copy the section table from the source file, while still preserving the target’s .rsrc section for icons.
// Default to copying only the PE header (DOS Header + NT Headers) without the section table if the flag isn’t provided.
// keep icon checking step.

#include <stdio.h>
#include <windows.h>
#include <string.h>

void copy_pe_header_with_resources(const char *source_file, const char *target_file, int copy_sections) {
 FILE *source = fopen(source_file, "rb");
 if (!source) {
  perror("Error opening source file");
  return;
 }

 FILE *target = fopen(target_file, "r+b");
 if (!target) {
  perror("Error opening target file");
  fclose(source);
  return;
 }

 // Read and validate source DOS header
 IMAGE_DOS_HEADER srcDosHeader;
 if (fread(&srcDosHeader, sizeof(IMAGE_DOS_HEADER), 1, source) != 1) {
  printf("Error reading source DOS header\n");
  goto cleanup;
 }
 if (srcDosHeader.e_magic != IMAGE_DOS_SIGNATURE) {
  printf("Source file is not a valid PE file (missing MZ signature)\n");
  goto cleanup;
 }

 // Read and validate target DOS header
 IMAGE_DOS_HEADER tgtDosHeader;
 if (fread(&tgtDosHeader, sizeof(IMAGE_DOS_HEADER), 1, target) != 1) {
  printf("Error reading target DOS header\n");
  goto cleanup;
 }
 if (tgtDosHeader.e_magic != IMAGE_DOS_SIGNATURE) {
  printf("Target file is not a valid PE file (missing MZ signature)\n");
  goto cleanup;
 }

 // Read source NT headers
 fseek(source, srcDosHeader.e_lfanew, SEEK_SET);
 IMAGE_NT_HEADERS srcNtHeaders;
 if (fread(&srcNtHeaders, sizeof(IMAGE_NT_HEADERS), 1, source) != 1) {
  printf("Error reading source NT headers\n");
  goto cleanup;
 }
 if (srcNtHeaders.Signature != IMAGE_NT_SIGNATURE) {
  printf("Source file has invalid PE signature\n");
  goto cleanup;
 }

 // Read target NT headers
 fseek(target, tgtDosHeader.e_lfanew, SEEK_SET);
 IMAGE_NT_HEADERS tgtNtHeaders;
 if (fread(&tgtNtHeaders, sizeof(IMAGE_NT_HEADERS), 1, target) != 1) {
  printf("Error reading target NT headers\n");
  goto cleanup;
 }
 if (tgtNtHeaders.Signature != IMAGE_NT_SIGNATURE) {
  printf("Target file has invalid PE signature\n");
  goto cleanup;
 }

 // Save target's resource directory
 IMAGE_DATA_DIRECTORY tgtResourceDir = tgtNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE];

 // Write source DOS header
 fseek(target, 0, SEEK_SET);
 if (fwrite(&srcDosHeader, sizeof(IMAGE_DOS_HEADER), 1, target) != 1) {
  printf("Error writing DOS header to target\n");
  goto cleanup;
 }

 // Write source NT headers
 fseek(target, srcDosHeader.e_lfanew, SEEK_SET);
 if (fwrite(&srcNtHeaders, sizeof(IMAGE_NT_HEADERS), 1, target) != 1) {
  printf("Error writing NT headers to target\n");
  goto cleanup;
 }

 // Restore target's resource directory
 fseek(target, srcDosHeader.e_lfanew + offsetof(IMAGE_NT_HEADERS, OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE]), SEEK_SET);
 if (fwrite(&tgtResourceDir, sizeof(IMAGE_DATA_DIRECTORY), 1, target) != 1) {
  printf("Error restoring resource directory\n");
  goto cleanup;
 }

 // Handle section table if requested
 if (copy_sections) {
  int srcSectionCount = srcNtHeaders.FileHeader.NumberOfSections;
  IMAGE_SECTION_HEADER *srcSections = malloc(srcSectionCount * sizeof(IMAGE_SECTION_HEADER));
  if (!srcSections) {
   printf("Memory allocation failed for source sections\n");
   goto cleanup;
  }
  fseek(source, srcDosHeader.e_lfanew + sizeof(IMAGE_NT_HEADERS), SEEK_SET);
  if (fread(srcSections, sizeof(IMAGE_SECTION_HEADER), srcSectionCount, source) != srcSectionCount) {
   printf("Error reading source section table\n");
   free(srcSections);
   goto cleanup;
  }

  int tgtSectionCount = tgtNtHeaders.FileHeader.NumberOfSections;
  IMAGE_SECTION_HEADER *tgtSections = malloc(tgtSectionCount * sizeof(IMAGE_SECTION_HEADER));
  if (!tgtSections) {
   printf("Memory allocation failed for target sections\n");
   free(srcSections);
   goto cleanup;
  }
  fseek(target, tgtDosHeader.e_lfanew + sizeof(IMAGE_NT_HEADERS), SEEK_SET);
  if (fread(tgtSections, sizeof(IMAGE_SECTION_HEADER), tgtSectionCount, target) != tgtSectionCount) {
   printf("Error reading target section table\n");
   free(srcSections);
   free(tgtSections);
   goto cleanup;
  }

  IMAGE_SECTION_HEADER *tgtRsrcSection = NULL;
  for (int i = 0; i < tgtSectionCount; i++) {
   if (strncmp((char *)tgtSections[i].Name, ".rsrc", 5) == 0) {
    tgtRsrcSection = &tgtSections[i];
    break;
   }
  }
  if (!tgtRsrcSection) {
   printf("Warning: Target file has no .rsrc section\n");
  }

  fseek(target, srcDosHeader.e_lfanew + sizeof(IMAGE_NT_HEADERS), SEEK_SET);
  for (int i = 0; i < srcSectionCount; i++) {
   if (tgtRsrcSection && strncmp((char *)srcSections[i].Name, ".rsrc", 5) == 0) {
    if (fwrite(tgtRsrcSection, sizeof(IMAGE_SECTION_HEADER), 1, target) != 1) {
     printf("Error writing .rsrc section header\n");
     free(srcSections);
     free(tgtSections);
     goto cleanup;
    }
   } else {
    if (fwrite(&srcSections[i], sizeof(IMAGE_SECTION_HEADER), 1, target) != 1) {
     printf("Error writing section header %d\n", i);
     free(srcSections);
     free(tgtSections);
     goto cleanup;
    }
   }
  }
  free(srcSections);
  free(tgtSections);
 }

 // Icon verification
 if (tgtResourceDir.VirtualAddress && tgtResourceDir.Size) {
  fseek(target, tgtNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE].VirtualAddress - tgtNtHeaders.OptionalHeader.ImageBase + tgtDosHeader.e_lfanew, SEEK_SET);
  IMAGE_RESOURCE_DIRECTORY resDir;
  if (fread(&resDir, sizeof(IMAGE_RESOURCE_DIRECTORY), 1, target) == 1) {
   int entryCount = resDir.NumberOfNamedEntries + resDir.NumberOfIdEntries;
   fseek(target, -sizeof(IMAGE_RESOURCE_DIRECTORY), SEEK_CUR); // Rewind to start of directory
   fseek(target, sizeof(IMAGE_RESOURCE_DIRECTORY), SEEK_CUR);  // Skip to entries
   for (int i = 0; i < entryCount; i++) {
    IMAGE_RESOURCE_DIRECTORY_ENTRY entry;
    if (fread(&entry, sizeof(IMAGE_RESOURCE_DIRECTORY_ENTRY), 1, target) != 1) break;
    if (!entry.NameIsString && entry.Id == 3) { // RT_ICON = 3
     printf("Icon resource detected in target file\n");
     break;
    }
   }
  }
 } else {
  printf("No resource directory found in target\n");
 }

 printf("PE header %s from %s to %s, preserving target's resources\n", 
     copy_sections ? "and section table copied" : "copied", source_file, target_file);

cleanup:
 fclose(source);
 fclose(target);
}

int main(int argc, char *argv[]) {
 int copy_sections = 0;

 if (argc < 3 || argc > 4) {
  printf("Usage: %s [-s] <source_file> <target_file>\n", argv[0]);
  printf("  -s: Copy section table (optional)\n");
  printf("Example: %s source.exe target.exe\n", argv[0]);
  printf("   %s -s source.exe target.exe\n", argv[0]);
  return 1;
 }

 if (argc == 4) {
  if (strcmp(argv[1], "-s") == 0) {
   copy_sections = 1;
   copy_pe_header_with_resources(argv[2], argv[3], copy_sections);
  } else {
   printf("Invalid flag. Use -s to copy section table.\n");
   return 1;
  }
 } else {
  copy_pe_header_with_resources(argv[1], argv[2], copy_sections);
 }

 return 0;
}
