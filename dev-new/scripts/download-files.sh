#!/usr/bin/env bash
set -euo pipefail

cd data

# Get en-de for training WMT21
wget -nc https://www.statmt.org/europarl/v10/training/europarl-v10.de-en.tsv.gz 2> /dev/null

# Uncompress
if [ ! -e europarl-v10.de-en.tsv ]; then
  gzip --keep -q -d europarl-v10.de-en.tsv.gz
fi

# Corpus
if [ ! -e corpus.de ] || [ ! -e corpus.en ]; then
  cat europarl-v10.de-en.tsv | cut -f 1 > corpus.de
  cat europarl-v10.de-en.tsv | cut -f 2 > corpus.en
fi

# Dev Sets
sacrebleu -t wmt19 -l en-de --echo src > valid.en
sacrebleu -t wmt19 -l en-de --echo ref > valid.de

# Test Sets
sacrebleu -t wmt20 -l en-de --echo src > test.en
sacrebleu -t wmt20 -l en-de --echo ref > test.de

echo "Corpus prepared"
