#!/usr/bin/env python3
"""
Plot the NVIDIA UVM oversubscription cliff from summary.tsv.

Usage:
    python3 plot_cliff.py results/20260817-154924/summary.tsv

Optional output path:
    python3 plot_cliff.py summary.tsv -o oversubscription_cliff.pdf

The input file must contain the following tab-separated columns:
    phase, label, hot, over, eps_mib, pct, mig_gib, csv
"""

import argparse
import csv
import math
import statistics
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter, LogLocator, NullFormatter


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Plot UVM migration amplification near GPU capacity."
    )
    parser.add_argument(
        "summary",
        type=Path,
        help="Path to the summary.tsv input file.",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help=(
            "Output figure path. The format is inferred from the extension "
            "(default: oversubscription_cliff.pdf next to the input file)."
        ),
    )
    parser.add_argument(
        "--title",
        default=None,
        help="Optional figure title.",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=300,
        help="Output resolution for raster formats (default: 300).",
    )
    return parser.parse_args()


def read_summary(path):
    required_columns = {
        "phase",
        "label",
        "hot",
        "over",
        "eps_mib",
        "pct",
        "mig_gib",
    }

    records = []

    with path.open("r", encoding="utf-8", newline="") as input_file:
        reader = csv.DictReader(input_file, delimiter="\t")

        if reader.fieldnames is None:
            raise ValueError(f"{path} does not contain a header")

        # Strip whitespace in case the TSV header was column-aligned.
        reader.fieldnames = [name.strip() for name in reader.fieldnames]

        missing = required_columns.difference(reader.fieldnames)
        if missing:
            missing_text = ", ".join(sorted(missing))
            raise ValueError(f"Missing required columns: {missing_text}")

        for line_number, row in enumerate(reader, start=2):
            row = {
                key.strip(): value.strip() if value is not None else ""
                for key, value in row.items()
                if key is not None
            }

            try:
                record = {
                    "phase": row["phase"],
                    "label": row["label"],
                    "hot": float(row["hot"]),
                    "over": float(row["over"]),
                    "pct": float(row["pct"]),
                    "mig_gib": float(row["mig_gib"]),
                    "eps_mib": (
                        None
                        if row["eps_mib"] in {"", "-"}
                        else float(row["eps_mib"])
                    ),
                }
            except (KeyError, ValueError) as error:
                raise ValueError(
                    f"Could not parse numeric data on line {line_number}: {error}"
                ) from error

            if not math.isfinite(record["pct"]) or not math.isfinite(
                record["mig_gib"]
            ):
                continue

            records.append(record)

    if not records:
        raise ValueError(f"No valid records found in {path}")

    records.sort(key=lambda record: (record["pct"], record["mig_gib"]))
    return records


def estimate_capacity(records):
    """
    Infer usable device capacity from pre-cliff measurements.

    Phase F contains the floor sweep, where total migration is approximately
    one pass over the active working set:

        migrated GiB ~= capacity GiB * pct / 100
    """
    floor_records = [
        record
        for record in records
        if record["phase"] == "F" and record["pct"] > 0.0
    ]

    if not floor_records:
        # Fallback: use the lowest-migration third of all observations.
        count = max(3, len(records) // 3)
        floor_records = sorted(
            records, key=lambda record: record["mig_gib"]
        )[:count]

    capacity_estimates = [
        record["mig_gib"] / (record["pct"] / 100.0)
        for record in floor_records
    ]

    return statistics.median(capacity_estimates)


def add_derived_values(records, capacity_gib):
    for record in records:
        record["working_set_gib"] = capacity_gib * record["pct"] / 100.0
        record["amplification"] = (
            record["mig_gib"] / record["working_set_gib"]
        )


def find_cliff(records, threshold=1.05):
    """
    Define the cliff onset as the first observation whose migration traffic
    exceeds the one-pass working-set baseline by more than `threshold`.
    """
    for record in records:
        if record["amplification"] >= threshold:
            return record
    return None


def find_amplification_pair(records, target=2.0):
    """
    Find a pre-cliff baseline point and the first later point reaching the
    requested migration amplification.

    The baseline is the final earlier point within 1% of one-pass migration.
    """
    target_record = next(
        (
            record
            for record in records
            if record["amplification"] >= target
        ),
        None,
    )

    if target_record is None:
        return None, None

    baseline_candidates = [
        record
        for record in records
        if record["pct"] < target_record["pct"]
        and record["amplification"] <= 1.01
    ]

    if not baseline_candidates:
        return None, target_record

    baseline_record = max(
        baseline_candidates,
        key=lambda record: record["pct"],
    )
    return baseline_record, target_record


def style_axis(axis):
    axis.grid(
        True,
        which="major",
        axis="both",
        color="#d0d0d0",
        linewidth=0.65,
        alpha=0.8,
    )
    axis.grid(
        True,
        which="minor",
        axis="y",
        color="#e5e5e5",
        linewidth=0.45,
        alpha=0.65,
    )
    axis.tick_params(direction="in", top=True, right=True)


def draw_series(axis, records):
    x_values = [record["pct"] for record in records]
    y_values = [record["mig_gib"] for record in records]

    axis.plot(
        x_values,
        y_values,
        color="#1f4e79",
        linewidth=1.4,
        alpha=0.85,
        zorder=2,
    )
    axis.scatter(
        x_values,
        y_values,
        s=24,
        facecolor="#2f75b5",
        edgecolor="white",
        linewidth=0.45,
        zorder=3,
        label="Measured migration",
    )


def draw_baseline(axis, records, capacity_gib):
    x_min = min(record["pct"] for record in records)
    x_max = max(record["pct"] for record in records)

    baseline_x = [x_min, x_max]
    baseline_y = [
        capacity_gib * x_min / 100.0,
        capacity_gib * x_max / 100.0,
    ]

    axis.plot(
        baseline_x,
        baseline_y,
        color="#666666",
        linestyle="--",
        linewidth=1.2,
        zorder=1,
        label="One-pass working-set migration",
    )


def add_capacity_axis(axis, capacity_gib):
    """
    Add a top x-axis expressing the active working set in GiB.
    """

    def pct_to_gib(percent):
        return capacity_gib * percent / 100.0

    def gib_to_pct(gib):
        return 100.0 * gib / capacity_gib

    secondary = axis.secondary_xaxis(
        "top",
        functions=(pct_to_gib, gib_to_pct),
    )
    secondary.set_xlabel("Active working set (GiB)")
    secondary.tick_params(direction="in")
    return secondary


def make_figure(records, capacity_gib, title=None):
    cliff = find_cliff(records)
    baseline_record, amplified_record = find_amplification_pair(
        records,
        target=2.0,
    )

    # IEEE two-column width is approximately 7.1 inches.
    figure, axes = plt.subplots(
        1,
        2,
        figsize=(7.1, 3.15),
        constrained_layout=True,
        gridspec_kw={"width_ratios": [1.0, 1.12]},
    )

    full_axis, zoom_axis = axes

    # ------------------------------------------------------------------
    # Panel (a): complete migration-amplification sweep.
    # ------------------------------------------------------------------
    draw_series(full_axis, records)
    draw_baseline(full_axis, records, capacity_gib)

    full_axis.set_yscale("log")
    full_axis.set_xlabel("Active working set (% of GPU memory)")
    full_axis.set_ylabel("Total migrated data (GiB)")
    #full_axis.set_title("(a) Complete sweep")

    full_axis.yaxis.set_major_locator(
        LogLocator(base=10.0, subs=(1.0, 2.0, 5.0))
    )
    full_axis.yaxis.set_major_formatter(
        FuncFormatter(lambda value, _: f"{value:g}")
    )
    full_axis.yaxis.set_minor_locator(
        LogLocator(base=10.0, subs=(3.0, 4.0, 6.0, 7.0, 8.0, 9.0))
    )
    full_axis.yaxis.set_minor_formatter(NullFormatter())

    if cliff is not None:
        full_axis.axvline(
            cliff["pct"],
            color="#c00000",
            linestyle=":",
            linewidth=1.25,
            zorder=1,
            label="Detected cliff onset",
        )

    style_axis(full_axis)
    full_axis.legend(
        loc="upper left",
        fontsize=7.2,
        frameon=True,
        framealpha=0.95,
    )

    # ------------------------------------------------------------------
    # Panel (b): high-resolution view of the cliff.
    # ------------------------------------------------------------------
    draw_series(zoom_axis, records)
    draw_baseline(zoom_axis, records, capacity_gib)

    if cliff is not None:
        zoom_axis.axvline(
            cliff["pct"],
            color="#c00000",
            linestyle=":",
            linewidth=1.25,
            zorder=1,
        )
        zoom_axis.scatter(
            [cliff["pct"]],
            [cliff["mig_gib"]],
            marker="D",
            s=40,
            facecolor="#c00000",
            edgecolor="white",
            linewidth=0.55,
            zorder=5,
        )

    # Select a narrow range centered around the observed cliff.
    if cliff is not None:
        zoom_left = max(
            min(record["pct"] for record in records),
            cliff["pct"] - 0.10,
        )
        zoom_right = min(
            max(record["pct"] for record in records),
            cliff["pct"] + 0.25,
        )
    else:
        pct_values = [record["pct"] for record in records]
        zoom_left = min(pct_values)
        zoom_right = max(pct_values)

    zoom_records = [
        record
        for record in records
        if zoom_left <= record["pct"] <= zoom_right
    ]

    zoom_axis.set_xlim(zoom_left, zoom_right)

    if zoom_records:
        zoom_y_min = min(record["mig_gib"] for record in zoom_records)
        zoom_y_max = max(record["mig_gib"] for record in zoom_records)
        y_padding = max(2.0, 0.10 * (zoom_y_max - zoom_y_min))
        zoom_axis.set_ylim(
            max(0.0, zoom_y_min - y_padding),
            zoom_y_max + y_padding,
        )

    zoom_axis.set_xlabel("Active working set (% of GPU memory)")
    zoom_axis.set_ylabel("Total migrated data (GiB)")
    #zoom_axis.set_title("(b) Cliff at high resolution")
    style_axis(zoom_axis)
    add_capacity_axis(zoom_axis, capacity_gib)

    # Highlight the small working-set increase that produces at least
    # twofold migration amplification.
    if baseline_record is not None and amplified_record is not None:
        delta_mib = (
            amplified_record["working_set_gib"]
            - baseline_record["working_set_gib"]
        ) * 1024.0

        traffic_factor = (
            amplified_record["mig_gib"] / baseline_record["mig_gib"]
        )

        zoom_axis.scatter(
            [baseline_record["pct"], amplified_record["pct"]],
            [baseline_record["mig_gib"], amplified_record["mig_gib"]],
            s=43,
            facecolor="#ed7d31",
            edgecolor="white",
            linewidth=0.6,
            zorder=6,
        )

        zoom_axis.annotate(
            "",
            xy=(
                amplified_record["pct"],
                amplified_record["mig_gib"],
            ),
            xytext=(
                baseline_record["pct"],
                baseline_record["mig_gib"],
            ),
            arrowprops={
                "arrowstyle": "->",
                "color": "#b34700",
                "linewidth": 1.25,
            },
            zorder=5,
        )

        annotation = (
            f"+{delta_mib:.1f} MiB working set\n"
            f"{traffic_factor:.1f}$\\times$ migrated data"
        )

        midpoint_x = (
            baseline_record["pct"] + amplified_record["pct"]
        ) / 2.0
        midpoint_y = (
            baseline_record["mig_gib"] + amplified_record["mig_gib"]
        ) / 2.0

        zoom_axis.annotate(
            annotation,
            xy=(midpoint_x, midpoint_y),
            xytext=(10, 12),
            textcoords="offset points",
            fontsize=7.4,
            color="#7f3300",
            bbox={
                "boxstyle": "round,pad=0.25",
                "facecolor": "white",
                "edgecolor": "#ed7d31",
                "alpha": 0.95,
            },
        )

    if title:
        figure.suptitle(title, fontsize=10.5)

    return figure, cliff, baseline_record, amplified_record


def main():
    arguments = parse_arguments()

    if arguments.output is None:
        output_path = arguments.summary.with_name(
            "oversubscription_cliff.pdf"
        )
    else:
        output_path = arguments.output

    records = read_summary(arguments.summary)
    capacity_gib = estimate_capacity(records)
    add_derived_values(records, capacity_gib)

    figure, cliff, baseline_record, amplified_record = make_figure(
        records,
        capacity_gib,
        title=arguments.title,
    )

    figure.savefig(
        output_path,
        dpi=arguments.dpi,
        bbox_inches="tight",
    )
    plt.close(figure)

    print(f"Read {len(records)} observations from {arguments.summary}")
    print(f"Estimated usable GPU capacity: {capacity_gib:.3f} GiB")

    if cliff is not None:
        print(
            "Detected cliff onset: "
            f"{cliff['pct']:.4f}% capacity, "
            f"{cliff['mig_gib']:.4f} GiB migrated, "
            f"{cliff['amplification']:.3f}x amplification"
        )

    if baseline_record is not None and amplified_record is not None:
        delta_mib = (
            amplified_record["working_set_gib"]
            - baseline_record["working_set_gib"]
        ) * 1024.0
        traffic_factor = (
            amplified_record["mig_gib"] / baseline_record["mig_gib"]
        )
        print(
            "Annotated transition: "
            f"+{delta_mib:.2f} MiB working set, "
            f"{traffic_factor:.2f}x migrated data"
        )

    print(f"Wrote figure to {output_path}")


if __name__ == "__main__":
    main()
