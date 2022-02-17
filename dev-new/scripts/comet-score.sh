#!/usr/bin/env bash
set -euo pipefail

# Compute Comet score
# Perform on CPU to avoid competing for GPU memory

comet-score \
  --gpus 0 \
  -s data/valid.en \
  -t $1 \
  -r data/valid.de \
  --model wmt20-comet-da \
  2> ./scripts/.comet.stderr.log \
  | tail -1 \
  | grep -oP "([+-]?\d+.\d+)"
