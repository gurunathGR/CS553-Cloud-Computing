# HW6

## Overview

The src folder contains mysort.c, HadoopSort.java, and SparkSort.java 
The gensort-1.5 folder contains the gensort library.  
The scripts folder contains bash scripts that automate tests.  
The doc folder contains the report.  
The results folder contains the results of experiments executed using make test-* commands.
The results/tables folder contains the results specific to the 32GB test cases.

## CD into the NameNode

ssh ubuntu@<your-namenode-ip>  

## Prerequisites

cmake  
build-essential  
pidstat  
zlib  
  
sudo apt-get install cmake sysstat build-essential libz-dev  

## Building

1. cd /path/to/hw6  
2. mkdir build  
3. cd build  
4. cmake ../  
5. make  

## Testing Sort Performance

#### Initializing Tests:  
make structure  
make reset  
make gensort  
make HadoopSort  
make SparkSort  

#### Running Custom Tests:

#MySort Tests
1. Modify the MySort variables in the MySort test on line 199
2. make mysort-test

#Linsort Tests
1. Modify the Linsort variables in the Linsort test on line 208
2. make linsort-test

#Hadoop Tests
1. Modify the HadoopSort variables in the HadoopSort test on line 218
2. make hadoop-test

#Spark Test 
1. Modify the SparkSort variables in the SparkSort test on line 228
2. make hadoop-test



#### Running Predefined Tests:

Tests follow the format: [sort-type]-test-[file-size]-[instances]
Sort-Type: mysort, linsort, hadoop, spark
File-Size: 1G, 4G, 16G, 32G
Instances: 1S, 1L, 4S (1S - 1 small, 1L - 1 large, 4S - 4 small)

Before running a Hadoop or Spark test, you must call make gen-1G, gen-4G, gen-16G, or gen-32G
For example:
	make gen-16G
	make hadoop-test-16G-1S
Note, MySort and LinSort tests will automatically generate the data.

#MySort Tests
make mysort-test-1G-1S
make mysort-test-4G-1S
make mysort-test-16G-1S

make mysort-test-1G-1L
make mysort-test-4G-1L
make mysort-test-16G-1L

#Linsort Tests
make linsort-test-1G-1S
make linsort-test-4G-1S
make linsort-test-16G-1S

make linsort-test-1G-1L
make linsort-test-4G-1L
make linsort-test-16G-1L

#Hadoop Tests
make hadoop-test-1G-1S
make hadoop-test-4G-1S
make hadoop-test-16G-1S

make hadoop-test-1G-1L
make hadoop-test-4G-1L
make hadoop-test-16G-1L
make hadoop-test-16G-1L

make hadoop-test-1G-4S
make hadoop-test-4G-4S
make hadoop-test-16G-4S
make hadoop-test-32G-4S

#Spark Tests
make spark-test-1G-1S
make spark-test-4G-1S
make spark-test-16G-1S

make spark-test-1G-1L
make spark-test-4G-1L
make spark-test-16G-1L
make spark-test-16G-1L

make spark-test-1G-4S
make spark-test-4G-4S
make spark-test-16G-4S
make spark-test-32G-4S





#### Use MySort directly:  
./MySort [/path/to/file] [buffer_size] [num_threads]  
  
buffer_size can take on numbers suffixed with K,M,G.  
For example, 1G or 32M for 1 gigabyte and 32 megabytes respectively.  
  
  
  
