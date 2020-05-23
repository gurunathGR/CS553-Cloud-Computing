
"""
05:44:51        CPU     %user     %nice   %system   %iowait    %steal     %idle
05:44:52        all      0.08      0.00      0.08      0.00      0.00     99.83

05:44:51          tps      rtps      wtps   bread/s   bwrtn/s
05:44:52         0.00      0.00      0.00      0.00      0.00

05:44:51    kbmemfree   kbavail kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty
05:44:52       756192 143468900 195845732     99.62     54296 140585208  51673920     26.28 159631856  30826936       676

"""

import sys, os
import re
import json
import glob
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

def parse_log(path):
	with open(path, "r") as fp:
		lines = fp.readlines()
	
	df = []
	idx = 0
	time = 0
	while idx < len(lines):
		cpu_row = lines[idx+1]
		disk_row = lines[idx+4]
		mem_row = lines[idx+7]
		
		cpu_match = cpu_row.split()
		disk_match = disk_row.split()
		mem_match = mem_row.split()
		
		if cpu_match is None:
			print("CPU MATCH NULL")
			sys.exit()
		if disk_match is None:
			print("DISK MATCH NULL")
			sys.exit()
		if mem_match is None:
			print("MEM MATCH NULL")
			sys.exit()
		
		cpu_util = float(cpu_match[2])
		mb_read = float(disk_match[4])*512/1000000
		mb_wrtn = float(disk_match[5])*512/1000000
		mem_util = float(mem_match[4]) 
		
		df.append({
			"timestamp": time,
			"mb_total": mb_read + mb_wrtn,
			"%mem": mem_util,
			"%cpu": cpu_util, 
		})
		
		idx += 9
		time += 1
	
	return pd.DataFrame(df)

def draw_utilization(df, title, out_dir, fn):
	
	df = df.sort_values("timestamp")
	plt.clf()
	
	fig,ax=plt.subplots()
	ax.plot(df["timestamp"], df["%cpu"], label="CPU Utilization", color="green")
	ax.plot(df["timestamp"], df["%mem"], label="RAM Usage", color="black")
	ax.set_xlabel("Time (s)", fontsize=14)
	ax.set_ylabel("Utilization (%)", color="red", fontsize=14)
		
	ax2=ax.twinx()
	ax2.plot(df["timestamp"], df["mb_total"], label="Disk Usage", color="orange")
	ax2.set_ylabel("Usage (MB)", color="blue", fontsize=14)
	
	handles, labels = ax.get_legend_handles_labels()
	handles2, labels2 = ax2.get_legend_handles_labels()
	handles += handles2
	labels += labels2
	#fig.legend(handles, labels, bbox_to_anchor=(1.02,1), loc="upper left")
	
	plt.title(title)
	#plt.legend(bbox_to_anchor=(1.04,1), loc="upper left")
	plt.savefig(os.path.join(out_dir, fn), bbox_inches="tight")
	plt.close()

#######COMMAND LINE ARGS
if len(sys.argv) != 2:
	print("Usage: python3 parse.py [RES_DIR]")
	print("[RES_DIR]: The directory with the parse data")
	sys.exit(1)
RES_DIR = os.path.join(sys.argv[1], "tables") 

#Parse logs
mysort1L = parse_log(os.path.join(RES_DIR, "mysort32G-1L-sar.log"))
linsort1L = parse_log(os.path.join(RES_DIR, "linsort32G-1L-sar.log"))
spark1L = parse_log(os.path.join(RES_DIR, "sparksort32G-1L-sar.log"))
hadoop1L = parse_log(os.path.join(RES_DIR, "hadoopsort32G-1L-sar.log"))
spark4S = parse_log(os.path.join(RES_DIR, "sparksort16G-4S-sar.log"))
hadoop4S = parse_log(os.path.join(RES_DIR, "hadoopsort16G-4S-sar.log"))

#Draw memory/cpu/disk utilization over time
draw_utilization(mysort1L, "MySort32G-1L", RES_DIR, "mysort32G-1L-consumption.png") 
draw_utilization(linsort1L, "LinSort32G-1L", RES_DIR, "linsort32G-1L-consumption.png") 
draw_utilization(hadoop1L, "HadoopSort32G-1L", RES_DIR, "hadoopsort32G-1L-consumption.png") 
draw_utilization(spark1L, "SparkSort32G-1L", RES_DIR, "sparksort32G-1L-consumption.png") 
draw_utilization(hadoop4S, "HadoopSort16G-4S", RES_DIR, "hadoopsort16G-4S-consumption.png") 
draw_utilization(spark4S, "SparkSort16G-4S", RES_DIR, "sparksort16G-4S-consumption.png") 

