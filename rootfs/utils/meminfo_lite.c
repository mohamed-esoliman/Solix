#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) { perror("/proc/meminfo"); return 1; }
    char line[256];
    long memtotal=-1, memfree=-1, buffers=-1, cached=-1;
    while (fgets(line, sizeof(line), f)) {
        if (sscanf(line, "MemTotal: %ld", &memtotal)==1) continue;
        if (sscanf(line, "MemFree: %ld", &memfree)==1) continue;
        if (sscanf(line, "Buffers: %ld", &buffers)==1) continue;
        if (sscanf(line, "Cached: %ld", &cached)==1) continue;
    }
    fclose(f);
    if (memtotal>=0) printf("MemTotal: %ld kB\n", memtotal);
    if (memfree>=0)  printf("MemFree:  %ld kB\n", memfree);
    if (buffers>=0)  printf("Buffers:  %ld kB\n", buffers);
    if (cached>=0)   printf("Cached:   %ld kB\n", cached);
    return 0;
}


