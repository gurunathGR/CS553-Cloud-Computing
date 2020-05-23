
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

void init_task(TASK *task)
{
	if(task == NULL) {
		return;
	}
	
	task->done = 1;
	pthread_mutex_init(&task->lock, NULL);
	pthread_cond_init(&task->cond, NULL);
}

void start_task(TASK *task)
{
	if(task == NULL) {
		return;
	}
	
	task->done = 0;
}

void wait_for_task(TASK *task)
{
	if(task == NULL) {
		return;
	}
	
	pthread_mutex_lock(&task->lock);
	while(!task->done) {
		pthread_cond_wait(&task->cond, &task->lock);
	}
	pthread_mutex_unlock(&task->lock);
}

void finish_task(TASK *task)
{
	if(task == NULL) {
		return;
	}
	
	pthread_mutex_lock(&task->lock);
	task->done = 1;
	pthread_cond_signal(&task->cond);
	pthread_mutex_unlock(&task->lock);
}
