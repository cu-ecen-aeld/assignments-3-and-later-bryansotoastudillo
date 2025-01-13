#!/bin/sh

if [ $# -ne 2 ]; then
    echo "Finder: se deben ingresar 2 parametros de entrada"
    exit 1
fi


writefile=$1
writestr=$2

mkdir -p "$(dirname "$writefile")"


echo "$writestr" > "$writefile"

if [ "$?" -ne 0 ]; then
    echo "Error: no se pudo crear el archivo $writefile"
    exit 1
fi


echo "Fichero creador exitosamente $writefile"

exit 0