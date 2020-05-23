
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

//Check if a buffer is sorted
int buffer_is_sorted(char *buffer, size_t buffer_size, size_t record_size, size_t key_size)
{
	for(size_t i = record_size; i < buffer_size; i += record_size) {
		char *prior_key = buffer + i - record_size;
		char *cur_key = buffer + i;
		int cmp = strncmp(prior_key, cur_key, key_size); 
		if(cmp > 0) {
			return 0;
		}
	}
	
	return 1;
}

//Sort a buffer in RAM
void sort_buffer_parallel(char *buffer, size_t buffer_size, size_t record_size, size_t key_size)
{
	//Check if sorted
	if(buffer_is_sorted(buffer, buffer_size, record_size, key_size)) {
		return;
	}
	
	//Get pivot
	char *temp_record = malloc(record_size);
	size_t q = (prng()%(buffer_size/record_size))*record_size;
	char *pivot = buffer + q;
	q = 0;
	
	//Partition
	for(size_t i = 0; i < buffer_size; i += record_size) {
		char *record = buffer + i;
		int cmp = strncmp(record, pivot, key_size);
		if(cmp <= 0) {
			memcpy(temp_record, record, record_size);
			memcpy(record, buffer + q, record_size);
			memcpy(buffer + q, temp_record, record_size);
			if(cmp == 0) {
				pivot = buffer + q;
			}
			q += record_size;
		} 
	}
	q -= record_size;
	
	//Move pivot
	memcpy(temp_record, pivot, record_size);
	memcpy(pivot, buffer + q, record_size);
	memcpy(buffer + q, temp_record, record_size);
		
	//Divide and conquer
	free(temp_record);
	if(q) {
		int sched_success = 0;
		if(q > MIN_LEAF_SIZE) { sched_success = schedule(buffer, q, SORT_WINDOW); }
		if(!sched_success) { sort_buffer_parallel(buffer, q, record_size, key_size); }
	}
	if(q < buffer_size) {
		int sched_success = 0;
		if(q > MIN_LEAF_SIZE) { sched_success = schedule(buffer + q + record_size, buffer_size - q - record_size, SORT_WINDOW); }
		if(!sched_success) { sort_buffer_parallel(buffer + q + record_size, buffer_size - q - record_size, record_size, key_size); }
	}
}

//Sort a buffer in RAM
void sort_buffer_seq(char *buffer, size_t buffer_size, size_t record_size, size_t key_size)
{
	//Check if sorted
	if(buffer_is_sorted(buffer, buffer_size, record_size, key_size)) {
		return;
	}
	
	//Get pivot
	char *temp_record = malloc(record_size);
	size_t q = (prng()%(buffer_size/record_size))*record_size;
	char *pivot = buffer + q;
	q = 0;
	
	//Partition
	for(size_t i = 0; i < buffer_size; i += record_size) {
		char *record = buffer + i;
		int cmp = strncmp(record, pivot, key_size);
		if(cmp <= 0) {
			memcpy(temp_record, record, record_size);
			memcpy(record, buffer + q, record_size);
			memcpy(buffer + q, temp_record, record_size);
			if(cmp == 0) {
				pivot = buffer + q;
			}
			q += record_size;
		} 
	}
	q -= record_size;
	
	//Move pivot
	memcpy(temp_record, pivot, record_size);
	memcpy(pivot, buffer + q, record_size);
	memcpy(buffer + q, temp_record, record_size);
		
	//Divide and conquer
	free(temp_record);
	if(q) {
		sort_buffer_seq(buffer, q, record_size, key_size);
	}
	if(q < buffer_size) {
		sort_buffer_seq(buffer + q + record_size, buffer_size - q - record_size, record_size, key_size);
	}
}

//Check if chunk array is sorted
int chunks_are_sorted(CHUNK *chunks, int num_chunks)
{
	for(int i = 1; i < num_chunks; i++) {
		int cmp  = strncmp(chunks[i-1].max, chunks[i].min, KEY_SIZE); 
		if(cmp > 0) { 
			return 0;
		}
	} 
	return 1;
}

//Sort a chunk
void sort_window(char *buffer, size_t size)
{
	sort_buffer_parallel(buffer, size, RECORD_SIZE, KEY_SIZE);  
}

//Update window metadata after sort
void update_metadata(CHUNK *window, size_t window_size)
{
	for(size_t i = 0; i < window_size; i++) {
		CHUNK *c1 = window + i; 
		memcpy(c1->min, c1->slot->buffer, KEY_SIZE);
		memcpy(c1->max, c1->slot->buffer + c1->size - RECORD_SIZE, KEY_SIZE);
	}
}

//Sort data out-of-core
void parallel_sort(CHUNK *chunk_array, size_t num_chunks, size_t cache_size)
{
	size_t i = 0;
	
	//Check if last chunk is equal to chunk size
	size_t sort_num_chunks = num_chunks;
	if(chunk_array[num_chunks - 1].size != CHUNK_SIZE) {
		sort_num_chunks--; 
	}
	
	//Merge chunks until the file is sorted
	while(1) { 
		//Even sort
		i = 0;
		while(i < num_chunks) { 
			CHUNK *window = chunk_array + i;
			size_t load_count, load_size;
			load_window(window, num_chunks - i, &load_count, &load_size); 
			schedule(window->slot->buffer, load_size, SORT_WINDOW);  
			wait_for_all_workers();
			update_metadata(window, load_count);
			write_window(window, load_count);
			i += load_count; 
		} 
		if(chunks_are_sorted(chunk_array, num_chunks)) {
			break;
		}
		sort_buffer_seq((char*)chunk_array, sort_num_chunks*sizeof(CHUNK), sizeof(CHUNK), KEY_SIZE);
		printf("HERE1\n");
		
		//Odd sort
		i = cache_size/2;
		while(i < num_chunks) {
			CHUNK *window = chunk_array + i;
			size_t load_count, load_size;
			load_window(window, num_chunks - i, &load_count, &load_size);
			schedule(window->slot->buffer, load_size, SORT_WINDOW);  
			wait_for_all_workers();
			update_metadata(window, load_count);
			write_window(window, load_count);
			i += load_count; 
		}
		if(chunks_are_sorted(chunk_array, num_chunks)) {
			break;
		}
		sort_buffer_seq((char*)chunk_array, sort_num_chunks*sizeof(CHUNK), sizeof(CHUNK), KEY_SIZE);
		printf("HERE2\n"); 
	}
	printf("HERE3\n");
	
	//Write to storage in sorted order
	map_chunks(chunk_array, num_chunks);
	
	//Terminate workers
	terminate_workers();
}

int main(int argc, char **argv)
{
	if(argc < 4) {
		printf("USAGE: ./mysort [/path/to/file] [buffer_size] [num_threads]\n");
		exit(1);
	}
	
	//Command line arguments
	char *path = argv[1];
	size_t buffer_size = get_size(argv[2]);
	int num_threads = atoi(argv[3]);
	size_t file_size = get_file_size(path);
	
	//Define number of threads
	int num_worker_threads, num_io_threads;
	num_threads++;
	num_worker_threads = num_threads/2;
	num_io_threads = num_threads - num_worker_threads;
	
	//Allocate memory
	size_t num_chunks, cache_size;
	CHUNK *chunk_array = divide_file(file_size, buffer_size, num_threads, &num_chunks);
	init_chunk_cache(file_size, buffer_size, &cache_size);
	init_worker_pool(path, num_worker_threads);
	init_io_thread_pool(path, num_io_threads);
	
	//Sort
	parallel_sort(chunk_array, num_chunks, cache_size);
}
