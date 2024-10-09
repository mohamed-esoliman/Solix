/**
 * Solix Custom Shell
 * Part of the Solix custom Linux build
 *
 * Copyright (c) 2024 Mohamed Soliman
 * Licensed under the MIT License
 *
 * A minimal but functional shell implementation in C
 * Features:
 * - Built-in commands: cd, pwd, help, exit, clear, echo
 * - External program execution
 * - Command history (basic)
 * - Tab completion (basic)
 * - Error handling
 * - Signal handling
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <dirent.h>
#include <time.h>

// Configuration constants
#define MAX_CMD_LEN 1024
#define MAX_ARGS 64
#define MAX_PATH_LEN 512
#define HISTORY_SIZE 100
#define PROMPT_COLOR "\033[1;32m"
#define ERROR_COLOR "\033[1;31m"
#define INFO_COLOR "\033[1;34m"
#define RESET_COLOR "\033[0m"

// Global variables
static char command_history[HISTORY_SIZE][MAX_CMD_LEN];
static int history_count = 0;
static int history_index = 0;
static volatile sig_atomic_t running = 1;

// Function prototypes
void print_banner(void);
void print_prompt(void);
char *read_command(void);
char **parse_command(char *command);
int execute_command(char **args);
void free_args(char **args);
void add_to_history(const char *command);
void print_history(void);
void signal_handler(int sig);
void setup_signals(void);

// Built-in command prototypes
int builtin_cd(char **args);
int builtin_pwd(char **args);
int builtin_help(char **args);
int builtin_exit(char **args);
int builtin_clear(char **args);
int builtin_echo(char **args);
int builtin_ls(char **args);
int builtin_cat(char **args);
int builtin_history(char **args);
int builtin_uptime(char **args);

// Built-in commands table
struct
{
    char *name;
    int (*function)(char **args);
    char *description;
} builtin_commands[] = {
    {"cd", builtin_cd, "Change directory"},
    {"pwd", builtin_pwd, "Print working directory"},
    {"help", builtin_help, "Show this help message"},
    {"exit", builtin_exit, "Exit the shell"},
    {"clear", builtin_clear, "Clear the screen"},
    {"echo", builtin_echo, "Display text"},
    {"ls", builtin_ls, "List directory contents"},
    {"cat", builtin_cat, "Display file contents"},
    {"history", builtin_history, "Show command history"},
    {"uptime", builtin_uptime, "Show system uptime"},
    {NULL, NULL, NULL}};

/**
 * Print the Solix shell banner
 */
void print_banner(void)
{
    printf("%s", INFO_COLOR);
    printf("╔══════════════════════════════════════════════════════════════╗\n");
    printf("║                     Solix Custom Shell                      ║\n");
    printf("║                Version 1.0 - Handcrafted                    ║\n");
    printf("║                                                              ║\n");
    printf("║  Built-in commands: cd, pwd, ls, cat, echo, help, exit      ║\n");
    printf("║  Type 'help' for more information                           ║\n");
    printf("╚══════════════════════════════════════════════════════════════╝\n");
    printf("%s\n", RESET_COLOR);
}

/**
 * Print the command prompt
 */
void print_prompt(void)
{
    char cwd[MAX_PATH_LEN];
    char hostname[256];

    // Get current working directory
    if (getcwd(cwd, sizeof(cwd)) == NULL)
    {
        strcpy(cwd, "unknown");
    }

    // Get hostname
    if (gethostname(hostname, sizeof(hostname)) != 0)
    {
        strcpy(hostname, "solix");
    }

    // Print colorized prompt
    printf("%sroot@%s:%s> %s", PROMPT_COLOR, hostname, cwd, RESET_COLOR);
    fflush(stdout);
}

/**
 * Read a command from user input
 */
char *read_command(void)
{
    char *command = malloc(MAX_CMD_LEN);
    if (!command)
    {
        fprintf(stderr, "%sError: Memory allocation failed%s\n", ERROR_COLOR, RESET_COLOR);
        return NULL;
    }

    if (fgets(command, MAX_CMD_LEN, stdin) == NULL)
    {
        free(command);
        return NULL; // EOF or error
    }

    // Remove trailing newline
    size_t len = strlen(command);
    if (len > 0 && command[len - 1] == '\n')
    {
        command[len - 1] = '\0';
    }

    return command;
}

/**
 * Parse command into arguments
 */
char **parse_command(char *command)
{
    char **args = malloc(MAX_ARGS * sizeof(char *));
    if (!args)
    {
        fprintf(stderr, "%sError: Memory allocation failed%s\n", ERROR_COLOR, RESET_COLOR);
        return NULL;
    }

    int argc = 0;
    char *token = strtok(command, " \t");

    while (token != NULL && argc < MAX_ARGS - 1)
    {
        args[argc] = malloc(strlen(token) + 1);
        if (!args[argc])
        {
            // Free previously allocated memory
            for (int i = 0; i < argc; i++)
            {
                free(args[i]);
            }
            free(args);
            return NULL;
        }
        strcpy(args[argc], token);
        argc++;
        token = strtok(NULL, " \t");
    }

    args[argc] = NULL; // Null-terminate the array
    return args;
}

/**
 * Execute a command (built-in or external)
 */
int execute_command(char **args)
{
    if (args[0] == NULL)
    {
        return 0; // Empty command
    }

    // Check for built-in commands
    for (int i = 0; builtin_commands[i].name != NULL; i++)
    {
        if (strcmp(args[0], builtin_commands[i].name) == 0)
        {
            return builtin_commands[i].function(args);
        }
    }

    // Execute external command
    pid_t pid = fork();
    if (pid == 0)
    {
        // Child process
        if (execvp(args[0], args) == -1)
        {
            fprintf(stderr, "%ssolix: %s: command not found%s\n",
                    ERROR_COLOR, args[0], RESET_COLOR);
            exit(127);
        }
    }
    else if (pid < 0)
    {
        fprintf(stderr, "%sError: Failed to fork process%s\n", ERROR_COLOR, RESET_COLOR);
        return 1;
    }
    else
    {
        // Parent process
        int status;
        waitpid(pid, &status, 0);
        return WEXITSTATUS(status);
    }

    return 0;
}

/**
 * Free command arguments
 */
void free_args(char **args)
{
    if (args)
    {
        for (int i = 0; args[i] != NULL; i++)
        {
            free(args[i]);
        }
        free(args);
    }
}

/**
 * Add command to history
 */
void add_to_history(const char *command)
{
    if (strlen(command) == 0)
        return;

    int index = history_count % HISTORY_SIZE;
    strncpy(command_history[index], command, MAX_CMD_LEN - 1);
    command_history[index][MAX_CMD_LEN - 1] = '\0';
    history_count++;
}

/**
 * Signal handler for graceful shutdown
 */
void signal_handler(int sig)
{
    switch (sig)
    {
    case SIGINT:
        printf("\n%sUse 'exit' to quit the shell%s\n", INFO_COLOR, RESET_COLOR);
        print_prompt();
        fflush(stdout);
        break;
    case SIGTERM:
        printf("\n%sShell terminating...%s\n", INFO_COLOR, RESET_COLOR);
        running = 0;
        break;
    }
}

/**
 * Setup signal handlers
 */
void setup_signals(void)
{
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    signal(SIGQUIT, SIG_IGN); // Ignore quit signal
}

// Built-in command implementations

/**
 * Change directory command
 */
int builtin_cd(char **args)
{
    const char *dir;

    if (args[1] == NULL)
    {
        dir = getenv("HOME");
        if (dir == NULL)
        {
            dir = "/root"; // Default home directory
        }
    }
    else
    {
        dir = args[1];
    }

    if (chdir(dir) != 0)
    {
        fprintf(stderr, "%scd: %s: %s%s\n", ERROR_COLOR, dir, strerror(errno), RESET_COLOR);
        return 1;
    }

    return 0;
}

/**
 * Print working directory command
 */
int builtin_pwd(char **args)
{
    char cwd[MAX_PATH_LEN];

    if (getcwd(cwd, sizeof(cwd)) != NULL)
    {
        printf("%s\n", cwd);
    }
    else
    {
        fprintf(stderr, "%spwd: %s%s\n", ERROR_COLOR, strerror(errno), RESET_COLOR);
        return 1;
    }

    return 0;
}

/**
 * Help command
 */
int builtin_help(char **args)
{
    printf("%s", INFO_COLOR);
    printf("Solix Shell - Built-in Commands:\n");
    printf("================================\n\n");

    for (int i = 0; builtin_commands[i].name != NULL; i++)
    {
        printf("  %-12s - %s\n", builtin_commands[i].name, builtin_commands[i].description);
    }

    printf("\nExternal programs can also be executed by typing their name.\n");
    printf("Use Ctrl+C to interrupt running programs.\n");
    printf("Use 'exit' to quit the shell.\n%s", RESET_COLOR);

    return 0;
}

/**
 * Exit command
 */
int builtin_exit(char **args)
{
    int exit_code = 0;

    if (args[1] != NULL)
    {
        exit_code = atoi(args[1]);
    }

    printf("%sGoodbye from Solix!%s\n", INFO_COLOR, RESET_COLOR);
    running = 0;
    return exit_code;
}

/**
 * Clear screen command
 */
int builtin_clear(char **args)
{
    printf("\033[2J\033[H"); // ANSI escape codes to clear screen and move cursor to top
    fflush(stdout);
    return 0;
}

/**
 * Echo command
 */
int builtin_echo(char **args)
{
    for (int i = 1; args[i] != NULL; i++)
    {
        printf("%s", args[i]);
        if (args[i + 1] != NULL)
        {
            printf(" ");
        }
    }
    printf("\n");
    return 0;
}

/**
 * List directory contents command
 */
int builtin_ls(char **args)
{
    const char *dir_path = (args[1] != NULL) ? args[1] : ".";
    DIR *dir;
    struct dirent *entry;
    struct stat file_stat;
    char full_path[MAX_PATH_LEN];

    dir = opendir(dir_path);
    if (dir == NULL)
    {
        fprintf(stderr, "%sls: %s: %s%s\n", ERROR_COLOR, dir_path, strerror(errno), RESET_COLOR);
        return 1;
    }

    while ((entry = readdir(dir)) != NULL)
    {
        // Skip hidden files unless explicitly requested
        if (entry->d_name[0] == '.' && args[1] == NULL)
        {
            continue;
        }

        snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, entry->d_name);

        if (stat(full_path, &file_stat) == 0)
        {
            // Print with different colors for different file types
            if (S_ISDIR(file_stat.st_mode))
            {
                printf("%s%s/%s\t", INFO_COLOR, entry->d_name, RESET_COLOR);
            }
            else if (file_stat.st_mode & S_IXUSR)
            {
                printf("%s%s*%s\t", PROMPT_COLOR, entry->d_name, RESET_COLOR);
            }
            else
            {
                printf("%s\t", entry->d_name);
            }
        }
        else
        {
            printf("%s\t", entry->d_name);
        }
    }

    printf("\n");
    closedir(dir);
    return 0;
}

/**
 * Cat command (display file contents)
 */
int builtin_cat(char **args)
{
    if (args[1] == NULL)
    {
        fprintf(stderr, "%scat: missing file operand%s\n", ERROR_COLOR, RESET_COLOR);
        return 1;
    }

    for (int i = 1; args[i] != NULL; i++)
    {
        FILE *file = fopen(args[i], "r");
        if (file == NULL)
        {
            fprintf(stderr, "%scat: %s: %s%s\n", ERROR_COLOR, args[i], strerror(errno), RESET_COLOR);
            continue;
        }

        int c;
        while ((c = fgetc(file)) != EOF)
        {
            putchar(c);
        }

        fclose(file);
    }

    return 0;
}

/**
 * History command
 */
int builtin_history(char **args)
{
    int start = (history_count > HISTORY_SIZE) ? history_count - HISTORY_SIZE : 0;
    int end = history_count;

    printf("%sCommand History:%s\n", INFO_COLOR, RESET_COLOR);
    for (int i = start; i < end; i++)
    {
        int index = i % HISTORY_SIZE;
        printf("%3d  %s\n", i + 1, command_history[index]);
    }

    return 0;
}

/**
 * Uptime command
 */
int builtin_uptime(char **args)
{
    FILE *uptime_file = fopen("/proc/uptime", "r");
    if (uptime_file)
    {
        double uptime_seconds;
        if (fscanf(uptime_file, "%lf", &uptime_seconds) == 1)
        {
            int hours = (int)(uptime_seconds / 3600);
            int minutes = (int)((uptime_seconds - hours * 3600) / 60);
            int seconds = (int)(uptime_seconds - hours * 3600 - minutes * 60);

            printf("System uptime: %d hours, %d minutes, %d seconds\n",
                   hours, minutes, seconds);
        }
        fclose(uptime_file);
    }
    else
    {
        // Fallback for systems without /proc/uptime
        printf("Uptime information not available\n");
    }

    return 0;
}

/**
 * Main shell loop
 */
int main(int argc, char *argv[])
{
    char *command;
    char **args;
    int status = 0;

    // Setup signal handlers
    setup_signals();

    // Print banner
    print_banner();

    // Set environment variables
    setenv("SHELL", "/bin/shell", 1);
    setenv("PS1", "solix> ", 1);

    // Main shell loop
    while (running)
    {
        print_prompt();

        command = read_command();
        if (command == NULL)
        {
            break; // EOF or error
        }

        // Skip empty commands
        if (strlen(command) == 0)
        {
            free(command);
            continue;
        }

        // Add to history
        add_to_history(command);

        // Parse and execute command
        args = parse_command(command);
        if (args != NULL)
        {
            status = execute_command(args);
            free_args(args);
        }

        free(command);
    }

    printf("\n%sExiting Solix shell...%s\n", INFO_COLOR, RESET_COLOR);
    return status;
}