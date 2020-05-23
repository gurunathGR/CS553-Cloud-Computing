#!/bin/bash
if [ $# != 1 ]
then
	echo "Arguments: [filename]"
	exit -1
fi

filename=$1
sort -k1 -n $filename -o "$filename.sorted"
