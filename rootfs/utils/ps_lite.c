#define _GNU_SOURCE
#include <stdio.h>
#include <dirent.h>
#include <string.h>
#include <ctype.h>

static int is_number(const char *s) {
    if (!s || !*s) return 0;
    for (; *s; ++s) if (!isdigit((unsigned char)*s)) return 0;
    return 1;
}

int main(void) {
    DIR *proc = opendir("/proc");
    if (!proc) {
        perror("/proc");
        return 1;
    }
    struct dirent *de;
    printf("  PID  CMD\n");
    while ((de = readdir(proc)) != NULL) {
        if (!is_number(de->d_name)) continue;
        char path[256];
        snprintf(path, sizeof(path), "/proc/%s/comm", de->d_name);
        FILE *f = fopen(path, "r");
        char name[256] = {0};
        if (f) {
            if (fgets(name, sizeof(name), f)) {
                size_t len = strlen(name);
                if (len && name[len-1]=='\n') name[len-1]='\0';
            }
            fclose(f);
        } else {
            snprintf(path, sizeof(path), "/proc/%s/stat", de->d_name);
            f = fopen(path, "r");
            if (f) {
                int pid; char comm[256]; char state;
                if (fscanf(f, "%d (%255[^)]) %c", &pid, comm, &state)==3) {
                    strncpy(name, comm, sizeof(name)-1);
                }
                fclose(f);
            }
        }
        if (name[0])
            printf("%5s  %s\n", de->d_name, name);
    }
    closedir(proc);
    return 0;
}


