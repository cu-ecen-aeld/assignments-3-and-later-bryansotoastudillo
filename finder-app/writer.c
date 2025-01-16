#include <stdio.h>
#include <stdlib.h>>
#include <string.h>
#include <syslog.h>


int main(int argc, char *argv[]){

    openlog("writer", LOG_PID || LOG_CONS, LOG_USER);

    if (argc !=3){
        syslog(LOG_ERR, "Se deben ingresar los dos parametros de entrada");
        fprintf(stderr, "Uso: %s <fichero> <cadena>\n", argv[0]);
        closelog();
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestd = argv[2];

    FILE *file = fopen(writefile, "w");

    if (file==NULL){
        syslog(LOG_ERR,"no se pudo crear el archivo %s", writefile);
        perror("fopen");
        closelog();
        return 1;
    }


    if (fprintf(file,"%s", writestd)<0){
         syslog(LOG_ERR,"no se pudo escribir el archivo %s", writefile);
        perror("fopen");
        closelog();
        return 1;
    }

    syslog(LOG_DEBUG,"Excribiendo '%s' en '%s'",writestd,writefile);
 
    fclose(file);
    closelog();

    printf("fichero creado exitosamente %s\n",writefile);

    return 0;

 
}