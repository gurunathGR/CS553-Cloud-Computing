
#We assume a 3-level fat tree topology
import math, numpy as np
import sys
import json
import pandas as pd

K = 1000
M = K*1000
G = M*1000
T = G*1000
P = T*1000
EX = 1000*P

KB = 1000
MB = 1000*KB
GB = 1000*MB
TB = 1000*GB
PB = 1000*TB

MBPS = MB
GBPS = GB
TBPS = TB 

w_to_kw = 1/1000

nodes = {

	"dummy": {
		"ram": np.inf,
		"hdd": np.inf,
		"num_hdd": np.inf,
		"thrpt": np.inf,
		"num_cores": np.inf,
		"power": 0,
		"cost": 0,
		"rack_unit": 0,
	}, 

	#RAX XS4-21S1-10G
	"p1-compute-config": {
		"ram": 384*GB,
		"hdd": 16*TB,
		"num_hdd": 4,
		"thrpt": 120*MBPS,
		"num_cores": 40,
		"power": 426.4*w_to_kw,
		"cost": 10359,
		"rack_unit": 1,
	},
	
	#STX-NS XE36-24S1-10G
	"p1-storage-config": {
		"ram": 32*GB,
		"hdd": 16*TB,
		"num_hdd": 36,
		"thrpt": 120*MBPS,
		"num_cores": 8,
		"power": 684.3*w_to_kw,
		"cost": 24414,
		"rack_unit": 4,
	},
	
	#RAX QS12-22E2
	"p2-compute-config": {
		"ram": 1*TB,
		"hdd": 5*TB,
		"num_hdd": 1,
		"thrpt": 600*MBPS,
		"num_cores": 128,
		"power": 793.5*w_to_kw,
		"cost": 35966,
		"rack_unit": 1,
	},
	
	#STX-NS XE36-24S1-10G
	"p2-storage-config": {
		"ram": 32*GB,
		"hdd": 16*TB,
		"num_hdd": 36,
		"thrpt": 120*MBPS,
		"num_cores": 8,
		"power": 682.7*w_to_kw,
		"cost": 24439,
		"rack_unit": 4,
	}, 
	
	#GPX QT8-12E2-8GPU
	"p3-compute-config": {
		"ram": 512*GB,
		"hdd": 1*TB,
		"num_hdd": 1,
		"thrpt": 120*MBPS,
		"num_cores": 64,
		"power": 2310*w_to_kw,
		"cost": 80698,
		"rack_unit": 2,
		"flops": 8*7*T,
	},
	
	#STX-NS XE36-24S1-10G
	"p3-storage-config": {
		"ram": 32*GB,
		"hdd": 16*TB,
		"num_hdd": 36,
		"thrpt": 120*MBPS,
		"num_cores": 8,
		"power": 691.5*w_to_kw,
		"cost": 24351,
		"rack_unit": 4,
	}, 
	
	#Amazon EC2
	"p1-amazon-compute-config": {
		"ram": 244*GB,
		"hdd": 2*TB,
		"num_hdd": 24,
		"thrpt": 120*MBPS,
		"num_cores": 36,
		"power": 0,
		"cost": 4034.1,
		"rack_unit": 0,
	}, 
}

switch = {
	"25gbps": {
		"ports": 48,
		"cost": 6200,
	},
	
	"10gbps": {
		"ports": 48,
		"cost": 3600,
	}
}

link = {
	"25gbps": {
		"cost": 78
	},
	"10gbps": {
		"cost": 78
	},
}

rack = {
	"units": 42,
	"cost": 992.99,
	"area": (23.6/12) * (43/12),
}

def get_num_nodes(config, total_num_cores, total_ram, total_hdd, total_thrpt):
	
	#Minimum number of nodes to satisfy constraints
	min_nodes = [0, 0, 0, 0]
	if config["num_cores"]: min_nodes[0] = math.ceil(total_num_cores/config["num_cores"])
	if config["ram"]: min_nodes[1] = math.ceil(total_ram/config["ram"])
	if config["hdd"] and config["num_hdd"]: min_nodes[2] = math.ceil(total_hdd/(config["hdd"]*config["num_hdd"])) 
	if config["thrpt"] and config["num_hdd"]: min_nodes[3] = math.ceil(total_thrpt/(config["thrpt"]*config["num_hdd"]))
	num_nodes = max(min_nodes)
	
	return (min_nodes, num_nodes)

def get_num_switches(switch, num_nodes):
	
	#Total number of switches and network links
	k = switch["ports"] 
	N = num_nodes
	Ns = k/2
	Np = math.ceil(N/(Ns * k/2))
	Ne = Np * Ns
	Na = Ne
	Nc = math.ceil(Ns * (k/2)/(k/Np))
	num_switches = Ne + Na + Nc
	num_links = k*num_switches
	
	return (num_switches, num_links)

def get_server_cost(config, rack, switch, link, num_nodes, num_switches, num_links, num_admins, num_racks, cool_kw):
	total_node_cost = num_nodes*config["cost"]
	total_rack_cost = num_racks*rack["cost"]
	total_power_cost = num_nodes*config["power"]*.083*24*365*5
	total_switch_cost = num_switches*switch["cost"]
	total_link_cost = num_links*link["cost"]
	total_cool_cost = cool_kw*.083*24*365*5
	total_admin_cost = num_admins * 59323
	total_cost = total_node_cost + total_rack_cost + total_power_cost + total_switch_cost + total_link_cost + total_cool_cost + total_admin_cost
	
	return {
		"num_nodes": num_nodes,
		"num_links": num_links,
		"num_switches": num_switches,
		"num_admins": num_admins,
		"num_racks": num_racks,
		"cool_kw": cool_kw,
		"server_kw": num_nodes*config["power"],
		"time_hrs": 24*365*5,
		
		"node_cost": config["cost"],
		"rack_cost": rack["cost"],
		"rack_area": rack["area"],
		"power_cost": .083,
		"switch_cost": switch["cost"],
		"link_cost": link["cost"],
		"admin_cost": 59323,
		"cool_cost": .083,
		
		"total_node_cost": total_node_cost,
		"total_rack_cost": total_rack_cost,
		"total_power_cost": total_power_cost,
		"total_switch_cost": total_switch_cost,
		"total_link_cost": total_link_cost,
		"total_cool_cost": total_cool_cost,
		"total_admin_cost": total_admin_cost,
		"total_cost": total_cost,
	}

def get_subserver_counts(config, rack, switch, total_num_cores, total_ram, total_hdd, total_thrpt):
	(min_nodes, num_nodes) = get_num_nodes(config, total_num_cores, total_ram, total_hdd, total_thrpt)
	(num_switches, num_links) = get_num_switches(switch, num_nodes)
	num_admins = num_nodes/1000
	num_racks = (num_nodes*config["rack_unit"] + num_switches)/rack["units"]
	cool_kw = num_nodes*config["power"]
	return (min_nodes, num_nodes, num_switches, num_links, num_admins, num_racks, cool_kw)

def get_subserver_cost(config, rack, switch, link, total_num_cores, total_ram, total_hdd, total_thrpt):
	(min_nodes, num_nodes, num_switches, num_links, num_admins, num_racks, cool_kw) =\
	get_subserver_counts(config, rack, switch, total_num_cores, total_ram, total_hdd, total_thrpt)
	
	print("Nodes in order to get CORES: {:,.2f}".format(min_nodes[0]))
	print("Nodes in order to get RAM: {:,.2f}".format(min_nodes[1]))
	print("Nodes in order to get HDD: {:,.2f}".format(min_nodes[2]))
	print("Nodes in order to get THROUGHPUT: {:,.2f}".format(min_nodes[3]))
	print()
		
	return get_server_cost(config, rack, switch, link, num_nodes, num_switches, num_links, num_admins, num_racks, cool_kw)

def get_gpu_server_cost(config, rack, switch, link, flops):
	num_nodes = math.ceil(flops/config["flops"])
	(num_switches, num_links) = get_num_switches(switch, num_nodes)
	num_admins = num_nodes/1000
	num_racks = (num_nodes*config["rack_unit"] + num_switches)/rack["units"]
	cool_kw = num_nodes*config["power"] 
	return get_server_cost(config, rack, switch, link, num_nodes, num_switches, num_links, num_admins, num_racks, cool_kw)

def get_amazon_server_cost(config, store_cost, total_num_cores, total_ram, total_hdd):
	(min_nodes, num_nodes) = get_num_nodes(config, total_num_cores, total_ram, total_hdd, 0)
	print("Nodes in order to get CORES: {:,.2f}".format(min_nodes[0]))
	print("Nodes in order to get RAM: {:,.2f}".format(min_nodes[1]))
	print("Nodes in order to get HDD: {:,.2f}".format(min_nodes[2]))
	print("Nodes in order to get THROUGHPUT: {:,.2f}".format(min_nodes[3]))
	print()
	print("Node Cost: {:,.2f}".format(config["cost"]))
	print("Quantity: {:,.2f}".format(num_nodes))
	print("Total Cost (Monthly): {:,.2f}".format(num_nodes*config["cost"]))
	print("Total Cost (5 yrs): {:,.2f}".format(num_nodes*config["cost"]*60))
	print()
	print("Storage Cost (Monthly): {:,.2f}".format(store_cost))
	print("Storage Cost (5yrs): {:,.2f}".format(store_cost*60))
	print()
	print("Total (5yrs): {:,.2f}".format(num_nodes*config["cost"]*60 + store_cost*60))
	print("--------------------------------")
	print()
	print()
	print()

def combine_configs(compute, storage):
	
	return {
		"num_compute_nodes": compute["num_nodes"],
		"num_storage_nodes": storage["num_nodes"],
		"num_links": math.ceil(compute["num_links"] + storage["num_links"]),
		"num_switches": math.ceil(compute["num_switches"] + storage["num_switches"]),
		"num_admins": math.ceil(compute["num_admins"] + storage["num_admins"]),
		"num_racks": math.ceil(compute["num_racks"] + storage["num_racks"]),
		"cool_kw": ((compute["cool_kw"] + storage["cool_kw"]) + (20 * .000392 * compute["rack_area"])),
		"server_kw": compute["server_kw"] + storage["server_kw"],
		"time_hrs": 24*365*5,
		
		"compute_node_cost": compute["node_cost"],
		"storage_node_cost": storage["node_cost"],
		"rack_cost": rack["cost"],
		"power_cost": .083,
		"switch_cost": compute["switch_cost"],
		"link_cost": compute["link_cost"],
		"admin_cost": 59323,
		"cool_cost": .083,
		
		"total_compute_node_cost": compute["total_node_cost"],
		"total_storage_node_cost": storage["total_node_cost"],
		"total_rack_cost": compute["total_rack_cost"] + storage["total_rack_cost"],
		"total_power_cost": compute["total_power_cost"] + storage["total_power_cost"],
		"total_switch_cost": compute["total_switch_cost"] + storage["total_switch_cost"],
		"total_link_cost": compute["total_link_cost"] + storage["total_link_cost"],
		"total_cool_cost": ((compute["cool_kw"] + storage["cool_kw"]) + (20 * .000392 * compute["rack_area"]))*24*365*5*.083,
		"total_admin_cost": compute["total_admin_cost"] + storage["total_admin_cost"],
		"total_cost": compute["total_cost"] + storage["total_cost"],
	}

def to_table(df):
	df = {
		"Compute Servers": {
			"Description": "Perform processing operations",
			"Price Per Item": "${:,.2f}".format(df["compute_node_cost"]),
			"Quantity": "{:,.2f}".format(df["num_compute_nodes"]),
			"Total": "${:,.2f}".format(df["total_compute_node_cost"]),
		},
		
		"Network Switches": {
			"Description": "Route information sent over the network",
			"Price Per Item": "${:,.2f}".format(df["switch_cost"]),
			"Quantity": "{:,.2f}".format(df["num_switches"]),
			"Total": "${:,.2f}".format(df["total_switch_cost"]),
		},
		
		"Network Cables": {
			"Description": "Cables that connect connect computers/switches to each other",
			"Price Per Item": "${:,.2f}".format(df["link_cost"]),
			"Quantity": "{:,.2f}".format(df["num_links"]),
			"Total": "${:,.2f}".format(df["total_link_cost"]),
		},
		
		"Racks": {
			"Description": "Cabinets that hold the server racks",
			"Price Per Item": "${:,.2f}".format(df["rack_cost"]),
			"Quantity": "{:,.2f}".format(df["num_racks"]),
			"Total": "${:,.2f}".format(df["total_rack_cost"]),
		},
		
		"Storage Servers": {
			"Description": "The servers that are meant for permanent mass storage",
			"Price Per Item": "${:,.2f}".format(df["storage_node_cost"]),
			"Quantity": "{:,.2f}".format(df["num_storage_nodes"]),
			"Total": "${:,.2f}".format(df["total_storage_node_cost"]),
		},
		
		"Electric Power": {
			"Description": "Energy cost of server hardware",
			"Price Per Item": "${:,.4f}/kwh".format(df["power_cost"]),
			"Quantity": "{:,.4f} kwh".format(df["time_hrs"]*df["server_kw"]),
			"Total": "${:,.2f}".format(df["total_power_cost"]),
		},
		
		"Cooling": {
			"Description": "Energy cost of AC",
			"Price Per Item": "${:,.4f}/kwh".format(df["cool_cost"]),
			"Quantity": "{:,.4f} kwh".format(df["time_hrs"]*df["cool_kw"]),
			"Total": "${:,.2f}".format(df["total_cool_cost"]),
		},
		
		"Administration": {
			"Description": "Those who manage the server.",
			"Price Per Item": "${:,.2f}".format(df["admin_cost"]),
			"Quantity": "{:,.2f}".format(df["num_admins"]),
			"Total": "${:,.2f}".format(df["total_admin_cost"]),
		},
		
		"Total": {
			"Description": None,
			"Price Per Item": None,
			"Quantity": None,
			"Total": "${:,.2f}".format(df["total_cost"]),
		},
	}
	
	df = pd.DataFrame(df).transpose()
	return df

PRIVATE_CLOUD = False
PUBLIC_CLOUD = False

if PRIVATE_CLOUD: 
	c1 = get_subserver_cost(nodes["p1-compute-config"], rack, switch["25gbps"], link["25gbps"], 256*K, 2*PB, 400*PB, 0)
	c2 = get_subserver_cost(nodes["p1-storage-config"], rack, switch["25gbps"], link["25gbps"], 0, 0, 800*PB, 800*GBPS)
	c3 = combine_configs(c1, c2)
	df = to_table(c3)
	df.to_csv("config1.csv")

	c1 = get_subserver_cost(nodes["p2-compute-config"], rack, switch["10gbps"], link["10gbps"], 2*M, 16*M*GB, 75*M*GB, 0)
	c2 = get_subserver_cost(nodes["p2-storage-config"], rack, switch["10gbps"], link["10gbps"], 0, 0, 10*PB, 100*GBPS)
	c3 = combine_configs(c1, c2)
	df = to_table(c3)
	df.to_csv("config2.csv")

	c1 = get_gpu_server_cost(nodes["p3-compute-config"], rack, switch["25gbps"], link["25gbps"], 1*EX)
	c2 = get_subserver_cost(nodes["p3-storage-config"], rack, switch["25gbps"], link["25gbps"], 0, 0, 1*PB, 10*GBPS)
	c3 = combine_configs(c1, c2)
	df = to_table(c3)
	df.to_csv("config3.csv")

if PUBLIC_CLOUD:
	get_amazon_server_cost(nodes["p1-amazon-compute-config"], 8808601.6, 256*K, 2*PB, 400*PB) 
	
