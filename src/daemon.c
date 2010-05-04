#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

/*
 * from http://www.steve.org.uk/Reference/Unix/faq_2.html#SEC16
 * Should allow safe forking of processes from gaya.
 * The directory change step has been omitted.
 */

#define SLEEP_USECS 1000000

static void set_logs();
static void close_all();

int main(int argc, char **argv) {

    int pid = fork();

    switch(pid) {

        case 0:
            break;
        case -1:
            fprintf(stderr,"Unable to fork - error %d",errno);
            exit(-1);
            break;
        default:
            {
                //int status;
                //waitpid(pid,&status,0);
                exit(0);
            }
    }

    // child 1 ---------------------------------------------
    
    // Give parent time to die.
    usleep(SLEEP_USECS);

    if (setpgrp() == -1) {
        fprintf(stderr,"Unable to setpgrp - error %d",errno);
    }
    if (setsid() == -1) {
        fprintf(stderr,"Unable to setsid - error %d",errno);
    }

    pid = fork();
    switch(pid) {

        case 0:
            break;
        case -1:
            fprintf(stderr,"Unable to fork child - error %d",errno);
            exit(-1);
            break;
        default:
            _exit(0);
    }

    // child 2 ---------------------------------------------

    // Give parent time to die.
    usleep(SLEEP_USECS);


    // chdir("/");
    umask(0);

    set_logs();

    close_all();

    char *env;

    if ((env = getenv("DAEMON_DIR")) != NULL) {
        chdir(env);
    }

    char *d =  get_current_dir_name();


    int i;
    for(i = 0 ; i < argc ; i++ ) {
        printf("'%s' ",argv[i]);
    }
    printf(" [%s] \n",d);
    fflush(stdout);
    free(d);

    if (execvp(argv[1],argv+1) == -1) {
        fprintf(stderr,"Unable to exec [%s] - error %d",argv[1],errno);
    }
    _exit(-1);
}

static void close_all()
{
    long i;
    long fc_max = sysconf(_SC_OPEN_MAX);
    for( i = 3 ; i < fc_max ; i++ ) {
        close(i);
    }
}

static void set_logs()
{
    char *log_dir = "/share/tmp";
    char *out_log_name = "daemon.out";
    char *err_log_name = "daemon.out";

    char *env;

    if ((env = getenv("DAEMON_LOG_DIR")) != NULL) {
        log_dir = env;
    }
    char *out_path = malloc(strlen(log_dir) + strlen(out_log_name) + 2);
    char *err_path = malloc(strlen(log_dir) + strlen(err_log_name) + 2);

    mkdir(log_dir,0777); // ignore error for now

    if (out_path != NULL ) {
        sprintf(out_path,"%s/%s",log_dir,out_log_name);
        freopen(out_path,"w",stdout);
    }

    if (err_path != NULL ) {
        sprintf(err_path,"%s/%s",log_dir,err_log_name);
        freopen(err_path,"w",stderr);
    }
    freopen("/dev/null","r",stdin);
}


