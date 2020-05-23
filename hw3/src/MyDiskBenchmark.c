
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

typedef struct {
    pthread_t tid;
    int init;
} THREAD;

typedef struct {
    int worker_id;
    int workload;
    int fd;
    char *block;
    size_t record_size;
    size_t file_size;
} TASK;

TASK *task_vector;
THREAD *threads;

size_t get_size(double count, char *unit)
{
    size_t size = 0;

    if(strcmp(unit, "k") == 0) {
        size = (size_t)(count*(((size_t)1)<<10));
    }
    
    else if(strcmp(unit, "m") == 0) {
        size = (size_t)(count*(((size_t)1)<<20));
    }
    
    else if(strcmp(unit, "g") == 0) {
        size = (size_t)(count*(((size_t)1)<<30));
    }
    
    else {
        printf("ERROR: Invalid unit %s\n", unit);
        exit(1);
    }
    
    return (size/4096)*4096;
}

size_t prand(size_t record_size, size_t file_size)
{
    static int init = 0;
    if(!init) {
        srand(238592);
        init = 1;
    }
    
    if((file_size - record_size)/4096 == 0) {
		return 0;
	}
    
    //prand returns a number aligned to 4KB
    return (rand()%((file_size - record_size)/4096))*4096;
}

void read_seq(int fd, size_t record_size, size_t file_size, char *block)
{
	for(size_t i = 0; i < file_size; i += record_size) {
	    lseek(fd, i, SEEK_SET);
	    size_t count = read(fd, block, record_size);
	    if(count == -1) {
	        printf("ERROR: Did not read (seq) all data (i=%lu/%lu, count=%lu/%lu)\n", i, file_size, count, record_size);
	        perror("ERROR");
	        exit(1);
	    }
	}
}

void read_rand(int fd, size_t record_size, size_t file_size, char *block)
{
	for(size_t i = 0; i < file_size; i += record_size) {
	    lseek(fd, prand(record_size, file_size), SEEK_SET);
	    size_t count = read(fd, block, record_size);
	    if(count == -1) {
	        printf("ERROR: Did not read (rand) all data (i=%lu/%lu, count=%lu/%lu)\n", i, file_size, count, record_size);
	        perror("ERROR");
	        exit(1);
	    }
	}
}

void write_seq(int fd, size_t record_size, size_t file_size, char *block)
{
	for(size_t i = 0; i < file_size; i += record_size) {
	    lseek(fd, i, SEEK_SET);
	    size_t count = write(fd, block, record_size);
	    if(count == -1) {
	        printf("ERROR: Did not write (seq) all data (i=%lu/%lu, count=%lu/%lu)\n", i, file_size, count, record_size);
	        perror("ERROR");
	        exit(1);
	    }
	}
}

void write_rand(int fd, size_t record_size, size_t file_size, char *block)
{
	for(size_t i = 0; i < file_size; i += record_size) {
	    lseek(fd, prand(record_size, file_size), SEEK_SET);
	    size_t count = write(fd, block, record_size);
	    if(count == -1) {
	        printf("ERROR: Did not write (rand) all data (i=%lu/%lu, count=%lu/%lu)\n", i, file_size, count, record_size);
	        perror("ERROR");
	        exit(1);
	    }
	}
}

void *worker_thread(void *data)
{
    int worker_id = *((int*)data);
    size_t count;
    
    threads[worker_id].init = 1;
    switch(task_vector[worker_id].workload) {
	    case 0: 
		    write_seq(task_vector[worker_id].fd, task_vector[worker_id].record_size, task_vector[worker_id].file_size, task_vector[worker_id].block);
		    break;
	    case 1:
		    write_rand(task_vector[worker_id].fd, task_vector[worker_id].record_size, task_vector[worker_id].file_size, task_vector[worker_id].block);
		    break;
		case 2: 
		    read_seq(task_vector[worker_id].fd, task_vector[worker_id].record_size, task_vector[worker_id].file_size, task_vector[worker_id].block);
		    break;
	    case 3:
		    read_rand(task_vector[worker_id].fd, task_vector[worker_id].record_size, task_vector[worker_id].file_size, task_vector[worker_id].block);
		    break;
    }
}

void test(char *dir, int workload, size_t record_size, size_t file_size, int num_files)
{
	char *path = malloc(16384);
	int dirlen = strlen(dir);
	int loc = 0;
	struct timespec start, end;
	
	//Open files
	int fds[num_files];
	for(int i = 0; i < num_files; i++) {
	    sprintf(path, "%s/temp_%d", dir, i);
	    int fd = -1;
	    switch(workload) {
	        case 0:
		    case 1:
		        remove(path);
			    fd = open(path, O_CREAT | O_WRONLY | O_DIRECT | O_SYNC, 0);
			    break;
		    case 2:
			case 3:
			    fd = open(path, O_RDONLY | O_DIRECT | O_SYNC, 0);
			    break;
	    }
	    if(fd < 0) {
		    printf("Error opening %s\n", path);
		    perror("ERROR");
		    exit(1);
	    }
	    fds[i] = fd;
	}
	
	//Start clock
	clock_gettime(CLOCK_MONOTONIC_RAW, &start);
	
	//Create threads for each file
	for(int i = 0; i < num_files; i++) {
	    task_vector[i].worker_id = i;
        task_vector[i].workload = workload;
        task_vector[i].fd = fds[i];
        task_vector[i].block = aligned_alloc(4096, record_size);
        if(task_vector[i].block == NULL) {
            printf("Could not align memory to 4KB\n");
            exit(1);
        }
        task_vector[i].record_size = record_size;
        task_vector[i].file_size = (file_size/record_size)*record_size;
        
        threads[i].init = 0;
        pthread_create(&threads[i].tid, NULL, worker_thread, (void*)&task_vector[i].worker_id);
        while(!threads[i].init);
    }
    
    //Wait for threads
	for(int i = 0; i < num_files; i++) {
	    pthread_join(threads[i].tid, NULL);
	    free(task_vector[i].block);
	}
	
	//Stop clock
	clock_gettime(CLOCK_MONOTONIC_RAW, &end);
	
	//Close files
	for(int i = 0; i < num_files; i++) {
	    close(fds[i]);
	}
	
	//Print Timing Results
	size_t total_data = file_size*num_files;
	size_t total_io = (file_size/record_size)*num_files;
	double time_us = ((double)end.tv_sec - (double)start.tv_sec)*1000000 + ((double)end.tv_nsec - (double)start.tv_nsec)/1000;
	double time_s = ((double)end.tv_sec - (double)start.tv_sec) + ((double)end.tv_nsec - (double)start.tv_nsec)/1000000000;
	double mbps = total_data/time_us;
	double iops = total_io/time_s;
	printf("TIMER: (workload=%d, throughput=%lf, iops=%lf)\n", workload, mbps, iops);
}

int main(int argc, char **argv)
{
	if(argc < 7) {
		printf("Usage: ./mydiskbenchmark [/path/to/tempdir] [workload] [record_size] [record_size_unit] [file_size] [file_size_unit] [num_files]\n");
		printf("[/path/to/tempdir]: the path to the directory where files will be written.\n");
		printf("[workload]: the workload to run.\n");
		printf("[record_size]: The maximum amount of data to write to a file at once.\n");
		printf("[record_size_unit]: The unit of block size (k/m/g)\n");
		printf("[file_size]: The total size of the file.\n");
		printf("[file_size_unit]: The unit of file size (k/m/g)\n");
		printf("[num_files]: The number of files to write concurrently.\n");
		printf("Workloads\n");
		printf("  0 - Write Sequential\n");
		printf("  1 - Write Random\n");
		printf("  2 - Read Sequential\n");
		printf("  3 - Read Random\n");
		exit(1);
	}
	
	printf("STARTING TEST\n");
	printf("[/path/to/tempdir]: %s\n", argv[1]);
	printf("[workload]: %s\n", argv[2]);
	printf("[record_size]: %s%s\n", argv[3], argv[4]);
	printf("[file_size]: %s%s\n", argv[5], argv[6]);
	printf("[num_files]: %s\n", argv[7]);
	
	char *dir = argv[1];
	int workload = atoi(argv[2]);
	size_t record_size = get_size(atof(argv[3]), argv[4]);
	size_t file_size = get_size(atof(argv[5]), argv[6]);
	int num_files = atoi(argv[7]);
	
	//Initialize thread variables
	task_vector = malloc(num_files * sizeof(TASK));
    threads = malloc(num_files * sizeof(THREAD));
    
    //Run test
    test(dir, workload, record_size, file_size, num_files);
    
	printf("TEST FINISHED!\n");
}



