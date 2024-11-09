#include <stdio.h>
#include <stdlib.h>

int main(void) {
    FILE *f = fopen("/proc/uptime", "r");
    if (!f) {
        perror("/proc/uptime");
        return 1;
    }
    double up = 0.0;
    if (fscanf(f, "%lf", &up) != 1) {
        fprintf(stderr, "failed to parse /proc/uptime\n");
        fclose(f);
        return 1;
    }
    fclose(f);
    long seconds = (long)(up + 0.5);
    long days = seconds / 86400; seconds %= 86400;
    long hours = seconds / 3600; seconds %= 3600;
    long mins = seconds / 60; seconds %= 60;
    if (days > 0)
        printf("uptime: %ldd %ldh %ldm %lds\n", days, hours, mins, seconds);
    else if (hours > 0)
        printf("uptime: %ldh %ldm %lds\n", hours, mins, seconds);
    else
        printf("uptime: %ldm %lds\n", mins, seconds);
    return 0;
}


