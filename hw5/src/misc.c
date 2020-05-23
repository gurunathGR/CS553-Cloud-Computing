
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h> 
#include <mysort/mysort.h>

//Returns the ceiling of a/b
size_t ceild(size_t a, size_t b)
{
	if(a % b) {
		return a/b + 1;
	}
	return a/b;
}

//Convert a number string into a size
size_t get_size(char *num_str)
{
	int len_num_str = strlen(num_str);
	double num = atof(num_str);
	char unit = num_str[len_num_str - 1];
	
	if(unit == 'k' || unit == 'K') {
		return (size_t)(num*(((size_t)1) << 10));
	}
	
	else if(unit == 'm' || unit == 'M') {
		return (size_t)(num*(((size_t)1) << 20));
	}
	
	else if(unit == 'g' || unit == 'G') {
		return (size_t)(num*(((size_t)1) << 30));
	}
	
	printf("Could not convert number into a size\n");
	exit(1);
}

//Get the size of a file in bytes
size_t get_file_size(char *path)
{
	FILE *file = fopen(path, "r");
	fseek(file, 0, SEEK_END);
	size_t fsize = ftell(file);
	fseek(file, 0, SEEK_SET);
	fclose(file);
	return fsize;
}

//A very simple "RNG"
size_t prng(void)
{
	static size_t count = 0;
	size_t num;
	
	num = ((count + 4328252)*23094) / 382;
	num = num*(count&0x82892) + (count+21)*(count+8923)*289239;
	
	count++;
	return num;
}
