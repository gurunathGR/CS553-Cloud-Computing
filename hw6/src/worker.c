
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

void *worker_thread(void *workerptr)
{
	WORKER *worker = workerptr; 
	
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
			case SORT_WINDOW: {
				sort_window(worker->buffer, worker->size);
				finish(worker);
				break;
			}
		}
	}
	
	return NULL;
}

void init_worker_pool(char *path, int num_threads)
{
	WP.workers = malloc(num_threads * sizeof(WORKER));
	pthread_mutex_init(&WP.lock, NULL);
	pthread_cond_init(&WP.cond, NULL);
	WP.num_workers = num_threads;
	WP.free_workers = num_threads;
	
	for(int i = 0; i < num_threads; i++) {
		WP.workers[i].fd = NULL;
		WP.workers[i].init = 0;
		WP.workers[i].worker_id = i;
		WP.workers[i].op = NO_OP;
		pthread_mutex_init(&WP.workers[i].lock, NULL);
		pthread_cond_init(&WP.workers[i].cond, NULL); 
		pthread_mutex_lock(&WP.workers[i].lock);
		pthread_create(&WP.workers[i].tid, NULL, worker_thread, (void*)&WP.workers[i]); 
		while(!WP.workers[i].init) {
			pthread_cond_wait(&WP.workers[i].cond, &WP.workers[i].lock);
		}
		pthread_mutex_unlock(&WP.workers[i].lock);
	}
}

int schedule(char *buffer, size_t size, int op)
{	
	pthread_mutex_lock(&WP.lock);
	
	//Wait for a worker to become available
	if(WP.free_workers == 0) {
		pthread_mutex_unlock(&WP.lock);
		return 0;
		//pthread_cond_wait(&WP.cond, &WP.lock);
	}
	
	//Allocate worker
	for(int i = 0; i < WP.num_workers; i++) {
		if(WP.workers[i].op == NO_OP) {
			WP.workers[i].buffer = buffer;
			WP.workers[i].size = size;
			WP.workers[i].op = op;
			pthread_mutex_lock(&WP.workers[i].lock);
			pthread_cond_signal(&WP.workers[i].cond);
			pthread_mutex_unlock(&WP.workers[i].lock);
			break;
		}
	}
	WP.free_workers--; 
	
	pthread_mutex_unlock(&WP.lock);
	
	return 1;
}

void finish(WORKER *worker)
{
	pthread_mutex_lock(&WP.lock);
	worker->op = NO_OP;
	WP.free_workers++;
	pthread_cond_signal(&WP.cond);
	pthread_mutex_unlock(&WP.lock);
}

void wait_for_all_workers(void)
{
	pthread_mutex_lock(&WP.lock);
	while(WP.free_workers != WP.num_workers) {
		pthread_cond_wait(&WP.cond, &WP.lock);
	}
	pthread_mutex_unlock(&WP.lock);
}

void terminate_workers(void)
{
	terminate = 1;
}

void wait_for_worker_term(void)
{
	for(int i = 0; i < WP.num_workers; i++) {
		pthread_join(WP.workers[i].tid, NULL);
	}
}
