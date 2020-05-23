# HW5

## Overview

The src folder contains the mysort.c  
The gensort-1.5 folder contains the gensort library.  
The scripts folder contains bash scripts that automate tests.  
The doc folder contains the report.  
The results folder contains the results of experiments executed using make test-* commands.  

## Prerequisites

cmake  
build-essential  
pidstat  
  
sudo apt-get install cmake sysstat build-essential  

## Building

1. cd /path/to/hw5  
2. mkdir build  
3. cd build  
4. cmake ../  
5. make  

## Testing Sort Performance

#### Initializing Tests:  
make structure  
make gensort

#### Running All tests
sudo su  
make reset
make test-all  
exit  

#### Running Individual Tests:

#1GB test  
sudo su  
make test1  
exit
  
#4GB test  
sudo su  
make test2  
exit  
   
#16GB test  
sudo su  
make test3  
exit  
  
#64GB test  
sudo su  
make test4  
exit  
  
#### Use MySort directly:  
./mysort [/path/to/file] [buffer_size] [num_threads]  
  
buffer_size can take on numbers suffixed with K,M,G.  
For example, 1G or 32M for 1 gigabyte and 32 megabytes respectively.  
  
  
  
