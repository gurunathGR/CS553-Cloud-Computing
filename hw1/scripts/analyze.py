
import numpy as np
import matplotlib.pyplot as plt

plt.plot([1000,100000, 10000000], [.017, .403, 48.453], label="Generate")
plt.plot([1000,100000, 10000000], [.008, .223, 21.569], label="Sort")
plt.xlabel("Number of Records")
plt.ylabel("Execution Time (s)")
plt.legend()
plt.title("Number of Records vs Execution Time")
plt.savefig("num_records_vs_time.png")
plt.close()

