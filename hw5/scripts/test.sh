#!/bin/bash

MODE=$1
BIN=$2
SOURCE=$3

SCRIPTS=${SOURCE}/scripts
TEMP_DIR="${HOME}/temp"
RES_DIR="${SOURCE}/results"
GENSORT=${SOURCE}/gensort-1.5/gensort
VALSORT=${SOURCE}/gensort-1.5/valsort

function validate() {
	COUNT=$1
	NUM_THREADS=$2 
	BUFFER=$3
	
	#Generate temp file to use for both tests
	echo "GENERATING DATASET"
	${GENSORT} -a ${COUNT} ${TEMP_DIR}/temp.txt
	
	#MySort
	echo "MY SORT"
	${VALSORT} ${TEMP_DIR}/temp.txt
	echo
	${BIN}/mysort ${TEMP_DIR}/temp.txt ${BUFFER} ${NUM_THREADS}
	echo
	${VALSORT} ${TEMP_DIR}/temp.txt
	return
}

function thread_test() {
	COUNT=$1
	NUM_THREADS=$2
	BUFFER=$3
	
	echo "THREAD TEST NUM_THREADS=${NUM_THREADS}, DATASET_COUNT: ${COUNT}, BUFFER_SIZE: ${BUFFER}"
	
	MYSORT_OUT=${RES_DIR}/mysort${BUFFER}_threads.log
	LINSORT_OUT=${RES_DIR}/linsort${BUFFER}_threads.log
	
	echo ${NUM_THREADS} >> ${MYSORT_OUT}
	echo ${NUM_THREADS} >> ${LINSORT_OUT}
	
	#Generate temp file to use for both tests
	echo "GENERATING DATASET"
	${GENSORT} -a ${COUNT} ${TEMP_DIR}/temp_save.txt
	
	#Clear disk cache
	sync
	echo 3 > /proc/sys/vm/drop_caches
	
	#MySort
	echo "MYSORT"
	cp ${TEMP_DIR}/temp_save.txt ${TEMP_DIR}/temp.txt 
	{ time ${BIN}/mysort ${TEMP_DIR}/temp.txt ${BUFFER} ${NUM_THREADS} ; } 2>> ${MYSORT_OUT} 
	
	#Clear disk cache
	sync
	echo 3 > /proc/sys/vm/drop_caches
	
	#Linux Sort
	echo "LINSORT"
	export LC_ALL=C
	cp ${TEMP_DIR}/temp_save.txt ${TEMP_DIR}/temp.txt
	{ time sort -k1 -S ${BUFFER} --parallel=${NUM_THREADS} -o ${TEMP_DIR}/temp.txt ${TEMP_DIR}/temp.txt ; } 2>> ${LINSORT_OUT}
	
	return
}

function test() {
	COUNT=$1
	NUM_THREADS1=$2
	NUM_THREADS2=$3
	BUFFER=$4
	FILESIZE=$5
	
	MYSORT_OUT=${RES_DIR}/mysort${FILESIZE}.log
	LINSORT_OUT=${RES_DIR}/linsort${FILESIZE}.log
	
	echo "TEST NUM_THREADS=${NUM_THREADS}, DATASET_COUNT: ${COUNT}, BUFFER_SIZE: ${BUFFER}"
	
	#Generate temp file to use for both tests
	rm -r ${TEMP_DIR}/*
	rm -r /tmp/*
	
	#MySort
	echo "MYSORT"
	date
	${GENSORT} -a ${COUNT} ${TEMP_DIR}/temp.txt
	{ ${VALSORT} ${TEMP_DIR}/temp.txt ; } 2>> ${MYSORT_OUT}
	sync; echo 3 > /proc/sys/vm/drop_caches
	sysctl -w vm.drop_caches=3
	${BIN}/mysort ${TEMP_DIR}/temp.txt ${BUFFER} ${NUM_THREADS1} &
	SORT_PID=$! 
	pidstat -T ALL -h -d 1 -r -u -p $SORT_PID >> ${MYSORT_OUT} &
	PIDSTAT=$!
	{ time wait $PIDSTAT ; } 2>> ${MYSORT_OUT}
	{ ${VALSORT} ${TEMP_DIR}/temp.txt ; } 2>> ${MYSORT_OUT}
	date
	
	#Linux Sort
	echo "LINSORT"
	date
	export LC_ALL=C
	${GENSORT} -a ${COUNT} ${TEMP_DIR}/temp.txt
	{ ${VALSORT} ${TEMP_DIR}/temp.txt ; } 2>> ${LINSORT_OUT}
	sync; echo 3 > /proc/sys/vm/drop_caches
	sysctl -w vm.drop_caches=3
	sort -k1 -T ${TEMP_DIR} -S ${BUFFER} --parallel=${NUM_THREADS2} -o ${TEMP_DIR}/temp.txt ${TEMP_DIR}/temp.txt &
	SORT_PID=$! 
	pidstat -T ALL -h -d 1 -r -u -p $SORT_PID >> ${LINSORT_OUT} &
	PIDSTAT=$!
	{ time wait $PIDSTAT ; } 2>> ${LINSORT_OUT}
	{ ${VALSORT} ${TEMP_DIR}/temp.txt ; } 2>> ${LINSORT_OUT}
	date
	
	return
}

#Create the structure
if [ ${MODE} -eq 0 ]; then
	mkdir $TEMP_DIR
	mkdir $RES_DIR
	mkdir $RES_DIR/tables
	mkdir $RES_DIR/fig
fi

#Find optimal number of threads for sorts
if [ ${MODE} -eq 1 ]; then
	thread_test 10000000 1 100m
	thread_test 10000000 2 100m
	thread_test 10000000 4 100m
	thread_test 10000000 8 100m
	thread_test 10000000 16 100m
	thread_test 10000000 32 100m
fi

#1GB Test
if [ ${MODE} -eq 2 ] || [ ${MODE} -eq 6 ]; then
	test 10000000 16 16 8G 1GB
fi

#4GB Test
if [ ${MODE} -eq 3 ] || [ ${MODE} -eq 6 ]; then
    test 40000000 16 16 8G 4GB
fi

#16GB Test
if [ ${MODE} -eq 4 ] || [ ${MODE} -eq 6 ]; then
	test 160000000 16 16 8G 16GB
fi

#64GB Test
if [ ${MODE} -eq 5 ] || [ ${MODE} -eq 6 ]; then
	test 640000000 16 16 8G 64GB
fi

#Parse output logs
if [ ${MODE} -eq 7 ]; then
	python3 ${SCRIPTS}/parse.py ${RES_DIR}
fi

#Reset output logs
if [ ${MODE} -eq 8 ]; then
	rm -r ${RES_DIR}/*
fi

#Validation phase
if [ ${MODE} -eq 9 ]; then
	validate 10000000 16 4g
fi

#Build gensort
if [ ${MODE} -eq 10 ]; then
	rm ${GENSORT} ${VALSORT}
	cd ${SOURCE}/gensort-1.5
	make
fi
