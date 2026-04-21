import pandas as pd
import matplotlib.pyplot as plt

# Load CSVs
df = pd.read_csv("subset_results.csv")
scale_df = pd.read_csv("scale_back.csv")

scales = sorted(df["scale"].unique())

fig, axes = plt.subplots(1, len(scales), figsize=(3 * len(scales), 4), sharey=True)

if len(scales) == 1:
    axes = [axes]

# Store legend handles
all_lines = []
all_labels = []

# Compute global range for active scale
scale_min = scale_df["active_scale"].min()
scale_max = scale_df["active_scale"].max()

for i, (ax, scale) in enumerate(zip(axes, scales)):
    sub = df[df["scale"] == scale]
    scale_sub = scale_df[scale_df["input_scale"] == scale]

    explicit = sub[sub["use_uvm"] == 0]
    uvm = sub[sub["use_uvm"] == 1]

    # --- LEFT AXIS (time) ---
    l1, = ax.plot(explicit["BFS_DEPTH"], explicit["NodesPerSec"],
                  marker='o', label="Explicit" if i == 0 else None)
    l2, = ax.plot(uvm["BFS_DEPTH"], uvm["NodesPerSec"],
                  marker='o', label="UVM" if i == 0 else None)

    ax.set_title(f"Scale {scale}")
    ax.set_xlabel("BFS Depth")
    ax.grid(True)

    # Only leftmost subplot shows left y-axis
    if i == 0:
        ax.set_ylabel("ActiveEdgesPerSec")
    else:
        ax.set_ylabel("")
        ax.tick_params(labelleft=False)

    # --- RIGHT AXIS (active scale) ---
    ax2 = ax.twinx()
    l3, = ax2.plot(scale_sub["BFS_DEPTH"], scale_sub["active_scale"],
                   linestyle='--', marker='x',
                   label="Active Scale" if i == 0 else None)

    # Apply SAME limits to all subplots
    ax2.set_ylim(scale_min, 1.0)

    # Only show the right axis on the last subplot
    if i == len(scales) - 1:
        ax2.set_ylabel("Active Scale")
    else:
        ax2.set_ylabel("")
        ax2.tick_params(labelright=False)

    # Collect legend handles only once
    if i == 0:
        all_lines.extend([l1, l2, l3])
        all_labels.extend([l.get_label() for l in [l1, l2, l3]])

# One global legend
fig.legend(all_lines, all_labels, loc="upper center", ncol=3)

plt.tight_layout(rect=[0, 0, 1, 0.9])  # leave space for legend
plt.savefig("pr_results_with_scale.pdf", dpi=200)
plt.show()
