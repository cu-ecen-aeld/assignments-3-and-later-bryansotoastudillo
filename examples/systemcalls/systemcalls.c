#include "systemcalls.h"
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#include <fcntl.h>

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{

/*
 * TODO  add your code here
 *  Call the system() function with the command set in the cmd
 *   and return a boolean true if the system() call completed with success
 *   or false() if it returned a failure
*/
    if(system(cmd)){
        perror("ERror");
        return false;
    }
    return true;
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];

/*
 * TODO:
 *   Execute a system command by calling fork, execv(),
 *   and wait instead of system (see LSP page 161).
 *   Use the command[0] as the full path to the command to execute
 *   (first argument to execv), and use the remaining arguments
 *   as second argument to the execv() command.
 *
*/

    va_end(args);

    pid_t process_id = fork();
    
    if (process_id<0)
    {
        perror("fork error");
        exit(EXIT_FAILURE);
        /* code */
    }else if  (process_id == 0){
        /*Es un hijo*/
       execv(command[0],command);
       perror("execv error");
       exit(EXIT_FAILURE);
    }else{
        int status;
        waitpid(process_id,&status,0);

       return (status==0);
        

    }
    

    return true;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...) {
    va_list args;
    va_start(args, count);

    char *command[count + 1];
    for (int i = 0; i < count; i++) {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    va_end(args);

    int log_fd = open(outputfile, O_WRONLY | O_TRUNC | O_CREAT, 0644);
    if (log_fd < 0) {
        perror("open");
        return false;
    }

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork error");
        close(log_fd);
        return false;
    } else if (pid == 0) {
        // Redirigir stdout al archivo
        if (dup2(log_fd, STDOUT_FILENO) == -1) {
            perror("dup2");
            close(log_fd);
            exit(EXIT_FAILURE);
        }
        close(log_fd);

        // Ejecutar el comando
        if (command[0] == NULL) {
            fprintf(stderr, "Command is NULL\n");
            exit(EXIT_FAILURE);
        }
        execv(command[0], command);
        perror("execv error");
        exit(EXIT_FAILURE);
    } else {
        // Proceso padre
        close(log_fd);
        int status;
        if (waitpid(pid, &status, 0) == -1) {
            perror("waitpid");
            return false;
        }

        if (WIFEXITED(status)) {
            printf("Child exited with status %d\n", WEXITSTATUS(status));
        } else if (WIFSIGNALED(status)) {
            printf("Child terminated by signal %d\n", WTERMSIG(status));
        } else {
            printf("Child did not terminate normally\n");
        }
    }

    return true;
}
