#!/usr/bin/env bash
set -euo pipefail

MARIAN=../../build
if [ ! -e $MARIAN/marian ]; then
  echo "Marian is not found at '$MARIAN'. Please compile it first!"
  exit 1;
fi

SRC="en"
TRG="de"

compute="-d 0 1 2 3"

# Setup
mkdir -p data model evaluation

# Get Data
echo "Download data and prepare corpus"
./scripts/download-files.sh

# Preprocessing
./scripts/preprocess-data.sh


# Prepare vocab (optional)
# $MARIAN/spm_train \
#   --accept_language $SRC,$TRG \
#   --input data/corpus.clean.$SRC,data/corpus.clean.$TRG \
#   --model_prefix model/vocab.$SRC$TRG \
#   --vocab_size 32000
# mv model/vocab.$SRC$TRG.{model,spm}

# Train
$MARIAN/marian -c transformer-model.yml \
  ${compute} --workspace 9000 \
  --shuffle none --no-restore-corpus --after 5ku \
  --seed 1234 \
  --model model/model.npz \
  --train-sets data/corpus.clean.{$SRC,$TRG} \
  --vocabs model/vocab.$SRC$TRG.spm model/vocab.$SRC$TRG.spm \
  --dim-vocabs 32000 32000 \
  --valid-sets data/valid.{$SRC,$TRG} \
  --log model/train.log --valid-log model/valid.log
  --valid-translation-output model/validation-output-after-{U}-updates-{T}-tokens.txt

# Decoding
SB_OPTS="--metrics bleu chrf -b -w 3 -f text"  # options for sacrebleu
mkdir -p evaluation
echo "Evaluating test set"
cat data/test.$SRC \
  | $MARIAN/marian-decoder -c model/model.npz.decoder.yml \
      ${compute} \
      --log evaluation/testset_decoding.log \
      --quiet --quiet-translation \
      --alignment soft \
  | tee evaluation/testset_output.txt \
  | sacrebleu data/test.$TRG ${SB_OPTS}

# for test in wmt{16,17,18,19,20}; do
#   break
#   echo "Evaluating ${test} test set"
#   sacrebleu -t $test -l $SRC-$TRG --echo src \
#   | $MARIAN/marian-decoder -c model/model.npz.decoder.yml \
#       ${compute} \
#       --log evaluation/${test}_decoding.log \
#       --quiet --quiet-translation \
#   | tee evaluation/${test}_output.txt \
#   | sacrebleu -t $test -l $SRC-$TRG ${SB_OPTS}

# done
