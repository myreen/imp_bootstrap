#!/usr/bin/env python3

import argparse
import csv
import re
import resource
import statistics
import subprocess
import sys
import tempfile
import time
from collections import defaultdict
from pathlib import Path


ROCQ_ROOT = Path(__file__).resolve().parent
MARKER_RE = re.compile(r"^TIMING compiler_stage ([A-Za-z0-9_]+)$")
ROCQ_TIME_RE = re.compile(
    r"^Finished transaction in ([0-9.]+) secs "
    r"\(([0-9.]+)u,([0-9.]+)s\) \(successful\)$"
)

BASE_TARGETS = [
    "utils/Core.vo",
    "utils/Llist.vo",
    "utils/AppList.vo",
    "utils/Words4Naive.vo",
    "commons/ProofUtils.vo",
    "commons/CompilerUtils.vo",
    "assembly/ASMSyntax.vo",
    "assembly/ASMToString.vo",
    "imperative/ImpSyntax.vo",
    "functional/FunValues.vo",
    "functional/FunSemantics.vo",
    "fp2imp/FpToImpCodegen.vo",
    "imp2asm/ImpToASMCodegen.vo",
    "imp2asm/Compiler.vo",
    "parsing/Parser.vo",
    "automation/RelCompiler.vo",
]

REIFICATION_TARGETS = [
    ("compiler_utilities", "derivations/CompilerUtilsDerivations.vo"),
    ("parser", "derivations/ParserDerivations.vo"),
    ("imperative_to_assembly", "derivations/ImpToASMCodegenDerivations.vo"),
    ("assembly_to_string", "derivations/AsmToStringDerivations.vo"),
    ("compiler_entry", "derivations/CompilerDerivations.vo"),
]

COMPILATION_TARGETS = [
    ("functional_to_imperative", "bootstrapping/CompilerToImpTiming.vo"),
    ("render_imperative", "bootstrapping/RenderImpTiming.vo"),
    ("imperative_to_assembly", "bootstrapping/CompilerToAssemblyTiming.vo"),
    ("render_assembly", "bootstrapping/RenderAssemblyTiming.vo"),
]

TimingRow = tuple[
    int,
    str,
    str,
    float,
    float,
    float,
    float | None,
    float | None,
    float | None,
]


def dune_command(build_dir: Path, *targets: str) -> list[str]:
    return [
        "dune",
        "build",
        "--root",
        str(ROCQ_ROOT),
        "--build-dir",
        str(build_dir),
        "--cache=disabled",
        "--display=short",
        *targets,
    ]


def child_usage() -> tuple[float, float]:
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    return usage.ru_utime, usage.ru_stime


def run_command(command: list[str], log_path: Path) -> tuple[float, float, float]:
    user_before, system_before = child_usage()
    start = time.perf_counter()
    with log_path.open("w") as log:
        result = subprocess.run(
            command,
            cwd=ROCQ_ROOT,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
    elapsed = time.perf_counter() - start
    user_after, system_after = child_usage()

    if result.returncode != 0:
        sys.stderr.write(log_path.read_text())
        raise subprocess.CalledProcessError(result.returncode, command)

    return elapsed, user_after - user_before, system_after - system_before


def parse_compiler_stage(log_path: Path) -> tuple[str, float, float, float]:
    stage: tuple[str, float, float, float] | None = None
    pending: str | None = None

    for line in log_path.read_text().splitlines():
        marker = MARKER_RE.match(line)
        if marker:
            pending = marker.group(1)
            continue

        timing = ROCQ_TIME_RE.match(line)
        if timing and pending is not None:
            if stage is not None:
                raise RuntimeError(f"multiple compiler stage timings in {log_path}")
            stage = pending, *(float(value) for value in timing.groups())
            pending = None

    if pending is not None:
        raise RuntimeError(f"missing Time result for compiler stage {pending}")
    if stage is None:
        raise RuntimeError(f"no compiler stage timing in {log_path}")
    return stage


def print_summary(rows: list[TimingRow]) -> None:
    samples: dict[tuple[str, str], list[float]] = defaultdict(list)
    for _, category, step, elapsed, _, _, _, _, _ in rows:
        samples[(category, step)].append(elapsed)

    print(
        f"{'category':<18} {'step':<28} {'n':>3} "
        f"{'mean(s)':>10} {'median(s)':>10} {'min(s)':>10} {'max(s)':>10}"
    )
    for (category, step), values in samples.items():
        print(
            f"{category:<18} {step:<28} {len(values):>3} "
            f"{statistics.mean(values):>10.3f} "
            f"{statistics.median(values):>10.3f} "
            f"{min(values):>10.3f} {max(values):>10.3f}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Measure reification and compilation of the bootstrapped compiler"
    )
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    if args.runs < 1:
        parser.error("--runs must be positive")

    timestamp = time.strftime("%Y%m%d-%H%M%S")
    output_dir = args.output or ROCQ_ROOT / "timings" / f"compiler-{timestamp}"
    if not output_dir.is_absolute():
        output_dir = Path.cwd() / output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    rows: list[TimingRow] = []

    for run in range(1, args.runs + 1):
        with tempfile.TemporaryDirectory(prefix="impboot-compiler-timing-") as temp:
            build_dir = Path(temp) / "build"
            setup_log = output_dir / f"run-{run}-setup.log"
            print(f"run {run}/{args.runs}: building prerequisites", flush=True)
            run_command(dune_command(build_dir, *BASE_TARGETS), setup_log)

            reification_start = time.perf_counter()
            reification_user, reification_system = child_usage()
            for step, target in REIFICATION_TARGETS:
                print(f"run {run}/{args.runs}: reification {step}", flush=True)
                log = output_dir / f"run-{run}-reification-{step}.log"
                elapsed, user, system = run_command(
                    dune_command(build_dir, target), log
                )
                rows.append(
                    (run, "reification", step, elapsed, user, system, None, None, None)
                )
            total_elapsed = time.perf_counter() - reification_start
            total_user, total_system = child_usage()
            rows.append(
                (
                    run,
                    "pipeline",
                    "reification_total",
                    total_elapsed,
                    total_user - reification_user,
                    total_system - reification_system,
                    None,
                    None,
                    None,
                )
            )

            compilation_start = time.perf_counter()
            compilation_user, compilation_system = child_usage()
            for step, target in COMPILATION_TARGETS:
                print(f"run {run}/{args.runs}: compilation {step}", flush=True)
                log = output_dir / f"run-{run}-compilation-{step}.log"
                elapsed, user, system = run_command(dune_command(build_dir, target), log)
                timed_step, rocq_elapsed, rocq_user, rocq_system = (
                    parse_compiler_stage(log)
                )
                if timed_step != step:
                    raise RuntimeError(
                        f"expected timing for {step} in {log}, found {timed_step}"
                    )
                rows.append(
                    (
                        run,
                        "compilation",
                        step,
                        elapsed,
                        user,
                        system,
                        rocq_elapsed,
                        rocq_user,
                        rocq_system,
                    )
                )
            total_elapsed = time.perf_counter() - compilation_start
            total_user, total_system = child_usage()
            rows.append(
                (
                    run,
                    "pipeline",
                    "compilation_total",
                    total_elapsed,
                    total_user - compilation_user,
                    total_system - compilation_system,
                    None,
                    None,
                    None,
                )
            )

    csv_path = output_dir / "timings.csv"
    with csv_path.open("w", newline="") as timing_file:
        writer = csv.writer(timing_file)
        writer.writerow(
            [
                "run",
                "category",
                "step",
                "real_seconds",
                "user_seconds",
                "system_seconds",
                "rocq_time_seconds",
                "rocq_user_seconds",
                "rocq_system_seconds",
            ]
        )
        writer.writerows(rows)

    print_summary(rows)
    print(f"raw timings: {csv_path}")
    print(f"raw logs: {output_dir}")


if __name__ == "__main__":
    main()
