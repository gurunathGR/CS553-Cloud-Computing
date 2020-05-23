#!/bin/bash

MODE=$1
BIN=$2
SOURCE=$3

SCRIPTS=${SOURCE}/scripts
TEMP_DIR="${HOME}/temp"
RES_DIR="${SOURCE}/results"
GENSORT=${SOURCE}/gensort-1.5/gensort
VALSORT=${SOURCE}/gensort-1.5/valsort
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64/
export HADOOP_HOME=/exports/projects/hadoop-3.2.1/
export HADOOP_PREFIX=/exports/projects/hadoop-3.2.1/
export HADOOP_CLASSPATH=${JAVA_HOME}/lib/tools.jar
export SPARK_HOME=/exports/projects/spark-3.0.0-preview2-bin-hadoop3.2/
export PATH=${JAVA_HOME}/bin:${PATH}

##########TEST FUNCTIONS

function HadoopGenSort() {
	COUNT=$1
	OFF=0
	
	${HADOOP_HOME}/bin/hadoop fs -rm /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm -r -f /home/input 
	
	rm my-pipe
	mkfifo my-pipe
	${GENSORT} -a ${COUNT} my-pipe &
	PIPEPID1=$!
	${HADOOP_HOME}/bin/hadoop fs -appendToFile my-pipe /home/input/temp.txt &
	PIPEPID2=$!
	wait $PIPEPID1 $PIPEPID2
}

function HadoopValSort2() {
	OUTFILE=$1
	IFS=$'\n'
	PARTS=($(${HADOOP_HOME}/bin/hadoop fs -ls /home/output | grep part | awk '{ print $8 }'))
	rm ${TEMP_DIR}/vs_sum.sum
	for IDX in ${!PARTS[@]}; do
		HDP_PART=${PARTS[$IDX]}
		echo "${IDX}: ${HADOOP_HOME}/bin/hadoop fs -get -f ${HDP_PART} ${TEMP_DIR}/temp.txt"
		echo
		
		rm my-pipe
		mkfifo my-pipe
		${HADOOP_HOME}/bin/hadoop fs -get -f ${HDP_PART} my-pipe &
		PIPEPID1=$!
		${VALSORT} -o ${TEMP_DIR}/vs_$IDX.sum my-pipe &
		PIPEPID2=$!
		wait $PIPEPID1 $PIPEPID2
		cat ${TEMP_DIR}/vs_$IDX.sum >> ${TEMP_DIR}/vs_sum.sum
	done
	{ ${VALSORT} -s ${TEMP_DIR}/vs_sum.sum ; } 2>> ${OUTFILE}
}

function MySort() {
	COUNT=$1
	NUM_THREADS=$2
	BUFFER=$3
	FILESIZE=$4
	INSTANCE=$5
		
	MYSORT_OUT=${RES_DIR}/mysort${FILESIZE}-${INSTANCE}.log
	echo "MYSORT TEST NUM_THREADS=${NUM_THREADS}, DATASET_COUNT: ${COUNT}, BUFFER_SIZE: ${BUFFER}"
	
	rm -rf ${TEMP_DIR}/*
	rm -rf /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm -r -f /home/input
	${HADOOP_HOME}/bin/hadoop fs -rm -r -f /home/output
	${HADOOP_HOME}/bin/hadoop fs -mkdir /home/input
	
	${GENSORT} -a ${COUNT} ${TEMP_DIR}/temp.txt
	{ ${VALSORT} ${TEMP_DIR}/temp.txt ; } 2>> ${MYSORT_OUT}
	sudo sysctl -w vm.drop_caches=3
	
	date >> ${MYSORT_OUT}
	${BIN}/MySort ${TEMP_DIR}/temp.txt ${BUFFER} ${NUM_THREADS} & 
	SORT_PID=$!
	{ time wait $SORT_PID ; } 2>> ${MYSORT_OUT}
	date >> ${MYSORT_OUT}
	
	{ ${VALSORT} ${TEMP_DIR}/temp.txt ; } 2>> ${MYSORT_OUT}
}

function LinSort() {
	COUNT=$1
	NUM_THREADS1=$2
	BUFFER=$3
	FILESIZE=$4
	INSTANCE=$5
	
	LINSORT_OUT=${RES_DIR}/linsort${FILESIZE}-${INSTANCE}.log
	echo "LINSORT TEST NUM_THREADS=${NUM_THREADS}, DATASET_COUNT: ${COUNT}, BUFFER_SIZE: ${BUFFER}"
	
	export LC_ALL=C
	rm -rf ${TEMP_DIR}/*
	rm -rf /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm -r -f /home/input
	${HADOOP_HOME}/bin/hadoop fs -rm -r -f /home/output
	${HADOOP_HOME}/bin/hadoop fs -mkdir /home/input
	
	${GENSORT} -a ${COUNT} ${TEMP_DIR}/temp.txt
	{ ${VALSORT} ${TEMP_DIR}/temp.txt ; } 2>> ${LINSORT_OUT}
	sudo sysctl -w vm.drop_caches=3
	
	date >> ${LINSORT_OUT}
	sort -k1 -T ${TEMP_DIR} -S ${BUFFER} --parallel=${NUM_THREADS} -o ${TEMP_DIR}/temp.txt ${TEMP_DIR}/temp.txt &
	SORT_PID=$! 
	{ time wait $SORT_PID ; } 2>> ${LINSORT_OUT}
	date >> ${LINSORT_OUT}
	
	{ ${VALSORT} ${TEMP_DIR}/temp.txt ; } 2>> ${LINSORT_OUT}
}

function HadoopSort() {
	COUNT=$1
	MAPPERS=$2
	REDUCERS=$3
	FILESIZE=$4
	INSTANCE=$5
	
	HADOOPSORT_OUT=${RES_DIR}/hadoopsort${FILESIZE}-${INSTANCE}.log
	echo "HadoopSort TEST MAPPERS=${MAPPERS}, REDUCERS=${REDUCERS}, DATASET_COUNT: ${COUNT}"
	
	export LC_ALL=C
	rm -rf ${TEMP_DIR}/*
	rm -rf /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm -r -f /home/output
	sudo sysctl -w vm.drop_caches=3
	
	date >> ${HADOOPSORT_OUT}
	${HADOOP_HOME}/bin/hadoop jar HadoopSort.jar HadoopSort /home/input /home/output -Dmapred.map.tasks=${MAPPERS} -Dmapred.reduce.tasks=${REDUCERS} &
	SORT_PID=$!
	{ time wait $SORT_PID ; } 2>> ${HADOOPSORT_OUT}
	date >> ${HADOOPSORT_OUT}
	
	HadoopValSort2 ${HADOOPSORT_OUT}
}

function SparkSort() {
	COUNT=$1
	NUM_EXECUTORS=$2
	DRIVER_MEMORY=$3
	EXECUTOR_MEMORY=$4
	EXECUTOR_CORES=$5
	FILESIZE=$6
	INSTANCE=$7
	
	SPARKSORT_OUT=${RES_DIR}/sparksort${FILESIZE}-${INSTANCE}.log
	echo "SparkSort TEST NUM_EXECUTORS: ${NUM_EXECUTORS}, EXECUTOR_MEMORY: ${EXECUTOR_MEMORY}, EXECUTOR_CORES: ${EXECUTOR_CORES}, DATASET_COUNT: ${COUNT}"
	
	date
	export LC_ALL=C
	rm -rf ${TEMP_DIR}/*
	rm -rf /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm /tmp/*
	${HADOOP_HOME}/bin/hadoop fs -rm -r -f /home/output
	sudo sysctl -w vm.drop_caches=3
	
	date >> ${SPARKSORT_OUT}
	${SPARK_HOME}/bin/spark-submit \
	--class SparkSort \
	--master yarn \
	--deploy-mode cluster \
	--num-executors ${NUM_EXECUTORS} \
	--driver-memory ${DRIVER_MEMORY} \
	--executor-memory ${EXECUTOR_MEMORY} \
	--executor-cores ${EXECUTOR_CORES} \
	SparkSort.jar /home/input/temp.txt /home/output &
	SORT_PID=$!
	{ time wait $PIDSTAT ; } 2>> ${SPARKSORT_OUT}
	date >> ${SPARKSORT_OUT}
	
	HadoopValSort2 ${SPARKSORT_OUT}
}


##########UPLOADING DATA

#1GB dataset
if [ ${MODE} -eq 600 ]; then
	HadoopGenSort 10000000
fi

#4GB dataset
if [ ${MODE} -eq 601 ]; then
	HadoopGenSort 40000000
fi

#16GB dataset
if [ ${MODE} -eq 602 ]; then
	HadoopGenSort 160000000
fi

#24GB dataset
if [ ${MODE} -eq 603 ]; then
	HadoopGenSort 240000000
fi


#28GB dataset
if [ ${MODE} -eq 604 ]; then
	HadoopGenSort 280000000
fi

#32GB dataset
if [ ${MODE} -eq 605 ]; then
	HadoopGenSort 320000000
fi



##########GENERIC TEST CASES

#MySort
if [ ${MODE} -eq 1 ]; then
	NUM_RECORDS=160000000
	FILE_SIZE=16G
	NUM_THREADS=16
	BUFFER_SIZE=7G
	INSTANCE="1S"
	
	MySort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#LinuxSort
if [ ${MODE} -eq 2 ]; then 
	NUM_RECORDS=160000000
	FILE_SIZE=16G
	NUM_THREADS=16
	BUFFER_SIZE=7G
	INSTANCE="1S"
	
	LinSort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#HadoopSort
if [ ${MODE} -eq 3 ]; then
	NUM_RECORDS=320000000
	FILESIZE=32G
	MAPPERS=4
	REDUCERS=4
	INSTANCE="4S"
	
	HadoopGenSort 320000000
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 4 ]; then
	NUM_RECORDS=320000000
	FILESIZE=32G
	NUM_EXECUTORS=4
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=2g
	EXECUTOR_CORES=4
	INSTANCE="4S"
	
	HadoopGenSort 320000000
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi



##########1GB TESTS, 4 SMALL INSTANCES (8 - 4)

#HadoopSort
if [ ${MODE} -eq 8 ]; then
	NUM_RECORDS=10000000
	FILESIZE=1G
	MAPPERS=2
	REDUCERS=2
	INSTANCE="4S"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 9 ]; then
	NUM_RECORDS=10000000
	FILESIZE=1G
	NUM_EXECUTORS=4
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=2g
	EXECUTOR_CORES=4
	INSTANCE="4S"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########4GB TESTS, 4 SMALL INSTANCES (12 - 4)

#HadoopSort
if [ ${MODE} -eq 12 ]; then
	NUM_RECORDS=40000000
	FILESIZE=4G
	MAPPERS=2
	REDUCERS=2
	INSTANCE="4S"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 13 ]; then
	NUM_RECORDS=40000000
	FILESIZE=4G
	NUM_EXECUTORS=4
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=2g
	EXECUTOR_CORES=4
	INSTANCE="4S"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########16GB TESTS, 4 SMALL INSTANCES (16 - 4)

#HadoopSort
if [ ${MODE} -eq 16 ]; then
	NUM_RECORDS=160000000
	FILESIZE=16G
	MAPPERS=4
	REDUCERS=4
	INSTANCE="4S"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 17 ]; then
	NUM_RECORDS=160000000
	FILESIZE=16G
	NUM_EXECUTORS=8
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=2g
	EXECUTOR_CORES=4
	INSTANCE="4S"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########32GB TESTS, 4 SMALL INSTANCES (20 - 4)

#HadoopSort
if [ ${MODE} -eq 20 ]; then
	NUM_RECORDS=320000000
	FILESIZE=32G
	MAPPERS=1000
	REDUCERS=100
	INSTANCE="4S"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 21 ]; then
	NUM_RECORDS=320000000
	FILESIZE=32G
	NUM_EXECUTORS=8
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=2g
	EXECUTOR_CORES=4
	INSTANCE="4S"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########1GB TESTS, 1 LARGE INSTANCE (24 - 4)

#MySort
if [ ${MODE} -eq 24 ]; then
	NUM_RECORDS=10000000
	FILE_SIZE=1G
	NUM_THREADS=16
	BUFFER_SIZE=7G
	INSTANCE="1L"
	
	MySort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#LinuxSort
if [ ${MODE} -eq 25 ]; then 
	NUM_RECORDS=10000000
	FILE_SIZE=1G
	NUM_THREADS=16
	BUFFER_SIZE=7G
	INSTANCE="1L"
	
	LinSort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#HadoopSort
if [ ${MODE} -eq 26 ]; then
	NUM_RECORDS=10000000
	FILESIZE=1G
	MAPPERS=2
	REDUCERS=2
	INSTANCE="1L"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 27 ]; then
	NUM_RECORDS=10000000
	FILESIZE=1G
	NUM_EXECUTORS=4
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=4g
	EXECUTOR_CORES=4
	INSTANCE="1L"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########4GB TESTS, 1 LARGE INSTANCE (28 - 4)

#MySort
if [ ${MODE} -eq 28 ]; then
	NUM_RECORDS=40000000
	FILE_SIZE=4G
	NUM_THREADS=16
	BUFFER_SIZE=12G
	INSTANCE="1L"
	
	MySort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#LinuxSort
if [ ${MODE} -eq 29 ]; then 
	NUM_RECORDS=40000000
	FILE_SIZE=4G
	NUM_THREADS=16
	BUFFER_SIZE=12G
	INSTANCE="1L"
	
	LinSort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#HadoopSort
if [ ${MODE} -eq 30 ]; then
	NUM_RECORDS=40000000
	FILESIZE=4G
	MAPPERS=2
	REDUCERS=2
	INSTANCE="1L"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 31 ]; then
	NUM_RECORDS=40000000
	FILESIZE=4G
	NUM_EXECUTORS=4
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=2g
	EXECUTOR_CORES=4
	INSTANCE="1L"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########16GB TESTS, 1 LARGE INSTANCE (32 - 4)

#MySort
if [ ${MODE} -eq 32 ]; then
	NUM_RECORDS=160000000
	FILE_SIZE=16G
	NUM_THREADS=16
	BUFFER_SIZE=25G
	INSTANCE="1L"
	
	MySort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#LinuxSort
if [ ${MODE} -eq 33 ]; then 
	NUM_RECORDS=160000000
	FILE_SIZE=16G
	NUM_THREADS=16
	BUFFER_SIZE=25G
	INSTANCE="1L"
	
	LinSort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#HadoopSort
if [ ${MODE} -eq 34 ]; then
	NUM_RECORDS=160000000
	FILESIZE=16G
	MAPPERS=4
	REDUCERS=4
	INSTANCE="1L"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 35 ]; then
	NUM_RECORDS=160000000
	FILESIZE=16G
	NUM_EXECUTORS=8
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=2g
	EXECUTOR_CORES=4
	INSTANCE="1L"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########32GB TESTS, 1 LARGE INSTANCE (36 - 4)

#MySort
if [ ${MODE} -eq 36 ]; then
	NUM_RECORDS=320000000
	FILE_SIZE=32G
	NUM_THREADS=16
	BUFFER_SIZE=24G
	INSTANCE="1L"
	
	MySort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#LinuxSort
if [ ${MODE} -eq 37 ]; then 
	NUM_RECORDS=320000000
	FILE_SIZE=32G
	NUM_THREADS=16
	BUFFER_SIZE=24G
	INSTANCE="1L"
	
	LinSort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#HadoopSort
if [ ${MODE} -eq 38 ]; then
	NUM_RECORDS=320000000
	FILESIZE=32G
	MAPPERS=4
	REDUCERS=4
	INSTANCE="1L"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 39 ]; then
	NUM_RECORDS=320000000
	FILESIZE=32G
	NUM_EXECUTORS=8
	DRIVER_MEMORY=4g
	EXECUTOR_MEMORY=2g
	EXECUTOR_CORES=4
	INSTANCE="1L"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########1GB TESTS, 1 SMALL INSTANCE (40 - 4)

#MySort
if [ ${MODE} -eq 40 ]; then
	NUM_RECORDS=10000000
	FILE_SIZE=1G
	NUM_THREADS=16
	BUFFER_SIZE=6G
	INSTANCE="1S"
	
	MySort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#LinuxSort
if [ ${MODE} -eq 41 ]; then 
	NUM_RECORDS=10000000
	FILE_SIZE=1G
	NUM_THREADS=16
	BUFFER_SIZE=6G
	INSTANCE="1S"
	
	LinSort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#HadoopSort
if [ ${MODE} -eq 42 ]; then
	NUM_RECORDS=10000000
	FILESIZE=1G
	MAPPERS=2
	REDUCERS=2
	INSTANCE="1S"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 43 ]; then
	NUM_RECORDS=10000000
	FILESIZE=1G
	NUM_EXECUTORS=4
	DRIVER_MEMORY=2g
	EXECUTOR_MEMORY=1g
	EXECUTOR_CORES=4
	INSTANCE="1S"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########4GB TESTS, 1 SMALL INSTANCE (44 - 4)

#MySort
if [ ${MODE} -eq 44 ]; then
	NUM_RECORDS=40000000
	FILE_SIZE=4G
	NUM_THREADS=16
	BUFFER_SIZE=6G
	INSTANCE="1S"
	
	MySort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#LinuxSort
if [ ${MODE} -eq 45 ]; then 
	NUM_RECORDS=40000000
	FILE_SIZE=4G
	NUM_THREADS=16
	BUFFER_SIZE=6G
	INSTANCE="1S"
	
	LinSort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#HadoopSort
if [ ${MODE} -eq 46 ]; then
	NUM_RECORDS=40000000
	FILESIZE=4G
	MAPPERS=2
	REDUCERS=2
	INSTANCE="1S"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 47 ]; then
	NUM_RECORDS=40000000
	FILESIZE=4G
	NUM_EXECUTORS=4
	DRIVER_MEMORY=2g
	EXECUTOR_MEMORY=1g
	EXECUTOR_CORES=4
	INSTANCE="1S"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi

##########16GB TESTS, 1 SMALL INSTANCE (48 - 4)

#MySort
if [ ${MODE} -eq 48 ]; then
	NUM_RECORDS=160000000
	FILE_SIZE=16G
	NUM_THREADS=16
	BUFFER_SIZE=6G
	INSTANCE="1S"
	
	MySort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#LinuxSort
if [ ${MODE} -eq 49 ]; then 
	NUM_RECORDS=160000000
	FILE_SIZE=16G
	NUM_THREADS=16
	BUFFER_SIZE=6G
	INSTANCE="1S"
	
	LinSort ${NUM_RECORDS} ${NUM_THREADS} ${BUFFER_SIZE} ${FILE_SIZE} ${INSTANCE}
fi

#HadoopSort
if [ ${MODE} -eq 50 ]; then
	NUM_RECORDS=160000000
	FILESIZE=16G
	MAPPERS=250
	REDUCERS=8
	INSTANCE="1S"
	
	HadoopSort ${NUM_RECORDS} ${MAPPERS} ${REDUCERS} ${FILESIZE} ${INSTANCE}
fi

#SparkSort
if [ ${MODE} -eq 51 ]; then
	NUM_RECORDS=160000000
	FILESIZE=16G
	NUM_EXECUTORS=4
	DRIVER_MEMORY=2g
	EXECUTOR_MEMORY=1g
	EXECUTOR_CORES=4
	INSTANCE="1S"
	
	SparkSort ${NUM_RECORDS} ${NUM_EXECUTORS} ${DRIVER_MEMORY} ${EXECUTOR_MEMORY} ${EXECUTOR_CORES} ${FILESIZE} ${INSTANCE}
fi



##########TEST INITIALIZATION AND ANALYSIS

#Create the structure
if [ ${MODE} -eq 0 ]; then
	mkdir $TEMP_DIR
	mkdir $RES_DIR
	mkdir $RES_DIR/tables
	mkdir $RES_DIR/fig
fi

#Parse output logs
if [ ${MODE} -eq 500 ]; then
	python3 ${SCRIPTS}/parse.py ${RES_DIR}
fi

#Reset output logs
if [ ${MODE} -eq 501 ]; then
	rm -r ${RES_DIR}/*
fi

#Build gensort
if [ ${MODE} -eq 502 ]; then
	rm ${GENSORT} ${VALSORT}
	cd ${SOURCE}/gensort-1.5
	make
fi

#Build HadoopSort
if [ ${MODE} -eq 503 ]; then
	${HADOOP_HOME}/bin/hadoop com.sun.tools.javac.Main ${SOURCE}/src/HadoopSort.java
	mv ${SOURCE}/src/HadoopSort*.class .
	jar cf HadoopSort.jar HadoopSort*.class
fi

#Build SparkSort
if [ ${MODE} -eq 504 ]; then
	javac -cp ${SPARK_HOME}/jars/spark-core_2.12-3.0.0-preview2.jar:${SPARK_HOME}/jars/scala-library-2.12.10.jar ${SOURCE}/src/SparkSort.java
	mv ${SOURCE}/src/SparkSort*.class .
	jar cvf SparkSort.jar SparkSort*.class
fi

#Get system resource utilization
if [ ${MODE} -eq 505 ]; then
	sar -u -r -b 1 >> ${RES_DIR}/${TEST_CASE}-sar.log
fi
