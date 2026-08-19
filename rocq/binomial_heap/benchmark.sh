#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
iterations=${1:-1000}
input=${2:-9}
executable=${3:-"$script_dir/heapprog"}

if [[ ! $iterations =~ ^[1-9][0-9]*$ ]]; then
  echo "iterations must be a positive integer" >&2
  exit 2
fi

if [[ ! $input =~ ^[0-9]$ ]]; then
  echo "input must be one digit from 0 through 9" >&2
  exit 2
fi

if [[ ! -x $executable ]]; then
  echo "executable not found or not executable: $executable" >&2
  exit 2
fi

n=$((10#$input))
expected=$((((n + 1) * (n + 1)) % 10))

run_once() {
  printf '%s' "$input" | "$executable"
}

actual=$(run_once)
if [[ $actual != "$expected" ]]; then
  echo "warmup failed: expected '$expected', got '$actual'" >&2
  exit 1
fi

start_ns=$(date +%s%N)
for ((i = 0; i < iterations; i++)); do
  actual=$(run_once)
  if [[ $actual != "$expected" ]]; then
    echo "run $((i + 1)) failed: expected '$expected', got '$actual'" >&2
    exit 1
  fi
done
end_ns=$(date +%s%N)

elapsed_ns=$((end_ns - start_ns))
if ((elapsed_ns == 0)); then
  elapsed_ns=1
fi

elapsed_seconds=$(awk -v ns="$elapsed_ns" 'BEGIN { printf "%.6f", ns / 1000000000 }')
runs_per_second=$(awk -v runs="$iterations" -v ns="$elapsed_ns" \
  'BEGIN { printf "%.2f", runs * 1000000000 / ns }')

echo "Binomial heap end-to-end benchmark"
echo "  executable: $executable"
echo "  input: $input (expected output: $expected)"
echo "  iterations: $iterations"
echo "  elapsed: ${elapsed_seconds}s"
echo "  throughput: ${runs_per_second} runs/s"
