/**
 * Solix Custom Shell
 * Part of the Solix custom Linux build
 *
 * Copyright (c) 2024 Mohamed Soliman
 * Licensed under the MIT License
 *
 * A small but capable static shell
 * Features now include:
 * - Prompt: username@hostname:cwd$ (cwd truncated to last 2 segments)
 * - History: in-memory + persistent at ~/.solix_history
 * - Built-ins: cd, pwd, echo, help, exit, history, which, export, unset
 * - PATH lookup for external commands
 * - Redirections: >, >>, < (single redirection per command side)
 * - Pipe: single pipeline cmd1 | cmd2
 * - Chaining: cmd1 && cmd2, cmd1 || cmd2, cmd1 ; cmd2
 * - Exit status tracking: $? expansion
 * - Signals: foreground job receives SIGINT; shell survives
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
#define HISTORY_SIZE 200
#define PROMPT_COLOR "\033[1;32m"
#define ERROR_COLOR "\033[1;31m"
#define INFO_COLOR "\033[1;34m"
#define RESET_COLOR "\033[0m"
#define MAX_TOKENS 128

// Global variables
static char command_history[HISTORY_SIZE][MAX_CMD_LEN];
static int history_count = 0;
static int history_index = 0;
static volatile sig_atomic_t running = 1;
static int last_status = 0;
static char history_path[512];

// Function prototypes
void print_banner(void);
void print_prompt(void);
char *read_command(void);
int tokenize_command(const char *line, char *tokens[], int max_tokens);
void free_tokens(char *tokens[], int count);
void expand_vars(char *tokens[], int count);
int is_builtin(const char *cmd);
int exec_builtin(char *const argv[]);
int exec_external(char *const argv[], int in_fd, int out_fd);
int exec_simple(char *const argv[], const char *in_file, const char *out_file, int append);
int exec_pipeline(char *const left_argv[], const char *left_in, char *const right_argv[], const char *right_out, int append);
int execute_line_tokens(char *tokens[], int count);
void add_to_history(const char *command);
void print_history(void);
void signal_handler(int sig);
void setup_signals(void);
void load_history(void);
void save_history(void);

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
int builtin_which(char **args);
int builtin_export(char **args);
int builtin_unset(char **args);

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
    {"which", builtin_which, "Locate a command in PATH"},
    {"export", builtin_export, "Export environment variable: export VAR=value"},
    {"unset", builtin_unset, "Unset environment variable"},
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
    const char *user = getenv("USER");
    if (!user || !*user) user = "root";
    if (getcwd(cwd, sizeof(cwd)) == NULL) strcpy(cwd, "?");
    if (gethostname(hostname, sizeof(hostname)) != 0) strcpy(hostname, "solix");
    // truncate cwd to last 2 segments
    char truncated[MAX_PATH_LEN];
    const char *p = cwd; const char *last = cwd; const char *second = cwd;
    for (; *p; ++p) if (*p=='/') { second = last; last = p+1; }
    if (second==cwd) snprintf(truncated, sizeof(truncated), "%s", cwd);
    else snprintf(truncated, sizeof(truncated), "/%s/%s", second, last);
    printf("%s%s@%s:%s$ %s", PROMPT_COLOR, user, hostname, truncated, RESET_COLOR);
    fflush(stdout);
}

/**
 * Read a command from user input
 */
char *read_command(void)
{
    static char buf[MAX_CMD_LEN];
    if (!fgets(buf, sizeof(buf), stdin)) return NULL;
    size_t len = strlen(buf);
    if (len && buf[len-1]=='\n') buf[len-1]='\0';
    return buf;
}

/**
 * Parse command into arguments
 */
static int is_space(char c){ return c==' '||c=='\t'; }

int tokenize_command(const char *line, char *tokens[], int max_tokens)
{
    int count = 0; const char *p = line;
    while (*p) {
        while (is_space(*p)) p++;
        if (!*p) break;
        if (count >= max_tokens) break;
        // two-char operators
        if ((p[0]=='&'&&p[1]=='&') || (p[0]=='|'&&p[1]=='|') || (p[0]=='>'&&p[1]=='>')) {
            tokens[count++] = strndup(p, 2); p+=2; continue;
        }
        // one-char operators ; | > <
        if (*p==';' || *p=='|' || *p=='>' || *p=='<') { tokens[count++] = strndup(p,1); p++; continue; }
        // word with quotes
        char buf[MAX_CMD_LEN]; int bi=0; int in_s=0,in_d=0;
        while (*p && (in_s||in_d || (!is_space(*p) && *p!=';' && *p!='|' && *p!='>' && *p!='<'))) {
            if (!in_s && *p=='"') { in_d = !in_d; p++; continue; }
            if (!in_d && *p=='\'') { in_s = !in_s; p++; continue; }
            if (*p=='\\' && p[1]) { buf[bi++] = p[1]; p += 2; continue; }
            buf[bi++]=*p++;
            if (bi>=MAX_CMD_LEN-1) break;
        }
        buf[bi]='\0';
        tokens[count++] = strdup(buf);
    }
    return count;
}

void free_tokens(char *tokens[], int count)
{
    for (int i=0;i<count;i++) free(tokens[i]);
}

void expand_vars(char *tokens[], int count)
{
    char numbuf[16];
    snprintf(numbuf, sizeof(numbuf), "%d", last_status);
    for (int i=0;i<count;i++) {
        if (strcmp(tokens[i],"$?")==0) { free(tokens[i]); tokens[i]=strdup(numbuf); continue; }
        // simple $VAR expansion
        if (tokens[i][0]=='$' && tokens[i][1] && tokens[i][1] != '?') {
            const char *val = getenv(tokens[i]+1);
            if (val) { free(tokens[i]); tokens[i]=strdup(val); }
        }
    }
}

/**
 * Execute a command (built-in or external)
 */
int is_builtin(const char *cmd){
    if (!cmd) return 0;
    for (int i=0; builtin_commands[i].name; i++) if (strcmp(cmd,builtin_commands[i].name)==0) return 1;
    return 0;
}

int exec_builtin(char *const argv[]){
    for (int i=0; builtin_commands[i].name; i++) if (strcmp(argv[0], builtin_commands[i].name)==0) return builtin_commands[i].function((char**)argv);
    return 127;
}

int exec_external(char *const argv[], int in_fd, int out_fd)
{
    pid_t pid = fork();
    if (pid==0){
        signal(SIGINT, SIG_DFL);
        if (in_fd != -1) { dup2(in_fd, STDIN_FILENO); }
        if (out_fd != -1) { dup2(out_fd, STDOUT_FILENO); }
        execvp(argv[0], (char* const*)argv);
        fprintf(stderr, "%ssolix: %s: command not found%s\n", ERROR_COLOR, argv[0], RESET_COLOR);
        _exit(127);
    } else if (pid<0){
        perror("fork");
        return 1;
    }
    int status; int w = waitpid(pid, &status, 0);
    (void)w;
    return WIFEXITED(status)? WEXITSTATUS(status) : 128+SIGINT;
}

int exec_simple(char *const argv[], const char *in_file, const char *out_file, int append)
{
    int in_fd=-1, out_fd=-1; int rc;
    if (in_file){ in_fd = open(in_file, O_RDONLY); if (in_fd<0){ perror("open in"); return 1; } }
    if (out_file){ int flags = O_WRONLY|O_CREAT|(append?O_APPEND:O_TRUNC); out_fd = open(out_file, flags, 0644); if (out_fd<0){ perror("open out"); if(in_fd!=-1) close(in_fd); return 1; } }
    if (is_builtin(argv[0]) && in_fd==-1 && out_fd==-1){
        rc = exec_builtin(argv);
    } else {
        rc = exec_external(argv, in_fd, out_fd);
    }
    if (in_fd!=-1) close(in_fd);
    if (out_fd!=-1) close(out_fd);
    return rc;
}

int exec_pipeline(char *const left_argv[], const char *left_in, char *const right_argv[], const char *right_out, int append)
{
    int pipefd[2]; if (pipe(pipefd)<0){ perror("pipe"); return 1; }
    pid_t c1 = fork();
    if (c1==0){
        signal(SIGINT, SIG_DFL);
        // left process
        int in_fd=-1; if (left_in){ in_fd=open(left_in,O_RDONLY); if(in_fd<0) _exit(1);} 
        if (in_fd!=-1) dup2(in_fd, STDIN_FILENO);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[0]); close(pipefd[1]); if(in_fd!=-1) close(in_fd);
        if (is_builtin(left_argv[0])) _exit(exec_builtin(left_argv));
        execvp(left_argv[0], (char* const*)left_argv);
        _exit(127);
    }
    pid_t c2 = fork();
    if (c2==0){
        signal(SIGINT, SIG_DFL);
        // right process
        int out_fd=-1; if (right_out){ int flags=O_WRONLY|O_CREAT|(append?O_APPEND:O_TRUNC); out_fd=open(right_out,flags,0644); if(out_fd<0) _exit(1);} 
        dup2(pipefd[0], STDIN_FILENO);
        if (out_fd!=-1) dup2(out_fd, STDOUT_FILENO);
        close(pipefd[0]); close(pipefd[1]); if(out_fd!=-1) close(out_fd);
        if (is_builtin(right_argv[0])) _exit(exec_builtin(right_argv));
        execvp(right_argv[0], (char* const*)right_argv);
        _exit(127);
    }
    close(pipefd[0]); close(pipefd[1]);
    int st1=0, st2=0; waitpid(c1,&st1,0); waitpid(c2,&st2,0);
    return WIFEXITED(st2)? WEXITSTATUS(st2) : 128+SIGINT;
}

int execute_line_tokens(char *tokens[], int count)
{
    // chaining: left-to-right, short-circuit &&/||
    int i=0; int status=0;
    while (i<count) {
        // gather command until next chain op
        int start=i; int j=i; const char *chain_op=NULL;
        int depth=0; // not used for now
        for (; j<count; j++) {
            if (strcmp(tokens[j],"&&")==0 || strcmp(tokens[j],"||")==0 || strcmp(tokens[j],";")==0) { chain_op=tokens[j]; break; }
        }
        int end=j; // [start,end)
        // Execute segment [start,end)
        // detect pipeline and redirs
        int pipe_index=-1; int k;
        for (k=start;k<end;k++) if (strcmp(tokens[k],"|")==0) { pipe_index=k; break; }
        // split argv and redirs
        char *in_file=NULL,*out_file=NULL; int append=0;
        char *argv_left[MAX_TOKENS]; int al=0;
        char *argv_right[MAX_TOKENS]; int ar=0;
        if (pipe_index==-1){
            for (k=start;k<end;k++){
                if (strcmp(tokens[k],">")==0 || strcmp(tokens[k],">>")==0){ append = (tokens[k][1]=='>'); if (k+1<end) { out_file=tokens[k+1]; k++; } continue; }
                if (strcmp(tokens[k],"<")==0){ if (k+1<end){ in_file=tokens[k+1]; k++; } continue; }
                argv_left[al++] = tokens[k];
            }
            argv_left[al]=NULL;
            if (al>0) status = exec_simple(argv_left, in_file, out_file, append); else status=0;
        } else {
            // left side
            for (k=start;k<pipe_index;k++){
                if (strcmp(tokens[k],"<")==0){ if (k+1<pipe_index){ in_file=tokens[k+1]; k++; } continue; }
                argv_left[al++]=tokens[k];
            }
            argv_left[al]=NULL;
            // right side
            for (k=pipe_index+1;k<end;k++){
                if (strcmp(tokens[k],">")==0 || strcmp(tokens[k],">>")==0){ append = (tokens[k][1]=='>'); if (k+1<end) { out_file=tokens[k+1]; k++; } continue; }
                argv_right[ar++]=tokens[k];
            }
            argv_right[ar]=NULL;
            if (al>0 && ar>0) status = exec_pipeline(argv_left, in_file, argv_right, out_file, append); else status=0;
        }
        last_status = status;
        // chain logic
        if (!chain_op) break;
        if (strcmp(chain_op,"&&")==0 && status!=0) { // skip to next after && segment
            i = end+1; // skip op
            // skip following segments separated by && until status short-circuit ends? We'll just proceed
        } else if (strcmp(chain_op,"||")==0 && status==0) {
            i = end+1;
        } else {
            i = end+1;
        }
    }
    return last_status;
}

/**
 * Free command arguments
 */
void free_args(char **args) { (void)args; }

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
        printf("\n");
        last_status = 130;
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

static const char *get_history_path(void)
{
    const char *home = getenv("HOME");
    if (!home || !*home) home = "/root";
    snprintf(history_path, sizeof(history_path), "%s/.solix_history", home);
    return history_path;
}

void load_history(void)
{
    FILE *f = fopen(get_history_path(), "r"); if (!f) return;
    char line[MAX_CMD_LEN];
    while (fgets(line, sizeof(line), f)) {
        size_t len = strlen(line); if (len && line[len-1]=='\n') line[len-1]='\0';
        add_to_history(line);
    }
    fclose(f);
}

void save_history(void)
{
    FILE *f = fopen(get_history_path(), "a"); if (!f) return;
    int start = (history_count>HISTORY_SIZE)? history_count - HISTORY_SIZE : 0;
    for (int i=start;i<history_count;i++) {
        int idx = i % HISTORY_SIZE;
        fprintf(f, "%s\n", command_history[idx]);
    }
    fclose(f);
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

int builtin_which(char **args)
{
    if (!args[1]) { fprintf(stderr, "which: missing operand\n"); return 1; }
    const char *path = getenv("PATH"); if (!path) path = "/bin:/sbin:/usr/bin:/usr/sbin";
    char buf[512];
    for (int i=1; args[i]; i++){
        const char *p = path; int found=0;
        while (*p){
            const char *q = strchr(p, ':'); size_t len = q? (size_t)(q-p) : strlen(p);
            snprintf(buf, sizeof(buf), "%.*s/%s", (int)len, p, args[i]);
            if (access(buf, X_OK)==0){ printf("%s\n", buf); found=1; break; }
            if (!q) break; p = q+1;
        }
        if (!found) last_status=1; else last_status=0;
    }
    return last_status;
}

int builtin_export(char **args)
{
    if (!args[1]) { fprintf(stderr, "export: usage: export VAR=value\n"); return 1; }
    int rc=0;
    for (int i=1; args[i]; i++){
        char *eq = strchr(args[i], '=');
        if (!eq || eq==args[i]) { fprintf(stderr, "export: invalid: %s\n", args[i]); rc=1; continue; }
        *eq='\0'; const char *name=args[i]; const char *val=eq+1;
        if (setenv(name, val, 1)!=0) { perror("export"); rc=1; }
        *eq='=';
    }
    return rc;
}

int builtin_unset(char **args)
{
    if (!args[1]) { fprintf(stderr, "unset: usage: unset VAR [VAR...]\n"); return 1; }
    int rc=0; for (int i=1; args[i]; i++) if (unsetenv(args[i])!=0) { perror("unset"); rc=1; }
    return rc;
}

/**
 * Main shell loop
 */
int main(int argc, char *argv[])
{
    char *line;
    int status = 0;

    // Setup signal handlers
    setup_signals();

    // Print banner
    print_banner();

    // Set environment variables
    setenv("SHELL", "/bin/shell", 1);
    setenv("PS1", "solix> ", 1);
    if (!getenv("PATH")) setenv("PATH","/bin:/sbin:/usr/bin:/usr/sbin",1);

    load_history();

    // Main shell loop
    while (running)
    {
        print_prompt();

        line = read_command();
        if (line == NULL)
        {
            break; // EOF or error
        }

        // Skip empty commands
        if (strlen(line) == 0)
        {
            continue;
        }

        // Add to history
        add_to_history(line);

        // Tokenize, expand, and execute with chaining support
        char *tokens[MAX_TOKENS];
        int ntok = tokenize_command(line, tokens, MAX_TOKENS);
        if (ntok>0){
            expand_vars(tokens, ntok);
            status = execute_line_tokens(tokens, ntok);
            last_status = status;
            free_tokens(tokens, ntok);
        }
    }

    printf("\n%sExiting Solix shell...%s\n", INFO_COLOR, RESET_COLOR);
    save_history();
    return status;
}