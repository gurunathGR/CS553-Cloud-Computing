
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

static MM_CACHE cache;
size_t CHUNK_SIZE = MAX_CHUNK_SIZE;

//Divides a file into chunks, determines reasonable chunk size
CHUNK *divide_file(size_t file_size, size_t buffer_size, int num_threads, size_t *num_chunksp)
{
	if(buffer_size < MIN_BUFFER_SIZE) {
		printf("ERROR: The buffer must be at least %u bytes\n", MIN_BUFFER_SIZE);
		exit(1);
	}
	
	//Maximize chunk size
	if(CHUNK_SIZE > buffer_size) {
		CHUNK_SIZE = ALIGN(buffer_size, 100);
	}
	
	//If we have more than one chunk in the file, we'll have to external sort 
	size_t num_chunks = ceild(file_size, CHUNK_SIZE);
	if(num_chunks > 1 && buffer_size/CHUNK_SIZE < 4) {
		CHUNK_SIZE = buffer_size/4;
		CHUNK_SIZE = ALIGN(CHUNK_SIZE, 100);
		num_chunks = ceild(file_size, CHUNK_SIZE);
	}
	if(CHUNK_SIZE < MIN_BUFFER_SIZE) {
		printf("ERROR: Buffer can't be divided into 4 chunks\n");
		exit(1);
	}
	
	//Allocate chunk metadata
	CHUNK *chunk_array = malloc(num_chunks*sizeof(CHUNK));
	for(size_t i = 0; i < num_chunks; i++) {
		chunk_array[i] = (CHUNK) {
			.off = i*CHUNK_SIZE,
			.size = CHUNK_SIZE,
			.slot = NULL
		};
	}
	chunk_array[num_chunks - 1].size = file_size - CHUNK_SIZE*(num_chunks - 1);
	
	*num_chunksp = num_chunks;
	return chunk_array;
}

//Initialize the chunk cache
void init_chunk_cache(size_t file_size, size_t buffer_size, size_t *cache_sizep)
{
	size_t num_chunks = buffer_size / CHUNK_SIZE;
	cache.max_chunks = num_chunks;
	cache.last_pin = 0;
	cache.free_chunks = num_chunks;
	cache.empty_chunks = num_chunks;
	cache.slots = calloc(num_chunks, sizeof(MM_CACHE_SLOT));
	cache.buffer = malloc(buffer_size);
	
	for(size_t i = 0; i < cache.max_chunks; i++) {
		cache.slots[i].flags = 0;
		cache.slots[i].buffer = cache.buffer + i*CHUNK_SIZE;
		cache.slots[i].chunk =  NULL;
	}
	
	*cache_sizep = num_chunks;
}

//Add chunk to cache
void pin_chunk(CHUNK *chunk)
{
	if(chunk == NULL) {
		return;
	}
	if(cache.free_chunks == 0) {
		printf("ERROR: No free chunks\n");
		exit(1);
	}
	
	if(chunk->slot && chunk->slot->chunk == chunk) {
		if(chunk->slot->flags & IN_USE) {
			printf("ERROR: Can't pin same chunk twice\n");
			exit(1);
		}
		chunk->slot->flags |= IN_USE | IS_LOADED;
	}
	
	else if(cache.empty_chunks > 0) {
		for(size_t i = 0; i < cache.max_chunks; i++) {
			size_t idx = (i + cache.last_pin + 1) % cache.max_chunks;
			if(cache.slots[idx].chunk == 0) {
				cache.last_pin = idx;
				cache.slots[idx].chunk = chunk;
				cache.slots[idx].flags = IN_USE;
				chunk->slot = &cache.slots[idx];
				break;
			}
		}
		cache.empty_chunks--;
	}
	
	else {
		for(size_t i = 0; i < cache.max_chunks; i++) {
			size_t idx = (i + cache.last_pin + 1) % cache.max_chunks;
			if(!(cache.slots[idx].flags & IN_USE)) {
				cache.last_pin = idx;
				if(cache.slots[idx].flags & IS_DIRTY) {
					flush_chunk(cache.slots[idx].chunk);
					wait_for_all_io();
				}
				cache.slots[idx].chunk = chunk; 
				cache.slots[idx].flags = IN_USE;
				chunk->slot = &cache.slots[idx];
				break;
			}
		}
	}
	cache.free_chunks--; 
}

//Pin chunk to particular slot in cache
void pin_chunk_force(CHUNK *chunk, size_t idx)
{
	if(chunk == NULL) {
		return;
	}
	if(cache.free_chunks == 0) {
		printf("ERROR: No free chunks\n");
		exit(1);
	}
	if(cache.slots[idx].flags & IN_USE) {
		printf("ERROR: Can't pin same chunk twice\n");
		exit(1);
	}
	
	if(cache.slots[idx].chunk == 0) {
		cache.empty_chunks--;
	}
	cache.free_chunks--; 
	
	if(cache.slots[idx].chunk && (cache.slots[idx].flags & IS_DIRTY)) { 
		flush_chunk(cache.slots[idx].chunk);
		wait_for_all_io();
	}
	cache.last_pin = idx;
	cache.slots[idx].chunk = chunk; 
	cache.slots[idx].flags = IN_USE;
	chunk->slot = &cache.slots[idx];
}

//Remove chunk from cache
void unpin_chunk(CHUNK *chunk)
{
	chunk->slot->flags &= ~IN_USE;
	cache.free_chunks++; 
}

//Load a chunk into memory if it isn't already
void read_chunk(CHUNK *chunk)
{
	if(!(chunk->slot->flags & IS_LOADED)) {
		io_read(chunk->slot->buffer, chunk->size, chunk->off, NULL);
		chunk->slot->flags |= IS_LOADED;
	}
}

//Mark a chunk as dirty
void write_chunk(CHUNK *chunk)
{
	chunk->slot->flags |= IS_DIRTY;
}

//Flush a dirty chunk
void flush_chunk(CHUNK *chunk)
{
	if(!(chunk->slot->flags & IN_USE)) {
		return;
	}
	if(chunk->slot->flags & IS_DIRTY) {
		io_write(chunk->slot->buffer, chunk->size, chunk->off, NULL);
		chunk->slot->flags &= ~IS_DIRTY;
	}
}

//Flush the entire cache
void flush_cache(void)
{
	for(size_t i = 0; i < cache.max_chunks; i++) { 
		flush_chunk(cache.slots[i].chunk); 
	}
	wait_for_all_io();
}

//Load a contiguous window into cache
void load_window(CHUNK *chunk_array, size_t length, size_t *load_countp, size_t *load_sizep)
{
	if(length == 0) {
		*load_countp = 0;
		*load_sizep = 0;
		return;
	}
	
	wait_for_all_io();
	size_t load_count = cache.free_chunks <= length ? cache.free_chunks : length;
	size_t load_size = 0;
	for(size_t i = 0; i < load_count; i++) {
		CHUNK *chunk = chunk_array + i;
		pin_chunk_force(chunk, i);
		read_chunk(chunk);
		load_size += chunk->size; 
	}
	wait_for_all_io();
	
	*load_countp = load_count;
	*load_sizep = load_size;
}

//Commit cache to file
void write_window(CHUNK *chunk_array, size_t length)
{
	wait_for_all_io();
	for(size_t i = 0; i < length; i++) { 
		CHUNK *chunk = chunk_array + i;
		write_chunk(chunk);
		flush_chunk(chunk);
		unpin_chunk(chunk);
	}
	wait_for_all_io();
}

//Sort the chunks within the file itself
void map_chunks(CHUNK *sorted, size_t length)
{
	char *flags = calloc(length, 1);
	//Determine the original offset of the chunk at this position
	CHUNK *chunk_at_loc = calloc(length, sizeof(CHUNK));
	//Determine the current offset of a chunk from its original position
	CHUNK *whereis_chunk = calloc(length, sizeof(CHUNK));
	//The absolute chunk positions
	CHUNK *absolute = calloc(length, sizeof(CHUNK));
	for(size_t i = 0; i < length; i++) {
		chunk_at_loc[i].off = i*CHUNK_SIZE;
		chunk_at_loc[i].size = CHUNK_SIZE;
		whereis_chunk[i].off = i*CHUNK_SIZE;
		whereis_chunk[i].size = CHUNK_SIZE;
		absolute[i].off = i*CHUNK_SIZE;
		absolute[i].size = CHUNK_SIZE;
	}
	
	//Put chunks in sorted position
	for(size_t i = 0; i < length; i++) {
		//The data to move to sorted position
		size_t x_abs = sorted[i].off/CHUNK_SIZE; //Where x originally was
		size_t x_cur = whereis_chunk[x_abs].off/CHUNK_SIZE; //Where x currently is
		//The data currently at sorted position
		size_t y_abs = i; //Where x is going
		size_t y_cur = chunk_at_loc[i].off/CHUNK_SIZE; //What is at that position
		
		if(x_cur == y_abs) {
			continue;
		}
		
		//Read x and the data where x is going
		pin_chunk_force(absolute + x_cur, 0);
		pin_chunk_force(absolute + y_abs, 1);
		read_chunk(absolute + x_cur);
		read_chunk(absolute + y_abs);
		wait_for_all_io();
		
		//Swap offsets
		whereis_chunk[x_abs].off = y_abs*CHUNK_SIZE;
		whereis_chunk[y_cur].off = x_cur*CHUNK_SIZE;
		chunk_at_loc[y_abs].off = x_abs*CHUNK_SIZE;
		chunk_at_loc[x_cur].off = y_cur*CHUNK_SIZE;
		absolute[x_cur].off = whereis_chunk[x_abs].off;
		absolute[y_abs].off = whereis_chunk[y_cur].off;
		
		//Commit
		write_chunk(absolute + x_cur);
		write_chunk(absolute + y_abs);
		flush_chunk(absolute + x_cur);
		flush_chunk(absolute + y_abs);
		unpin_chunk(absolute + x_cur);
		unpin_chunk(absolute + y_abs);
		wait_for_all_io();
		
		//Make positions absolute again
		absolute[y_abs].off = whereis_chunk[x_abs].off;
		absolute[x_cur].off = whereis_chunk[y_cur].off;
	}
	/*printf("\n");
	for(size_t i = 0; i < length; i++) {
		size_t x = sorted[i].off/CHUNK_SIZE;
		printf("%lu\n", whereis_chunk[x].off/CHUNK_SIZE);
	}*/
}

