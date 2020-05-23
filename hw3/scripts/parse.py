
import sys, os
import re
import json
import glob
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

fn_pattern = re.compile("^([a-zA-Z]+)_bench_([0-9.]+)([kmg])_([0-9.]+)([kmg])([0-9]+)")
mdb_pattern = re.compile("^TIMER: \(workload=([0-9.]+), throughput=([0-9.]+), iops=([0-9.]+)\)")
iozone_write_seq = re.compile ("^\"\s+Initial write\s+\"\s+([0-9.]+)")
iozone_write_rand = re.compile("^\"\s+Random write\s+\"\s+([0-9.]+)")
iozone_read_seq = re.compile  ("^\"\s+Read\s+\"\s+([0-9.]+)")
iozone_read_rand = re.compile ("^\"\s+Random read\s+\"\s+([0-9.]+)")

tab_type_1 = {
	"col_names": ["workload", "num_files", "record_size", "mdb_mbps", "iozone_mbps", "theoretical_mbps", "mdb_efficiency_mbps", "iozone_efficiency_mbps"],
	"pretty_col_names": {
		"workload": "Workload", 
		"num_files" : "Concurrency",
		"record_size": "Record Size",
		"mdb_mbps": "MyDiskBench Measured Throughput (MB/sec)",
		"iozone_mbps": "IOZone Measured Throughput (MB/sec)",
		"theoretical_mbps": "Theoretical Throughput (MB/sec)",
		"mdb_efficiency_mbps": "MyDiskBench Efficiency (%)",
		"iozone_efficiency_mbps": "IOZone Efficiency (%)",
	}
}

tab_type_2 = {
	"col_names": ["workload", "num_files", "record_size", "mdb_iops", "iozone_iops", "theoretical_iops", "mdb_efficiency_iops", "iozone_efficiency_iops"],
	"pretty_col_names": { 
		"workload": "Workload", 
		"num_files" : "Concurrency",
		"record_size": "Record Size",
		"mdb_iops": "MyDiskBench Measured Throughput (OPS/sec)",
		"iozone_iops": "IOZone Measured Throughput (OPS/sec)",
		"theoretical_iops": "Theoretical Throughput (OPS/sec)",
		"mdb_efficiency_iops": "MyDiskBench Efficiency (%)",
		"iozone_efficiency_iops": "IOZone Efficiency (%)",
	}
}

id_to_workload = {
	0: "WS",
	1: "WR",
	2: "RS",
	3: "RR"
}

def get_size(count, unit):
	if unit=="k":
		count = count*(1<<10)
	elif unit=="m":
		count = count*(1<<20)
	elif unit=="g":
		count = count*(1<<30)
	
	return count

def parse_log(path):
	filename = os.path.basename(TEST_PATH) 
	match = fn_pattern.match(filename)
	if match: 
		prog = match.group(1) 
		record_size = get_size(float(match.group(2)), match.group(3))
		file_size = get_size(float(match.group(4)), match.group(5))
		num_files = int(match.group(6))
		return (prog, file_size, record_size, num_files)
	else:
		return (None, None, None, None)

def parse_mdb(path, file_size, record_size, num_files):
	with open(path, "r") as fp:
		lines = fp.readlines()
	df = []
	for line in lines:
		match = mdb_pattern.match(line)
		if match:
			
			mdb_mbps = float(match.group(2))
			mdb_iops = float(match.group(3))
			
			df.append({
				"file_size": file_size,
				"record_size": record_size,
				"num_files": num_files,
				"workload": id_to_workload[int(match.group(1))],
				"mdb_mbps": mdb_mbps,
				"mdb_iops": mdb_iops,
				"theoretical_mbps": 510,
				"theoretical_iops": 90000,
				"mdb_efficiency_mbps": (mdb_mbps/510)*100,
				"mdb_efficiency_iops": (mdb_iops/90000)*100
			})
	
	return df

def parse_iozone(path, file_size, record_size, num_files):
	with open(path, "r") as fp:
		lines = fp.readlines()
	df = []
	for line in lines:
		ws = iozone_write_seq.match(line)
		wr = iozone_write_rand.match(line)
		rs = iozone_read_seq.match(line)
		rr = iozone_read_rand.match(line)
		
		if ws:
			workload="WS"
			match=ws
		elif wr:
			workload="WR"
			match=wr
		elif rs:
			workload="RS"
			match=rs
		elif rr:
			workload="RR"
			match=rr
		else:
			continue
		
		iozone_iops = float(match.group(1))
		iozone_mbps = float(match.group(1))*(record_size/(1<<20))
		
		df.append({
			"file_size": file_size,
			"record_size": record_size,
			"num_files": num_files,
			"workload": workload,
			"iozone_iops": iozone_iops,
			"iozone_mbps": iozone_mbps,
			"theoretical_mbps": 510,
			"theoretical_iops": 90000,
			"iozone_efficiency_mbps": (iozone_mbps/510)*100,
			"iozone_efficiency_iops": (iozone_iops/90000)*100
		})
	
	return df

#Throughput/Efficiency vs Thread Count
#Throughput vs Record Size
def mean_std_graph(df, LINE_SPLIT, LINE_KEY, X, MEAN_Y, STD_Y, xlab, ylab, title, out_dir, fn):
	lines = df[LINE_SPLIT].drop_duplicates()
	colors = ["blue", "orange", "green", "purple"]
	
	plt.clf()
	for line in lines:
		color = colors.pop(0)
		
		line_df = df[df[LINE_SPLIT] == line].sort_values(X)
		x = line_df[X]
		mean_y = line_df[MEAN_Y[0]]
		std_y = line_df[STD_Y[0]]
		p = plt.errorbar(x, mean_y, std_y, marker='o', color=color, label="{} = {}".format(LINE_KEY, line)) 
		
		line_df = df[df[LINE_SPLIT] == line].sort_values(X)
		x = line_df[X]
		mean_y = line_df[MEAN_Y[1]]
		std_y = line_df[STD_Y[1]]
		plt.errorbar(x, mean_y, std_y, linestyle=":", marker='^', color=color)
		
	plt.title(title)
	plt.xlabel(xlab)
	plt.ylabel(ylab)
	plt.legend(bbox_to_anchor=(1.04,1), loc="upper left")
	plt.savefig(os.path.join(out_dir, fn), bbox_inches="tight")
	plt.close()

#######COMMAND LINE ARGS
if len(sys.argv) != 2:
	print("Usage: python3 parse.py [RES_DIR]")
	print("[RES_DIR]: The directory with the parse data")
	sys.exit(1)
RES_DIR = sys.argv[1]
TABLE_DIR = os.path.join(RES_DIR, "tables")
FIG_DIR = os.path.join(RES_DIR, "fig")

#Convert result logs into pandas dataframes
mdb_df = []
iozone_df = []
TEST_PATHS = glob.glob(os.path.join(RES_DIR, "*.txt"))
for TEST_PATH in TEST_PATHS:
	(prog, file_size, record_size, num_files) = parse_log(TEST_PATH) 
	if prog == "mdb":
		mdb_df += parse_mdb(TEST_PATH, file_size, record_size, num_files)
	elif prog == "iozone":
		iozone_df += parse_iozone(TEST_PATH, file_size, record_size, num_files) 
mdb_df = pd.DataFrame(mdb_df) 
iozone_df = pd.DataFrame(iozone_df)

#Compute average and standard deviation
mdb_df_mean = mdb_df.groupby(by=["workload", "record_size", "file_size", "num_files", "theoretical_mbps", "theoretical_iops"]).mean().reset_index()
mdb_df_std = mdb_df.groupby(by=["workload", "record_size", "file_size", "num_files", "theoretical_mbps", "theoretical_iops"]).std().reset_index()
mdb_df_std = mdb_df_std.rename(columns={
	"mdb_mbps": "mdb_std_mbps", 
	"mdb_iops": "mdb_std_iops", 
	"mdb_efficiency_mbps" : "mdb_efficiency_std_mbps", 
	"mdb_efficiency_iops": "mdb_efficiency_std_iops"
})
mdb_df =pd.merge(mdb_df_mean, mdb_df_std, on=None, how="outer")

#Compute average and standard deviation
iozone_df_mean = iozone_df.groupby(by=["workload", "record_size", "file_size", "num_files", "theoretical_mbps", "theoretical_iops"]).mean().reset_index()
iozone_df_std = iozone_df.groupby(by=["workload", "record_size", "file_size", "num_files", "theoretical_mbps", "theoretical_iops"]).std().reset_index()
iozone_df_std = iozone_df_std.rename(columns={
	"iozone_mbps": "iozone_std_mbps", 
	"iozone_iops": "iozone_std_iops", 
	"iozone_efficiency_mbps" : "iozone_efficiency_std_mbps", 
	"iozone_efficiency_iops": "iozone_efficiency_std_iops"
})
iozone_df =pd.merge(iozone_df_mean, iozone_df_std, on=None, how="outer")

#Merge the two dataframes based off of workload, block size, and file size, etc
df = pd.merge(iozone_df, mdb_df, on=["workload", "record_size", "file_size", "num_files", "theoretical_mbps", "theoretical_iops"]) 

#Save 6 dataframes
tab1 = df[(df["workload"]=="RS") & (df["record_size"] > 4096)]
tab2 = df[(df["workload"]=="RR") & (df["record_size"] > 4096)]
tab3 = df[(df["workload"]=="WS") & (df["record_size"] > 4096)]
tab4 = df[(df["workload"]=="WR") & (df["record_size"] > 4096)]
tab5 = df[(df["workload"]=="RR") & (df["record_size"] == 4096)]
tab6 = df[(df["workload"]=="WR") & (df["record_size"] == 4096)]

#Throughput MBPS
ys = [("mdb_mbps", "iozone_mbps"), ("mdb_std_mbps", "iozone_std_mbps")]
mean_std_graph(tab1, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Throughput (MBps)", "Throughput vs Thread Count", FIG_DIR, "rs-mbps-vs-threads.png")
mean_std_graph(tab2, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Throughput (MBps)", "Throughput vs Thread Count", FIG_DIR, "rr-mbps-vs-threads.png")
mean_std_graph(tab3, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Throughput (MBps)", "Throughput vs Thread Count", FIG_DIR, "ws-mbps-vs-threads.png")
mean_std_graph(tab4, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Throughput (MBps)", "Throughput vs Thread Count", FIG_DIR, "wr-mbps-vs-threads.png")

#Throughput MBPS Efficiency
ys = [("mdb_efficiency_mbps", "iozone_efficiency_mbps"), ("mdb_efficiency_std_mbps", "iozone_efficiency_std_mbps")]
mean_std_graph(tab1, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Efficiency (%)", "Efficiency vs Thread Count", FIG_DIR, "rs-eff-mbps-vs-threads.png")
mean_std_graph(tab2, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Efficiency (%)", "Efficiency vs Thread Count", FIG_DIR, "rr-eff-mbps-vs-threads.png")
mean_std_graph(tab3, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Efficiency (%)", "Efficiency vs Thread Count", FIG_DIR, "ws-eff-mbps-vs-threads.png")
mean_std_graph(tab4, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Efficiency (%)", "Efficiency vs Thread Count", FIG_DIR, "wr-eff-mbps-vs-threads.png")

#Latency IOPS
ys = [("mdb_iops", "iozone_iops"), ("mdb_std_iops", "iozone_std_iops")]
mean_std_graph(tab5, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Throughput (IOPS)", "Throughput vs Thread Count", FIG_DIR, "rr-iops-vs-threads.png")
mean_std_graph(tab6, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Throughput (IOPS)", "Throughput vs Thread Count", FIG_DIR, "wr-iops-vs-threads.png")

#Latency IOPS Efficiency
ys = [("mdb_efficiency_iops", "iozone_efficiency_iops"), ("mdb_efficiency_std_iops", "iozone_efficiency_std_iops")]
mean_std_graph(tab5, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Efficiency (%)", "Efficiency vs Thread Count", FIG_DIR, "rr-eff-iops-vs-threads.png")
mean_std_graph(tab6, "record_size", "Record Size", "num_files", ys[0], ys[1], "Thread Count", "Efficiency (%)", "Efficiency vs Thread Count", FIG_DIR, "wr-eff-iops-vs-threads.png")

#Prettify Numbers

#Save 6 dataframes
tab1[tab_type_1["col_names"]].rename(columns=tab_type_1["pretty_col_names"]).round(decimals=2).to_csv(os.path.join(TABLE_DIR, "read-seq-mbps.csv"), index=False)
tab2[tab_type_1["col_names"]].rename(columns=tab_type_1["pretty_col_names"]).round(decimals=2).to_csv(os.path.join(TABLE_DIR, "read-rand-mbps.csv"), index=False)
tab3[tab_type_1["col_names"]].rename(columns=tab_type_1["pretty_col_names"]).round(decimals=2).to_csv(os.path.join(TABLE_DIR, "write-seq-mbps.csv"), index=False)
tab4[tab_type_1["col_names"]].rename(columns=tab_type_1["pretty_col_names"]).round(decimals=2).to_csv(os.path.join(TABLE_DIR, "write-rand-mbps.csv"), index=False)
tab5[tab_type_2["col_names"]].rename(columns=tab_type_2["pretty_col_names"]).round(decimals=2).to_csv(os.path.join(TABLE_DIR, "latency-read-rand-iops.csv"), index=False)
tab6[tab_type_2["col_names"]].rename(columns=tab_type_2["pretty_col_names"]).round(decimals=2).to_csv(os.path.join(TABLE_DIR, "latency-write-rand-iops.csv"), index=False)

