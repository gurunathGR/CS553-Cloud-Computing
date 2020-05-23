
#ifndef MYSORT_H
#define MYSORT_H

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

#define KEY_SIZE 10
#define RECORD_SIZE 100
#define MAX_CHUNK_SIZE 64000000
#define MIN_LEAF_SIZE 64000
#define MIN_BUFFER_SIZE (RECORD_SIZE*8)
#define ALIGN(num, to) (((num)/to)*to)

extern size_t CHUNK_SIZE; //defined in cache.c

typedef struct MM_CACHE_SLOT MM_CACHE_SLOT; 
typedef struct CHUNK CHUNK;
typedef void *(*THREAD_FUN)(void *);

#define IN_USE 1
#define IS_DIRTY 2
#define IS_LOADED 4

typedef enum OPERATION
{
	NO_OP,
	SORT_WINDOW,
	READ_CHUNK,
	WRITE_CHUNK
} OPERATION;

struct CHUNK
{
	char min[KEY_SIZE];
	char max[KEY_SIZE];
	size_t off;
	size_t size;
	MM_CACHE_SLOT *slot; 
};

struct MM_CACHE_SLOT
{
	int flags;
	CHUNK *chunk;
	char *buffer;
};

typedef struct MM_CACHE
{
	size_t last_pin;
	size_t max_chunks;
	size_t free_chunks;
	size_t empty_chunks;
	char *buffer;
	MM_CACHE_SLOT *slots;
} MM_CACHE;

typedef struct TASK
{
	pthread_mutex_t lock;
	pthread_cond_t cond;
	int done;
} TASK;

typedef struct WORKER
{
	pthread_mutex_t lock;
	pthread_cond_t cond;	
	pthread_t tid;
	int init;
	int worker_id;
	int op;
	
	TASK *task;
	FILE *fd;
	char *buffer;
	size_t off, size;
} WORKER;

typedef struct WORKER_POOL
{
	pthread_mutex_t lock;
	pthread_cond_t cond;
	
	int num_workers;
	int free_workers;
	WORKER *workers;
	
	size_t max_tasks;
	size_t num_tasks;
	size_t task_head;
} WORKER_POOL;

//misc.c
size_t ceild(size_t a, size_t b);
size_t get_size(char *num_str);
size_t get_file_size(char *path);
size_t prng(void);

//task.c
void init_task(TASK *task);
void start_task(TASK *task);
void wait_for_task(TASK *task);
void finish_task(TASK *task);

//io.c
void init_io_thread_pool(char *path, int num_threads);
void schedule_io(char *buffer, size_t size, size_t off, TASK *task, int op);
void io_read(char *buffer, size_t size, size_t off, TASK *task);
void io_write(char *buffer, size_t size, size_t off, TASK *task);
void wait_for_all_io(void);
void io_finish(WORKER *worker);
void terminate_io(void);
void wait_for_io_term(void);

//cache.c
CHUNK *divide_file(size_t file_size, size_t buffer_size, int num_threads, size_t *num_chunksp);
void init_chunk_cache(size_t file_size, size_t buffer_size, size_t *cache_sizep); 
void read_chunk(CHUNK *chunk);
void write_chunk(CHUNK *chunk);
void flush_chunk(CHUNK *chunk);
void flush_cache(void);
void load_window(CHUNK *chunk_array, size_t length, size_t *load_countp, size_t *load_sizep);
void write_window(CHUNK *chunk_array, size_t length);
void map_chunks(CHUNK *sorted, size_t length);

//worker.c
void init_worker_pool(char *path, int num_threads);
int can_schedule(void);
int schedule(char *buffer, size_t size, int op);
void finish(WORKER *worker);
void wait_for_all_workers(void);
void terminate_workers(void);
void wait_for_worker_term(void);

//mysort.c
int buffer_is_sorted(char *buffer, size_t buffer_size, size_t record_size, size_t key_size);
void sort_buffer_parallel(char *buffer, size_t buffer_size, size_t record_size, size_t key_size);
void sort_buffer_seq(char *buffer, size_t buffer_size, size_t record_size, size_t key_size);
void internal_sort(char *path, size_t num_chunks);
int chunks_are_sorted(CHUNK *chunks, int num_chunks);
void sort_window(char *buffer, size_t size);
void parallel_sort(CHUNK *chunk_array, size_t num_chunks, size_t cache_size);


#endif
