# Homework 1

The doc folder contains the report  
The scripts folder contains the shell and python scripts used in Question 3  

## scripts/generate-dataset.sh

Generates a random dataset of the following form: [int] [int] [string]  
* integers are 32-bit  
* the string is a sequence of 100 bytes  
Usage: bash scripts/generate-dataset.sh /path/to/output.csv num_records  

## scripts/sort-data.sh

Sorts a dataset produced by generate-dataset.sh  
Usage: bash scripts/sort-data.sh /path/to/output.csv  

## scripts/analyze.py

Draws a graph of the execution time for generate-dataset.sh and sort-data.sh with 1K, 100K, and 10M records.  
Usage: python3 scripts/analyze.py  