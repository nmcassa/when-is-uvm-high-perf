import pandas as pd
import matplotlib.pyplot as plt

# Load data
df = pd.read_csv("NPS_oversub_results.csv")

# Split
explicit = df[df["use_uvm"] == 0]
uvm = df[df["use_uvm"] == 1]

# Sort by scale (important for clean lines)
explicit = explicit.sort_values("scale")
uvm = uvm.sort_values("scale")

# Plot
plt.figure(figsize=(6, 4))

plt.plot(explicit["scale"], explicit["NodesPerSec"],
         marker='o', linewidth=2, label="Explicit")

plt.plot(uvm["scale"], uvm["NodesPerSec"],
         marker='o', linewidth=2, label="UVM")

plt.axvline(x=25.2, linestyle=':', linewidth=2, label="Device Memory")

plt.xlabel("Graph Scale")
plt.ylabel("ActiveEdgesPerSec")
plt.grid(True)

plt.legend()

plt.tight_layout()
plt.savefig("oversub.pdf", dpi=200)
plt.show()
