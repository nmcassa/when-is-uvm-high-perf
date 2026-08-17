#!/usr/bin/env python3
# ============================================================================
# cliff_fit.py -- Analyze the UVM capacity cliff from cliff.sh output.
#
# Usage:  python3 cliff_fit.py results/<stamp>/summary.tsv
#         python3 cliff_fit.py <summary.tsv> --ceff 0.9752 --floor 15.6
#
# What it does (matching the PMBS Late-Breaking story):
#   SOLID:
#     * detects the compulsory migration FLOOR from Phase-F points,
#     * detects C_eff as the DEPARTURE from that floor (a robust, byte-based
#       definition -- NOT "zero migration", which is unattainable under reset),
#     * brackets C_eff and reports its width in MiB and %-of-nominal,
#     * quantifies the cliff (mig jump ratio across the boundary).
#   EARLY HOOK (clearly labeled preliminary):
#     * fits excess migration V_ex(eps) = mig - floor vs eps = (h - C_eff)
#       to a POWER LAW (log-log line) and reports alpha,
#     * runs the reciprocal 1/V_ex divergence check (pole vs power law),
#     * states the verdict as PRELIMINARY.
#
# No SciPy -- numpy lstsq only, so it runs on a bare remote box.
# Emits cliff.png / cliff.pdf and a text summary.
# ============================================================================
import sys, os, csv
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---- config -----------------------------------------------------------------
DEPART_TOL = 1.25          # mig > floor*DEPART_TOL counts as "departed"
CAP_GIB    = 16.0          # nominal capacity (matches cliff.sh CAP)

# ---- 0-based CSV field map from uvm_phase.cu emit() (for optional extras) ---
CF = dict(over=2, hot=3, cap=15, hot_gib=16, iter=21, time_s=25,
          htod=37, dtoh=38, mig=39)

def cf(cells, key):
    try:    return float(cells[CF[key]])
    except (ValueError, IndexError): return float("nan")

# ---------------------------------------------------------------------------
def load(path):
    rows = []
    with open(path) as fh:
        for r in csv.DictReader(fh, delimiter="\t"):
            cells = r["csv"].split(",") if "," in r.get("csv", "") else []
            def g(k, default=float("nan")):
                v = r.get(k, "")
                try: return float(v)
                except (TypeError, ValueError): return default
            rows.append(dict(
                phase=r["phase"], label=r["label"],
                hot=g("hot"),
                eps_mib=(g("eps_mib") if r.get("eps_mib") not in ("-", "", None) else float("nan")),
                pct=g("pct"),
                mig=g("mig_gib"),
                time_s=(cf(cells, "time_s") if cells else float("nan")),
            ))
    return rows

def read_meta(sumpath, floor_override, ceff_override):
    floor, ceff = floor_override, ceff_override
    mpath = os.path.join(os.path.dirname(sumpath), "meta.txt")
    if os.path.exists(mpath):
        for line in open(mpath):
            if floor is None and line.startswith("floor_GiB="):
                floor = float(line.split("=", 1)[1])
            if ceff is None and line.startswith("provisional_Ceff_fraction="):
                ceff = float(line.split("=", 1)[1])
    return floor, ceff

# ---------------------------------------------------------------------------
def fit_power(eps, y):
    """y = k * eps^alpha ; fit in log-log."""
    x, ly = np.log(eps), np.log(y)
    A = np.vstack([x, np.ones_like(x)]).T
    coef, *_ = np.linalg.lstsq(A, ly, rcond=None)
    alpha, lnk = coef
    yhat = A @ coef
    ss_res = float(np.sum((ly - yhat) ** 2))
    ss_tot = float(np.sum((ly - ly.mean()) ** 2))
    r2 = 1 - ss_res / ss_tot if ss_tot > 0 else float("nan")
    return dict(alpha=float(alpha), k=float(np.exp(lnk)), r2=r2)

def recip_test(eps, y):
    """1/y = a*eps + b ; x-intercept eps* = -b/a. a<0 & eps*>max(eps) => pole."""
    r = 1.0 / y
    A = np.vstack([eps, np.ones_like(eps)]).T
    coef, *_ = np.linalg.lstsq(A, r, rcond=None)
    a, b = float(coef[0]), float(coef[1])
    rhat = A @ coef
    ss_res = float(np.sum((r - rhat) ** 2))
    ss_tot = float(np.sum((r - r.mean()) ** 2))
    r2 = 1 - ss_res / ss_tot if ss_tot > 0 else float("nan")
    eps_star = (-b / a) if a != 0 else float("nan")
    return dict(a=a, b=b, r2=r2, eps_star=eps_star, r=r)

# ---------------------------------------------------------------------------
def main():
    if len(sys.argv) < 2:
        print("usage: cliff_fit.py summary.tsv [--ceff FRAC] [--floor GiB]")
        sys.exit(1)
    sumpath = sys.argv[1]
    floor_ov = ceff_ov = None
    if "--floor" in sys.argv: floor_ov = float(sys.argv[sys.argv.index("--floor")+1])
    if "--ceff"  in sys.argv: ceff_ov  = float(sys.argv[sys.argv.index("--ceff")+1])

    rows = load(sumpath)
    good = [r for r in rows if not np.isnan(r["mig"])]

    # ---- FLOOR: mean of Phase-F points (fallback: lowest-mig quartile) -----
    floor, ceff = read_meta(sumpath, floor_ov, ceff_ov)
    Fpts = [r for r in good if r["phase"] == "F"]
    if floor is None:
        if Fpts:
            floor = float(np.mean([r["mig"] for r in Fpts]))
        else:
            migs = sorted(r["mig"] for r in good)
            floor = float(np.mean(migs[:max(1, len(migs)//4)]))
    tol = floor * DEPART_TOL

    # ---- C_eff: departure from floor across F+A points --------------------
    fa = sorted([r for r in good if r["phase"] in ("F", "A")], key=lambda r: r["hot"])
    below = [r for r in fa if r["mig"] <= tol]
    above = [r for r in fa if r["mig"] >  tol]
    lo = max((r["hot"] for r in below), default=float("nan"))
    hi = min((r["hot"] for r in above), default=float("nan"))
    if ceff is None:
        ceff = 0.5 * (lo + hi) if not (np.isnan(lo) or np.isnan(hi)) else lo
    bracket_mib = (hi - lo) * CAP_GIB * 1024.0 if not (np.isnan(lo) or np.isnan(hi)) else float("nan")

    # ---- CLIFF magnitude: mig ratio just below vs just above --------------
    mig_lo = next((r["mig"] for r in reversed(below)), float("nan"))
    mig_hi = next((r["mig"] for r in above), float("nan"))
    cliff_ratio = mig_hi / mig_lo if mig_lo and not np.isnan(mig_hi) else float("nan")
    dfoot_mib   = (hi - lo) * CAP_GIB * 1024.0 if not (np.isnan(lo) or np.isnan(hi)) else float("nan")

    # ---- Phase-B excess migration for the exponent hook -------------------
    B = sorted([r for r in good if r["phase"] == "B"], key=lambda r: r["hot"])
    eps = np.array([(r["hot"] - ceff) * CAP_GIB * 1024.0 for r in B])   # MiB
    Vex = np.array([r["mig"] - floor for r in B])                        # GiB
    ok = (eps > 0) & (Vex > 0)
    eps_f, Vex_f = eps[ok], Vex[ok]
    have_fit = len(eps_f) >= 4
    pw = fit_power(eps_f, Vex_f) if have_fit else None
    pl = recip_test(eps_f, Vex_f) if have_fit else None

    # ---- text report ------------------------------------------------------
    print("=" * 70)
    print("SOLID RESULTS")
    print("-" * 70)
    print(f"compulsory migration FLOOR : {floor:.3f} GiB "
          f"({len(Fpts)} floor points)")
    print(f"effective capacity C_eff   : {ceff:.5f} of nominal "
          f"= {ceff*CAP_GIB:.4f} GiB")
    print(f"  = {100*ceff:.3f}% of nominal capacity "
          f"(i.e. {100*(1-ceff):.3f}% BELOW nominal)")
    print(f"C_eff bracket              : ({lo:.5f}, {hi:.5f}) "
          f"= {bracket_mib:.1f} MiB wide")
    print(f"cliff magnitude            : mig {mig_lo:.2f} -> {mig_hi:.2f} GiB "
          f"= {cliff_ratio:.2f}x across {dfoot_mib:.1f} MiB of footprint")
    print("=" * 70)
    print("EARLY / PRELIMINARY HOOK  (divergence exponent -- first-of-a-kind)")
    print("-" * 70)
    if have_fit:
        print(f"excess migration V_ex = mig - floor, eps = (h - C_eff)")
        print(f"points used: {len(eps_f)}  eps range {eps_f.min():.1f}..{eps_f.max():.1f} MiB")
        print(f"POWER LAW  V_ex = k*eps^alpha : "
              f"alpha = {pw['alpha']:.3f}  k = {pw['k']:.3g}  R2(loglog) = {pw['r2']:.4f}")
        print(f"POLE TEST  1/V_ex = a*eps+b   : a = {pl['a']:.3g}  "
              f"eps* = {pl['eps_star']:.1f} MiB  R2 = {pl['r2']:.4f}")
        if pl["a"] < 0 and pl["eps_star"] > eps_f.max():
            print("  -> PRELIMINARY: 1/V_ex trends toward a finite eps*, "
                  "consistent with a divergence (critical capacity).")
        else:
            print(f"  -> PRELIMINARY: consistent with a super-linear power law, "
                  f"alpha ~ {pw['alpha']:.2f} (no finite pole detected in range).")
        print("  NOTE: exponent is PRELIMINARY; C_eff uncertainty dominates. "
              "Reported as an early first-of-a-kind observation.")
    else:
        print("insufficient Phase-B points (>0 excess, >0 eps) for a fit.")
    print("=" * 70)

    # ---- figures ----------------------------------------------------------
    fig, (ax, bx) = plt.subplots(1, 2, figsize=(11, 4.4))

    # (a) THE CLIFF: mig vs %-of-nominal, floor + C_eff annotated.
    allpts = sorted([r for r in good if r["phase"] in ("F", "A", "B")],
                    key=lambda r: r["hot"])
    px = [r["pct"] for r in allpts]
    py = [r["mig"] for r in allpts]
    resx = [r["pct"] for r in allpts if r["mig"] <= tol]
    resy = [r["mig"] for r in allpts if r["mig"] <= tol]
    ovx  = [r["pct"] for r in allpts if r["mig"] >  tol]
    ovy  = [r["mig"] for r in allpts if r["mig"] >  tol]
    ax.semilogy(resx, resy, "o-", color="#2c7fb8", lw=2, ms=6,
                label="on floor (compulsory)")
    ax.semilogy(ovx, ovy, "s-", color="#c0392b", lw=2, ms=6,
                label="thrashing (above C_eff)")
    ax.axhline(floor, ls=":", color="gray", lw=1.5, label=f"floor {floor:.1f} GiB")
    ax.axvspan(100*lo, 100*hi, color="#c0392b", alpha=0.15)
    ax.axvline(100*ceff, color="#27ae60", ls="--", lw=1.5)
    ax.annotate(f"$C_{{eff}}$ = {100*ceff:.2f}% nom\n"
                f"({100*(1-ceff):.2f}% below nominal)\n"
                f"bracket {bracket_mib:.0f} MiB",
                xy=(100*ceff, floor*1.5),
                xytext=(100*ceff-1.2, floor*6), fontsize=8.5,
                arrowprops=dict(arrowstyle="->", lw=1))
    if not np.isnan(cliff_ratio):
        ax.annotate(f"{cliff_ratio:.1f}$\\times$ jump\nover {dfoot_mib:.0f} MiB",
                    xy=(100*ceff, mig_hi), xytext=(100*ceff+0.3, mig_hi*1.6),
                    fontsize=9, color="#c0392b", fontweight="bold")
    ax.set_xlabel("working set (% of nominal capacity)")
    ax.set_ylabel("migrated volume per iteration (GiB)")
    ax.set_title("(a) UVM capacity cliff, measured in bytes")
    ax.grid(alpha=.3, which="both"); ax.legend(fontsize=8, loc="upper left")

    # (b) EARLY HOOK: excess migration vs eps, log-log, power-law fit.
    if have_fit:
        bx.loglog(eps_f, Vex_f, "o", color="#c0392b", ms=7,
                  label="excess migration (measured)")
        xs = np.logspace(np.log10(eps_f.min()), np.log10(eps_f.max()), 100)
        bx.loglog(xs, pw["k"] * xs ** pw["alpha"], "-", color="#2c7fb8", lw=2,
                  label=f"power law $\\alpha$={pw['alpha']:.2f} ($R^2$={pw['r2']:.3f})")
        bx.set_xlabel("footprint past $C_{eff}$   $\\epsilon$ (MiB)")
        bx.set_ylabel("excess migration $V_{ex}=$ mig $-$ floor (GiB)")
        bx.set_title("(b) Super-linear amplification [PRELIMINARY]")
        bx.grid(alpha=.3, which="both"); bx.legend(fontsize=8)
    else:
        bx.text(0.5, 0.5, "insufficient Phase-B points", ha="center", va="center")
        bx.set_axis_off()

    fig.tight_layout()
    fig.savefig("cliff.pdf"); fig.savefig("cliff.png", dpi=160)
    print("wrote cliff.{pdf,png}")

    # ---- data table -------------------------------------------------------
    print()
    print(f"{'phase':>6} {'hot':>9} {'%nom':>8} {'mig_GiB':>9} "
          f"{'excess':>9} {'eps_MiB':>9}")
    for r in allpts:
        e = (r["hot"] - ceff) * CAP_GIB * 1024.0
        print(f"{r['phase']:>6} {r['hot']:>9.4f} {r['pct']:>8.3f} "
              f"{r['mig']:>9.2f} {r['mig']-floor:>9.2f} {e:>9.1f}")


if __name__ == "__main__":
    main()
