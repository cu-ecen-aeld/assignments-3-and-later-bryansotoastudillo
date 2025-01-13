#!/bin/sh

if [ $# -ne 2 ]; then
    echo "se deben ingresar 2 parametros de entrada"
    exit 1
fi

filesdir=$1
searchstr=$2

echo ${filesdir}
echo ${searchstr}


if [ ! -d "$filesdir" ];then
    echo "Error: $filesdir no es un directorio valido de sistema"
    exit 1
fi

file_count=$(find "$filesdir" -type f | wc -l)

match_lines=$(grep -r "$searchstr" "$filesdir" 2>/dev/null | wc -l)

echo "The number of files are ${file_count} and the number of matching lines are ${match_lines}"

exit 0

