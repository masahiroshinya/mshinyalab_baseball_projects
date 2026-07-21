from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path


AXES = ("X", "Y", "Z")


def ensure_columns(fieldnames: list[str], columns: list[str]) -> None:
    for column in columns:
        if column not in fieldnames:
            fieldnames.append(column)


def find_point_prefixes(fieldnames: list[str]) -> list[str]:
    prefixes: list[str] = []
    for column in fieldnames:
        if not column.endswith("_X"):
            continue
        prefix = column[:-2]
        if all(f"{prefix}_{axis}" in fieldnames for axis in AXES):
            prefixes.append(prefix)
    return prefixes


def to_float(value: str | None) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if text == "":
        return None
    try:
        return float(text)
    except ValueError:
        return None


def format_float(value: float | None) -> str:
    if value is None or math.isnan(value):
        return ""
    return f"{value:.6f}"


def get_point_m(row: dict[str, str], prefix: str, unit_scale_to_m: float) -> tuple[float, float, float] | None:
    values: list[float] = []
    for axis in AXES:
        value = to_float(row.get(f"{prefix}_{axis}"))
        if value is None:
            return None
        values.append(value * unit_scale_to_m)
    return values[0], values[1], values[2]


def build_point_series_m(
    rows: list[dict[str, str]],
    prefix: str,
    window: int,
    unit_scale_to_m: float,
) -> list[tuple[float, float, float] | None]:
    raw_points = [get_point_m(row, prefix, unit_scale_to_m) for row in rows]
    if window <= 1:
        return raw_points

    half = window // 2
    smoothed_points: list[tuple[float, float, float] | None] = []

    for index in range(len(raw_points)):
        start = max(0, index - half)
        end = min(len(raw_points), index + half + 1)
        local_points = [point for point in raw_points[start:end] if point is not None]

        if not local_points:
            smoothed_points.append(None)
            continue

        smoothed_points.append(
            (
                sum(point[0] for point in local_points) / len(local_points),
                sum(point[1] for point in local_points) / len(local_points),
                sum(point[2] for point in local_points) / len(local_points),
            )
        )

    return smoothed_points


def add_speed_columns(
    rows: list[dict[str, str]],
    fieldnames: list[str],
    prefix: str,
    fps: float,
    points_m: list[tuple[float, float, float] | None],
) -> None:
    distance_col = f"{prefix}_distance_m"
    speed_mps_col = f"{prefix}_speed_mps"
    speed_kmph_col = f"{prefix}_speed_kmph"
    ensure_columns(fieldnames, [distance_col, speed_mps_col, speed_kmph_col])

    for row in rows:
        row[distance_col] = ""
        row[speed_mps_col] = ""
        row[speed_kmph_col] = ""

    for index in range(1, len(rows)):
        prev_row = rows[index - 1]
        curr_row = rows[index]

        previous_frame = to_float(prev_row.get("frame_number"))
        current_frame = to_float(curr_row.get("frame_number"))
        previous_point = points_m[index - 1]
        current_point = points_m[index]

        if previous_frame is None or current_frame is None:
            continue
        if previous_point is None or current_point is None:
            continue

        frame_diff = current_frame - previous_frame
        if frame_diff <= 0:
            continue

        dt = frame_diff / fps
        dx = current_point[0] - previous_point[0]
        dy = current_point[1] - previous_point[1]
        dz = current_point[2] - previous_point[2]
        distance_m = math.sqrt(dx * dx + dy * dy + dz * dz)
        speed_mps = distance_m / dt
        speed_kmph = speed_mps * 3.6

        curr_row[distance_col] = format_float(distance_m)
        curr_row[speed_mps_col] = format_float(speed_mps)
        curr_row[speed_kmph_col] = format_float(speed_kmph)


def add_bat_tip_estimate(rows: list[dict[str, str]], fieldnames: list[str], extend_ratio: float) -> None:
    required = [
        "left_wrist_X",
        "left_wrist_Y",
        "left_wrist_Z",
        "right_wrist_X",
        "right_wrist_Y",
        "right_wrist_Z",
        "bat_X",
        "bat_Y",
        "bat_Z",
    ]
    missing = [column for column in required if column not in fieldnames]
    if missing:
        missing_text = ", ".join(missing)
        raise ValueError(f"bat tip estimation requires columns: {missing_text}")

    bat_tip_columns = [f"bat_tip_{axis}" for axis in AXES]
    ensure_columns(fieldnames, bat_tip_columns)

    for row in rows:
        left_wrist = get_point_m(row, "left_wrist", 1.0)
        right_wrist = get_point_m(row, "right_wrist", 1.0)
        bat = get_point_m(row, "bat", 1.0)

        if left_wrist is None or right_wrist is None or bat is None:
            for column in bat_tip_columns:
                row[column] = ""
            continue

        grip = (
            (left_wrist[0] + right_wrist[0]) / 2.0,
            (left_wrist[1] + right_wrist[1]) / 2.0,
            (left_wrist[2] + right_wrist[2]) / 2.0,
        )
        bat_tip = (
            grip[0] + (bat[0] - grip[0]) * extend_ratio,
            grip[1] + (bat[1] - grip[1]) * extend_ratio,
            grip[2] + (bat[2] - grip[2]) * extend_ratio,
        )

        for axis, value in zip(AXES, bat_tip):
            row[f"bat_tip_{axis}"] = format_float(value)


def parse_targets(targets: str | None, available: list[str]) -> list[str]:
    if targets is None or targets.strip() == "":
        return available

    requested = [target.strip() for target in targets.split(",") if target.strip()]
    missing = [target for target in requested if target not in available]
    if missing:
        raise ValueError(f"target columns were not found: {', '.join(missing)}")
    return requested


def read_csv(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames is None:
            raise ValueError("input CSV has no header")
        fieldnames = list(reader.fieldnames)
        rows = [dict(row) for row in reader]
    return rows, fieldnames


def write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Calculate 3D point speeds from a tracking CSV.",
    )
    parser.add_argument("--input", required=True, type=Path, help="Input CSV path.")
    parser.add_argument("--output", required=True, type=Path, help="Output CSV path.")
    parser.add_argument("--fps", required=True, type=float, help="Video frame rate.")
    parser.add_argument(
        "--targets",
        default=None,
        help="Comma-separated point prefixes. Default: all detected points.",
    )
    parser.add_argument(
        "--unit-scale-to-m",
        default=1.0,
        type=float,
        help="Scale factor to convert input coordinates to meters.",
    )
    parser.add_argument(
        "--smooth-window",
        default=1,
        type=int,
        help="Centered rolling window for coordinate smoothing.",
    )
    parser.add_argument(
        "--make-bat-tip",
        action="store_true",
        help="Estimate bat_tip coordinates from wrist midpoint and bat point.",
    )
    parser.add_argument(
        "--bat-extend-ratio",
        default=1.5,
        type=float,
        help="Ratio used for bat_tip = grip + (bat - grip) * ratio.",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.fps <= 0:
        raise ValueError("--fps must be positive")
    if args.unit_scale_to_m <= 0:
        raise ValueError("--unit-scale-to-m must be positive")
    if args.smooth_window < 1:
        raise ValueError("--smooth-window must be 1 or greater")

    rows, fieldnames = read_csv(args.input)
    if "frame_number" not in fieldnames:
        raise ValueError("input CSV must contain frame_number")

    if args.make_bat_tip:
        add_bat_tip_estimate(rows, fieldnames, args.bat_extend_ratio)

    available = find_point_prefixes(fieldnames)
    targets = parse_targets(args.targets, available)
    if not targets:
        raise ValueError("no point columns were found")

    for target in targets:
        points_m = build_point_series_m(rows, target, args.smooth_window, args.unit_scale_to_m)
        add_speed_columns(rows, fieldnames, target, args.fps, points_m)

    write_csv(args.output, rows, fieldnames)

    print(f"saved: {args.output}")
    print(f"fps: {args.fps}")
    print(f"unit_scale_to_m: {args.unit_scale_to_m}")
    print(f"targets: {', '.join(targets)}")


if __name__ == "__main__":
    main()
