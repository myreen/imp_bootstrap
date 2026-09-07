#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
iterations=${1:-1000}
batches=${2:-3}

if [[ ! $iterations =~ ^[1-9][0-9]*$ ]]; then
  echo "iterations must be a positive integer" >&2
  exit 2
fi

if [[ ! $batches =~ ^[1-9][0-9]*$ ]]; then
  echo "batches must be a positive integer" >&2
  exit 2
fi

labels=(
  impl-adjusted
  certirocq-adjusted-o0
  certirocq-adjusted-o1
  certirocq-adjusted-o2
  certirocq-adjusted-o3
  impl-mynat
  certirocq-mynat-o0
  certirocq-mynat-o1
  certirocq-mynat-o2
  certirocq-mynat-o3
  certirocq-original-o0
  certirocq-original-o1
  certirocq-original-o2
  certirocq-original-o3
)
declare -A executables=(
  [impl-adjusted]="$script_dir/_build/impl-adjusted/impl-adjusted"
  [certirocq-adjusted-o0]="$script_dir/_build/certirocq-adjusted/certirocq-adjusted-o0"
  [certirocq-adjusted-o1]="$script_dir/_build/certirocq-adjusted/certirocq-adjusted-o1"
  [certirocq-adjusted-o2]="$script_dir/_build/certirocq-adjusted/certirocq-adjusted"
  [certirocq-adjusted-o3]="$script_dir/_build/certirocq-adjusted/certirocq-adjusted-o3"
  [impl-mynat]="$script_dir/_build/impl-mynat/impl-mynat"
  [certirocq-mynat-o0]="$script_dir/_build/certirocq-mynat/certirocq-mynat-o0"
  [certirocq-mynat-o1]="$script_dir/_build/certirocq-mynat/certirocq-mynat-o1"
  [certirocq-mynat-o2]="$script_dir/_build/certirocq-mynat/certirocq-mynat"
  [certirocq-mynat-o3]="$script_dir/_build/certirocq-mynat/certirocq-mynat-o3"
  [certirocq-original-o0]="$script_dir/_build/certirocq-original/certirocq-original-o0"
  [certirocq-original-o1]="$script_dir/_build/certirocq-original/certirocq-original-o1"
  [certirocq-original-o2]="$script_dir/_build/certirocq-original/certirocq-original"
  [certirocq-original-o3]="$script_dir/_build/certirocq-original/certirocq-original-o3"
)
declare -A total_ns=(
  [impl-adjusted]=0
  [certirocq-adjusted-o0]=0
  [certirocq-adjusted-o1]=0
  [certirocq-adjusted-o2]=0
  [certirocq-adjusted-o3]=0
  [impl-mynat]=0
  [certirocq-mynat-o0]=0
  [certirocq-mynat-o1]=0
  [certirocq-mynat-o2]=0
  [certirocq-mynat-o3]=0
  [certirocq-original-o0]=0
  [certirocq-original-o1]=0
  [certirocq-original-o2]=0
  [certirocq-original-o3]=0
)

ulimit -s 1048576

for label in "${labels[@]}"; do
  executable=${executables[$label]}
  if [[ ! -x $executable ]]; then
    echo "missing executable: $executable" >&2
    exit 2
  fi

  output=$($executable)
  if [[ -n $output ]]; then
    echo "$label produced unexpected output" >&2
    exit 1
  fi
done

bench_one() {
  local label=$1
  local executable=${executables[$label]}
  local start_ns end_ns elapsed_ns mean_ms throughput

  start_ns=$(date +%s%N)
  for ((i = 0; i < iterations; i++)); do
    "$executable" >/dev/null
  done
  end_ns=$(date +%s%N)

  elapsed_ns=$((end_ns - start_ns))
  total_ns[$label]=$((total_ns[$label] + elapsed_ns))
  mean_ms=$(awk -v ns="$elapsed_ns" -v runs="$iterations" \
    'BEGIN { printf "%.6f", ns / runs / 1000000 }')
  throughput=$(awk -v ns="$elapsed_ns" -v runs="$iterations" \
    'BEGIN { printf "%.2f", runs * 1000000000 / ns }')

  printf '%-22s mean=%sms throughput=%s runs/s\n' \
    "$label" "$mean_ms" "$throughput"
}

for ((batch = 0; batch < batches; batch++)); do
  echo "batch $((batch + 1))/$batches"
  for ((offset = 0; offset < ${#labels[@]}; offset++)); do
    index=$(((batch + offset) % ${#labels[@]}))
    bench_one "${labels[$index]}"
  done
done

echo "aggregate"
for label in "${labels[@]}"; do
  runs=$((iterations * batches))
  mean_ms=$(awk -v ns="${total_ns[$label]}" -v runs="$runs" \
    'BEGIN { printf "%.6f", ns / runs / 1000000 }')
  throughput=$(awk -v ns="${total_ns[$label]}" -v runs="$runs" \
    'BEGIN { printf "%.2f", runs * 1000000000 / ns }')
  printf '%-22s mean=%sms throughput=%s runs/s\n' \
    "$label" "$mean_ms" "$throughput"
done
