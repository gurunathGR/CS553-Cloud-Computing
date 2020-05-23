#!/bin/bash
if [ $# != 2 ]
then
	echo "Arguments: [filename] [num_records]"
	exit -1
fi

filename=$1
num_records=$2
temp1="$filename.int1"
temp2="$filename.int2"
temp3="$filename.str"

#Initialize output file
: > $filename
#Generate a bunch of 32-bit random numbers
shuf -i 0-4294967296 -n $num_records > $temp1
shuf -i 0-4294967296 -n $num_records > $temp2
#Generate a bunch of 100-byte ASCII strings
base64 -i /dev/urandom | fold -w 100 | head -n $num_records > $temp3
#[int1] [int2] [str]
paste $temp1 $temp2 $temp3 > $filename
