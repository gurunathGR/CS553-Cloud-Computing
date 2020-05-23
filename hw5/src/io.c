
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

static WORKER_POOL WP;
static int terminate = 0;

void *io_thread(void *workerptr)
{
	WORKER *worker = workerptr; 
	FILE *fd = worker->fd; 
	
	pthread_mutex_lock(&worker->lock);
	worker->init = 1; 
	pthread_cond_signal(&worker->cond);
	pthread_mutex_unlock(&worker->lock);
	
	while(!terminate) {
		//Wait for operation
		pthread_mutex_lock(&worker->lock);
		while(worker->op == NO_OP) {
			pthread_cond_wait(&worker->cond, &worker->lock);
		}
		pthread_mutex_unlock(&worker->lock);
				
		//Execute operation
		switch(worker->op) {
			case READ_CHUNK: {
				fseek(fd, worker->off, SEEK_SET);
				size_t ret = fread(worker->buffer, worker->size, 1, fd); 
				io_finish(worker);
				break;
			}
			
			case WRITE_CHUNK: { 
				fseek(fd, worker->off, SEEK_SET);
				size_t ret = fwrite(worker->buffer, worker->size, 1, fd);
				fflush(fd);
				io_finish(worker);
				break;
			}
		}
	}
	
	return NULL;
}

void init_io_thread_pool(char *path, int num_threads)
{
	WP.workers = malloc(num_threads * sizeof(WORKER));
	pthread_mutex_init(&WP.lock, NULL);
	pthread_cond_init(&WP.cond, NULL);
	WP.num_workers = num_threads;
	WP.free_workers = num_threads;
	
	for(int i = 0; i < num_threads; i++) {
		WP.workers[i].fd = fopen(path, "r+b");
		if(WP.workers[i].fd == NULL) {
			printf("Can't find %s\n", path);
			perror("ERROR");
			exit(1);
		}
		WP.workers[i].init = 0;
		WP.workers[i].worker_id = i;
		WP.workers[i].op = NO_OP;
		pthread_mutex_init(&WP.workers[i].lock, NULL);
		pthread_cond_init(&WP.workers[i].cond, NULL); 
		pthread_mutex_lock(&WP.workers[i].lock);
		pthread_create(&WP.workers[i].tid, NULL, io_thread, (void*)&WP.workers[i]); 
		while(!WP.workers[i].init) {
			pthread_cond_wait(&WP.workers[i].cond, &WP.workers[i].lock);
		}
		pthread_mutex_unlock(&WP.workers[i].lock);
	}
}

void schedule_io(char *buffer, size_t size, size_t off, TASK *task, int op)
{
	pthread_mutex_lock(&WP.lock);
	
	//Wait for a worker to become available
	while(WP.free_workers == 0) {
		pthread_cond_wait(&WP.cond, &WP.lock);
	}
	
	//Allocate worker
	for(int i = 0; i < WP.num_workers; i++) {
		if(WP.workers[i].op == NO_OP) {
			WP.workers[i].buffer = buffer;
			WP.workers[i].size = size;
			WP.workers[i].off = off;
			WP.workers[i].task = task;
			WP.workers[i].op = op;
			pthread_mutex_lock(&WP.workers[i].lock);
			pthread_cond_signal(&WP.workers[i].cond);
			pthread_mutex_unlock(&WP.workers[i].lock);
			break;
		}
	}
	WP.free_workers--; 
	
	pthread_mutex_unlock(&WP.lock);
}

void io_read(char *buffer, size_t size, size_t off, TASK *task)
{
	start_task(task);
	schedule_io(buffer, size, off, task, READ_CHUNK);
}

void io_write(char *buffer, size_t size, size_t off, TASK *task)
{
	start_task(task);
	schedule_io(buffer, size, off, task, WRITE_CHUNK);
}

void wait_for_all_io(void)
{
	pthread_mutex_lock(&WP.lock);
	while(WP.free_workers != WP.num_workers) {
		pthread_cond_wait(&WP.cond, &WP.lock);
	}
	pthread_mutex_unlock(&WP.lock);
}

void io_finish(WORKER *worker)
{
	pthread_mutex_lock(&WP.lock);
	worker->op = NO_OP;
	WP.free_workers++;
	finish_task(worker->task);
	pthread_cond_signal(&WP.cond);
	pthread_mutex_unlock(&WP.lock); 
}

void terminate_io(void)
{
	terminate = 1;
}

void wait_for_io_term(void)
{
	for(int i = 0; i < WP.num_workers; i++) {
		pthread_join(WP.workers[i].tid, NULL);
	}
}

