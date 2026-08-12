#!/usr/bin/env python3
"""Plot the UVM capacity cliff from summary.tsv.  Usage: plot.py results/<stamp>/summary.tsv"""
import sys, csv
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

# 0-based CSV field map for the uvm_phase warm (iter=-2) row
F = dict(over=2, hot=3, loc=6, cap=15, hot_gib=16, it=21, t=25, tmin=26, tmax=27,
         rate=28, uniq=30, htod=37, dtoh=38, mig=39,
         Am=40, Am_htod=41, Am_hot=42, Am_hot_htod=43, batches=46)

def f(c, k):
    v = c[F[k]].strip()
    try: return float(v)
    except ValueError: return float("nan")

rows = []
with open(sys.argv[1]) as fh:
    for r in csv.DictReader(fh, delimiter="\t"):
        if "," not in r["csv"]: continue
        c = r["csv"].split(",")
        rows.append(dict(phase=r["phase"], label=r["label"], pct=float(r["pct"]),
                         hot_gib=f(c,"hot_gib"), cap=f(c,"cap"), loc=int(float(c[F["loc"]])),
                         t=f(c,"t"), rate=f(c,"rate"), uniq=f(c,"uniq"),
                         htod=f(c,"htod"), dtoh=f(c,"dtoh"), mig=f(c,"mig"),
                         Am_hot_htod=f(c,"Am_hot_htod"), batches=f(c,"batches")))

p1 = sorted([r for r in rows if r["phase"] == "P1" and r["label"] != "shelf_ctl"],
            key=lambda r: r["hot_gib"])
ctl = next((r for r in rows if r["label"] == "shelf_ctl"), None)
p2  = sorted([r for r in rows if r["phase"] == "P2"], key=lambda r: r["loc"])

base = min(r["t"] for r in p1)
# C_eff bracket = last zero-migration point / first migrating point
res  = [r for r in p1 if r["mig"] == 0]
ovr  = [r for r in p1 if r["mig"] > 0]
lo   = max(r["hot_gib"] for r in res)
hi   = min(r["hot_gib"] for r in ovr)
ceff = 0.5 * (lo + hi)

fig, (ax, bx, cx) = plt.subplots(1, 3, figsize=(15, 4.4))

# ---- Panel A: the cliff -----------------------------------------------------
ax.semilogy([r["pct"] for r in res], [r["t"] for r in res], "o-", color="#2c7fb8",
            lw=2, ms=6, label="resident (zero migration)")
ax.semilogy([r["pct"] for r in ovr], [r["t"] for r in ovr], "s-", color="#c0392b",
            lw=2, ms=6, label="migrating")
ax.semilogy([res[-1]["pct"], ovr[0]["pct"]], [res[-1]["t"], ovr[0]["t"]],
            "--", color="#c0392b", lw=1.5)
if ctl: ax.semilogy([ctl["pct"]], [ctl["t"]], "x", color="k", ms=11, mew=2,
                    label="control: 1.5$\\times$ allocation")
ax.axhline(base, ls=":", c="gray", lw=1)
ax.axvspan(100*lo/16, 100*hi/16, color="#c0392b", alpha=0.15)
ax.annotate(f"$C_{{eff}}$ = {ceff:.3f} GiB\n({100*ceff/16:.2f}% of nominal)\nbracketed to {1024*(hi-lo):.0f} MiB",
            xy=(100*ceff/16, base*8), xytext=(64, base*90), fontsize=9,
            arrowprops=dict(arrowstyle="->", lw=1))
jump = ovr[0]["t"] / res[-1]["t"]
ax.annotate(f"{jump:.0f}$\\times$ slower\nfor +{1024*(hi-lo):.0f} MiB",
            xy=(ovr[0]["pct"], ovr[0]["t"]), xytext=(78, ovr[0]["t"]*1.4),
            fontsize=9, color="#c0392b", fontweight="bold")
ax.set_xlabel("working set (% of nominal 16 GiB)"); ax.set_ylabel("warm-iteration time (s)")
ax.set_title("(a) UVM fails 2.4% below nominal capacity")
ax.grid(alpha=.3, which="both"); ax.legend(fontsize=8, loc="upper left")

# ---- Panel B: amplification vs random-replacement ---------------------------
ox = [1024*(r["hot_gib"]-ceff) for r in ovr]          # MiB past C_eff
oy = [r["Am_hot_htod"] for r in ovr]                  # HtoD GiB per hot GiB per iter
rr = [max((r["hot_gib"]-ceff)/r["hot_gib"], 1e-9) for r in ovr]   # random-replacement
bx.semilogy(ox, oy, "s-", color="#c0392b", lw=2, ms=7, label="measured amplification")
bx.semilogy(ox, rr, "^--", color="#2c7fb8", lw=2, ms=7, label="random replacement")
for x, m, p in zip(ox, oy, rr):
    bx.annotate(f"{m/p:,.0f}$\\times$", xy=(x, m), xytext=(0, 8),
                textcoords="offset points", ha="center", fontsize=8)
bx.set_xlabel("footprint past $C_{eff}$ (MiB)")
bx.set_ylabel("HtoD GiB migrated per hot GiB per iteration")
bx.set_title("(b) Amplification vs. random-replacement bound")
bx.grid(alpha=.3, which="both"); bx.legend(fontsize=8)

# ---- Panel C: access-order discriminator ------------------------------------
if p2:
    lbl = [f"locality\n{r['loc']}" for r in p2]
    i = range(len(p2)); w = .38
    cx.bar([k-w/2 for k in i], [r["t"] for r in p2], w, color="#c0392b", label="time (s)")
    cx.set_ylabel("warm-iteration time (s)", color="#c0392b")
    cx.set_xticks(list(i)); cx.set_xticklabels(lbl); cx.grid(alpha=.3, axis="y")
    dx = cx.twinx()
    dx.bar([k+w/2 for k in i], [r["Am_hot_htod"] for r in p2], w, color="#2c7fb8")
    dx.set_ylabel("amplification (HtoD / hot GiB)", color="#2c7fb8")
    for k, r in enumerate(p2):
        dx.annotate(f"unique\n{r['uniq']:.1f} GiB", xy=(k, 0), xytext=(0, 6),
                    textcoords="offset points", ha="center", fontsize=7.5, color="dimgray")
    cx.set_title(f"(c) Access order @ {p2[0]['pct']:.1f}% nominal")

fig.tight_layout(); fig.savefig("fig1_capacity_cliff.pdf"); fig.savefig("fig1_capacity_cliff.png", dpi=160)
print("wrote fig1_capacity_cliff.{pdf,png}\n")

hdr = f"{'label':>10} {'hot GiB':>8} {'%nom':>6} {'warm s':>9} {'Macc/s':>8} " \
      f"{'uniq GiB':>9} {'HtoD':>9} {'DtoH':>9} {'A_m':>7} {'batches':>9}"
print(hdr); print("-"*len(hdr))
for r in p1 + ([ctl] if ctl else []) + p2:
    print(f"{r['label']:>10} {r['hot_gib']:>8.3f} {r['pct']:>6.2f} {r['t']:>9.4f} "
          f"{r['rate']:>8.2f} {r['uniq']:>9.4f} {r['htod']:>9.3f} {r['dtoh']:>9.3f} "
          f"{r['Am_hot_htod']:>7.3f} {r['batches']:>9.0f}")
print(f"\nC_eff bracketed: ({lo:.3f}, {hi:.3f}) GiB = {1024*(hi-lo):.0f} MiB wide, "
      f"{100*ceff/16:.2f}% of nominal")
print(f"Cliff: {res[-1]['t']:.4f} s -> {ovr[0]['t']:.4f} s = {jump:.0f}x for +{1024*(hi-lo):.0f} MiB "
      f"({100*(hi-lo)/lo:.3f}% more data)")
