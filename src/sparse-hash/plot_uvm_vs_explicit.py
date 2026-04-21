import sys
import pandas as pd
import matplotlib.pyplot as plt

plt.rcParams.update({
    "font.size": 16,        # base size
    "axes.titlesize": 18,
    "axes.labelsize": 16,
    "xtick.labelsize": 14,
    "ytick.labelsize": 14,
    "legend.fontsize": 14,
})

def main():
    if len(sys.argv) != 2:
        print("Usage: python plot_uvm_vs_explicit.py results.csv")
        sys.exit(1)

    input_file = sys.argv[1]

    df = pd.read_csv(input_file)

    # Drop incomplete rows (e.g., missing explicit_ms)
    df = df.dropna()

    # Ensure correct types
    df["fraction"] = df["fraction"].astype(float)
    df["uvm_ms"] = df["uvm_ms"].astype(float)
    df["explicit_ms"] = df["explicit_ms"].astype(float)
    df["table_gb"] = df["table_gb"].astype(int)

    plt.figure(figsize=(10, 6))

    for gb in sorted(df["table_gb"].unique()):
        sub = df[df["table_gb"] == gb]

        plt.plot(sub["fraction"], sub["uvm_ms"],
                 marker="o", linestyle="-",
                 label=f"UVM {gb}GB")

        plt.plot(sub["fraction"], sub["explicit_ms"],
                 marker="x", linestyle="--",
                 label=f"Explicit {gb}GB")

    plt.xscale("log")
    plt.xlabel("Active Set Fraction (log scale)")
    plt.ylabel("Time (ms)")
    plt.grid(True, which="both", linestyle="--", alpha=0.4)
    plt.legend(ncol=2, fontsize=12)

    plt.tight_layout()
    plt.savefig("uvm_vs_explicit.pdf")
    print("Saved plot to uvm_vs_explicit.pdf")

if __name__ == "__main__":
    main()
