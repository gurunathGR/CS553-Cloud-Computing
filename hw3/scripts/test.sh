#!/bin/bash

MODE=$1
BIN=$2
SOURCE=$3

SCRIPTS=${SOURCE}/scripts
TEMP_DIR="$HOME/temp"
RES_DIR="$SOURCE/results"

mkdir $TEMP_DIR
mkdir $RES_DIR
mkdir $RES_DIR/tables
mkdir $RES_DIR/fig

function test_throughput() {
	local tempdir=$1
	local record_size=$2
	local record_size_unit=$3
	local file_size=$4
	local file_size_unit=$5
	local num_files=$6
	
	#Clear disk cache
	sync
	echo 3 > /proc/sys/vm/drop_caches
    
    #Run MyDiskBenchmark
    WORKLOADS=(0 1 2 3)
    rm -f ${TEMP_DIR}/*
    for workload in ${WORKLOADS[@]}; do
		echo "MyDiskBenchmark(workload=${workload}, tempdir=${tempdir}, record_size=${record_size}${record_size_unit}, file_size=${file_size}${file_size_unit}, num_files=${num_files})"
		${BIN}/mydiskbenchmark ${tempdir} ${workload} ${record_size} ${record_size_unit} ${file_size} ${file_size_unit} ${num_files}\
		>> "${RES_DIR}/mdb_bench_${record_size}${record_size_unit}_${file_size}${file_size_unit}${num_files}.txt"
		if [ $? != 0 ]; then
			echo "MyDiskBenchmark failed"
			exit 1
		fi
	done
	
    #Clear disk cache
	sync
	echo 3 > /proc/sys/vm/drop_caches
        
    #Run IOZone
    echo "IOZone         (tempdir=${tempdir}, record_size=${record_size}${record_size_unit}, file_size=${file_size}${file_size_unit}, num_files=${num_files})"
    rm -f ${TEMP_DIR}/*
    TEMP=()
    for i in $(seq 1 ${num_files}); do 
        TEMP+=("${TEMP_DIR}/temp_$i")
    done
    ${SOURCE}/iozone/src/current/iozone -R -I -o -T -O -i 0 -i 1 -i 2\
    -t ${num_files} -s ${file_size}${file_size_unit} -r ${record_size}${record_size_unit} -F ${TEMP[@]}\
    >> "${RES_DIR}/iozone_bench_${record_size}${record_size_unit}_${file_size}${file_size_unit}${num_files}.txt"
    if [ $? != 0 ]; then
        echo "IOZone failed"
        exit 1
    fi
}

function test_latency() {
	local tempdir=$1
	local record_size=$2
	local record_size_unit=$3
	local file_size=$4
	local file_size_unit=$5
	local num_files=$6
	
	#Clear disk cache
	sync
	echo 3 > /proc/sys/vm/drop_caches
    
    #Run MyDiskBenchmark
    WORKLOADS=(1 3)
    rm -f ${TEMP_DIR}/*
    for workload in ${WORKLOADS[@]}; do
		echo "MyDiskBenchmark(workload=${workload}, tempdir=${tempdir}, record_size=${record_size}${record_size_unit}, file_size=${file_size}${file_size_unit}, num_files=${num_files})"
		${BIN}/mydiskbenchmark ${tempdir} ${workload} ${record_size} ${record_size_unit} ${file_size} ${file_size_unit} ${num_files}\
		>> "${RES_DIR}/mdb_bench_${record_size}${record_size_unit}_${file_size}${file_size_unit}${num_files}.txt"
		if [ $? != 0 ]; then
			echo "MyDiskBenchmark failed"
			exit 1
		fi
	done
    
    #Clear disk cache
	sync
	echo 3 > /proc/sys/vm/drop_caches
      
    #Run IOZone
    echo "IOZone         (tempdir=${tempdir}, record_size=${record_size}${record_size_unit}, file_size=${file_size}${file_size_unit}, num_files=${num_files})"
    rm -f ${TEMP_DIR}/*
    TEMP=()
    for i in $(seq 1 ${num_files}); do 
        TEMP+=("${TEMP_DIR}/temp_$i") 
    done
    ${SOURCE}/iozone/src/current/iozone -R -I -o -T -O -i 0 -i 2\
    -t ${num_files} -s ${file_size}${file_size_unit} -r ${record_size}${record_size_unit} -F ${TEMP[@]}\
    >> "${RES_DIR}/iozone_bench_${record_size}${record_size_unit}_${file_size}${file_size_unit}${num_files}.txt"
    if [ $? != 0 ]; then
        echo "IOZone failed"
        exit 1
    fi
}

#Test if the MyDiskBenchmark and IOZone program works
if [ ${MODE} -eq 0 ]; then 
	RECORD_SIZE=64
	RECORD_SIZE_UNIT=k
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 16 m 1
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 8 m 2
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 4 m 4
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 2 m 8
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 1.33 m 12
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 666.66 k 24
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 333.33 k 48
	
	RECORD_SIZE=1
	RECORD_SIZE_UNIT=m
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 1 g 1
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 500 m 2
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 250 m 4
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 125 m 8
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 83.33 m 12
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 41.67 m 24
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 20.83 m 48
	
	RECORD_SIZE=16
	RECORD_SIZE_UNIT=m
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 1 g 1
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 500 m 2
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 250 m 4
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 125 m 8
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 83.33 m 12
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 41.67 m 24
	test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 20.83 m 48

	RECORD_SIZE=4
	RECORD_SIZE_UNIT=k
	test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 1 m 1
	test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 500 k 2
	test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 250 k 4
	test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 125 k 8
	test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 83.33 k 12
	test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 41.67 k 24
	test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 20.83 k 48 
fi

#The actual test cases
if [ ${MODE} -eq 1 ]; then
    for i in $(seq 1 3); do
		RECORD_SIZE=64
		RECORD_SIZE_UNIT=k
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 10 g 1
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 5 g 2
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 2.5 g 4
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 1.25 g 8
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 833.33 m 12
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 433.67 m 24
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 208.33 m 48
		
		RECORD_SIZE=1
		RECORD_SIZE_UNIT=m
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 10 g 1
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 5 g 2
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 2.5 g 4
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 1.25 g 8
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 833.33 m 12
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 433.67 m 24
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 208.33 m 48
		
		RECORD_SIZE=16
		RECORD_SIZE_UNIT=m
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 10 g 1
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 5 g 2
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 2.5 g 4
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 1.25 g 8
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 833.33 m 12
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 433.67 m 24
		test_throughput $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 208.33 m 48
			
        RECORD_SIZE=4
        RECORD_SIZE_UNIT=k
        test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 1 g 1
        test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 500 m 2
        test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 250 m 4
        test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 125 m 8
        test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 83.33 m 12
        test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 41.67 m 24
        test_latency $TEMP_DIR ${RECORD_SIZE} ${RECORD_SIZE_UNIT} 20.83 m 48
    done
fi

#Parse and draw figures
if [ ${MODE} -eq 2 ]; then
	python3 ${SCRIPTS}/parse.py ${RES_DIR}
fi

#Remove old test data
if [ ${MODE} -eq 3 ]; then
    rm -f ${RES_DIR}/*
fi

