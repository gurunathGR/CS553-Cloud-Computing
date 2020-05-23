
"""
Extract %CPU, %MEM, kB_rd/s, kB_wr/s
"""

import sys, os
import re
import json
import glob
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

row = re.compile("^[^#]" + "([^\s]+)\s+"*19) 
time_row = re.compile("^real\s+([0-9.]+)m([0-9.]+)") 

def get_size(count, unit):
	if unit=="k":
		count = count*(1<<10)
	elif unit=="m":
		count = count*(1<<20)
	elif unit=="g":
		count = count*(1<<30)
	
	return count

def parse_log(path, app, file_size, num_threads, sort_approach, sort_algo, ram):
	with open(path, "r") as fp:
		lines = fp.readlines()
	
	timestamp = 0
	time = None
	df = []
	for line in lines:
		match = row.match(line) 
		if match: 
			cpu_util = float(match.group(8))
			mem_util = float(match.group(14))
			kb_rd = float(match.group(15))
			kb_wr = float(match.group(16))
			
			df.append({
				"app": app,
				"file_size": file_size,
				"timestamp": timestamp,
				"cpu_util": cpu_util,
				"mem_util": mem_util,
				"gb_mem": mem_util*ram/100,
				"gb_read": kb_rd/1000000,
				"gb_written": kb_wr/1000000,
				"num_threads": num_threads,
				"sort_approach": sort_approach,
				"sort_algo": sort_algo,
				"total_time": None
			})
			
			timestamp += 1
		else:
			match = time_row.match(line)
			if match:
				time = 60*float(match.group(1)) + float(match.group(2))
	
	if time is None:
		print("Error: time not found in logs " + path)
		sys.exit(1)
	if len(df) == 0:
		print("Error: no logs parsed for " + path)
		sys.exit(1)
	
	df = pd.DataFrame(df)
	df["total_time"] = time 
	return df

def draw_utilization(df, app, file_size, title, out_dir, fn):
	
	df = df[(df["app"] == app) & (df["file_size"] == file_size)]
	df = df.sort_values("timestamp")
	plt.clf()
	
	fig,ax=plt.subplots()
	ax.plot(df["timestamp"], df["cpu_util"], label="CPU Utilization", color="green")
	ax.set_xlabel("Time (s)", fontsize=14)
	ax.set_ylabel("Utilization (%)", color="red", fontsize=14)
		
	ax2=ax.twinx()
	ax2.plot(df["timestamp"], df["gb_mem"], label="RAM Usage", color="black")
	ax2.plot(df["timestamp"], df["gb_read"] + df["gb_written"], label="Disk Usage", color="orange")
	ax2.set_ylabel("Usage (GB)", color="blue", fontsize=14)
	
	handles, labels = ax.get_legend_handles_labels()
	handles2, labels2 = ax2.get_legend_handles_labels()
	handles += handles2
	labels += labels2
	fig.legend(handles, labels, bbox_to_anchor=(1.02,1), loc="upper left")
	
	plt.title(title)
	#plt.legend(bbox_to_anchor=(1.04,1), loc="upper left")
	plt.savefig(os.path.join(out_dir, fn), bbox_inches="tight")
	plt.close()

def create_tables(df, out_dir):
	avg = df[["app", "file_size", "gb_mem", "cpu_util"]].groupby(by=["app", "file_size"]).mean().reset_index()
	net = df[["app", "file_size", "gb_read", "gb_written"]].groupby(by=["app", "file_size"]).sum().reset_index()
	unchanged = df[["app", "file_size", "num_threads", "total_time", "sort_algo", "sort_approach"]].drop_duplicates()
	df = pd.merge(avg, net, on=None, how="outer")
	df = pd.merge(df, unchanged, on=None, how="outer")
	df["io_thrpt"] = 1000*(df["gb_read"] + df["gb_written"])/df["total_time"]
	df["gb_mem"] = df["gb_mem"].round(2)
	df["cpu_util"] = df["cpu_util"].round(2)
	df["gb_read"] = df["gb_read"].round(2)
	df["gb_written"] = df["gb_written"].round(2) 
	df.set_index(["app", "file_size"], inplace=True)
	df = df.transpose() 
	df.to_csv(os.path.join(out_dir, "table.csv"), index=True)

#######COMMAND LINE ARGS
if len(sys.argv) != 2:
	print("Usage: python3 parse.py [RES_DIR]")
	print("[RES_DIR]: The directory with the parse data")
	sys.exit(1)
RES_DIR = sys.argv[1]

#Convert result logs into pandas dataframes
df = parse_log(os.path.join(RES_DIR, "mysort1GB.log"), "mysort", 1, 16, "in_memory", "quicksort", 192)
df = pd.concat([df, parse_log(os.path.join(RES_DIR, "linsort1GB.log"), "linsort", 1, 16, "in_memory", "mergesort", 192)])
df = pd.concat([df, parse_log(os.path.join(RES_DIR, "mysort4GB.log"), "mysort", 4, 16, "in_memory", "quicksort", 192)])
df = pd.concat([df, parse_log(os.path.join(RES_DIR, "linsort4GB.log"), "linsort", 4, 16, "in_memory", "mergesort", 192)])
df = pd.concat([df, parse_log(os.path.join(RES_DIR, "mysort16GB.log"), "mysort", 16, 16, "external", "quicksort", 192)])
df = pd.concat([df, parse_log(os.path.join(RES_DIR, "linsort16GB.log"), "linsort", 16, 16, "external", "mergesort", 192)])
df = pd.concat([df, parse_log(os.path.join(RES_DIR, "mysort64GB.log"), "mysort", 64, 16, "external", "quicksort", 192)])
df = pd.concat([df, parse_log(os.path.join(RES_DIR, "linsort64GB.log"), "linsort", 64, 16, "external", "mergesort", 192)])

#Draw memory/cpu/disk utilization over time
#draw_utilization(df, "mysort", 64, "MySort Resource Consumption over Time", RES_DIR, "mysort-consumption.png")
#draw_utilization(df, "linsort", 64, "LinSort Resource Consumption over Time", RES_DIR, "linsort-consumption.png")

#Create the output table
create_tables(df, RES_DIR)
