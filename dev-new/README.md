# Transformer

En-De
- Train: EuroParl + News Comm. + CommonCrawl (WMT)
- Val: WMT19
- Test: WMT20

## Install requirements
```shell
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Getting Marian
```shell
git clone https://github.com/marian-nmt/marian-dev
cd marian-dev
```

### Compile
```shell
mkdir build
cd build
cmake .. -DUSE_SENTENCEPIECE=ON
cmake --build .
```

## Acquire data

### Download
Use a subset of the wmt21 news task training data

```shell
# Get en-de for training WMT21
wget -nc https://www.statmt.org/europarl/v10/training/europarl-v10.de-en.tsv.gz 2> /dev/null
wget -nc https://data.statmt.org/news-commentary/v16/training/news-commentary-v16.de-en.tsv.gz 2> /dev/null
wget -nc https://www.statmt.org/wmt13/training-parallel-commoncrawl.tgz 2> /dev/null

# Dev Sets
sacrebleu -t wmt19 -l en-de --echo src > valid.en
sacrebleu -t wmt19 -l en-de --echo ref > valid.de

# Test Sets
sacrebleu -t wmt20 -l en-de --echo src > test.en
sacrebleu -t wmt20 -l en-de --echo ref > test.de
```

### Combine
```shell
for compressed in europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv; do
  if [ ! -e $compressed ]; then
    gzip --keep -q -d $compressed.gz
  fi
done

tar xf training-parallel-commoncrawl.tgz

# Corpus
if [ ! -e corpus.de ] || [ ! -e corpus.en ]; then
  # TSVs
  cat europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv | cut -f 1 > corpus.de
  cat europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv | cut -f 2 > corpus.en

  # Plain text
  cat commoncrawl.de-en.de >> corpus.de
  cat commoncrawl.de-en.en >> corpus.en
fi
```

Splitting up TSV files and appending parallel plain-text.

## Prepare data
```shell
for lang in en de; do
  # Remove non-printing characters
  cat corpus.$lang \
    | perl $MOSES_SCRIPTS/tokenizer/remove-non-printing-char.perl \
    > .corpus.norm.$lang
done
```

```shell
# Contrain length between 1 100
perl $MOSES_SCRIPTS/training/clean-corpus-n.perl .corpus.norm en de .corpus.trim 1 100
```

```shell
# Deduplicate
paste <(cat .corpus.trim.en) <(cat .corpus.trim.de) \
  | LC_ALL=C sort -S 50% | uniq \
  > .corpus.uniq.ende.tsv
```

```shell
cat .corpus.uniq.ende.tsv | cut -f 1 > corpus.clean.en
cat .corpus.uniq.ende.tsv | cut -f 2 > corpus.clean.de
```


## Training

Start with a `transformer-base` preset
```shell
marian --task transformer-base --dump-config expand > transformer-model.yml
```

Make training a little more verbose. Stop training after 10 stalls on ce-mean-words
```
disp-freq: 1000
disp-first: 10
early-stopping: 10
save-freq: 2ku
```

Validate with additional metrics, also keep the best model per metric. Valdiate more often.
```
keep-best: true
valid-freq: 2ku
valid-metrics:
  - ce-mean-words
  - bleu
  - perplexity
```

### SentencePiece (Optional)
```shell
 $MARIAN/spm_train \
  --accept_language en,de \
  --input data/corpus.clean.en,data/corpus.clean.de \
  --model_prefix model/vocab.ende \
  --vocab_size 32000
mv model/vocab.ende.{model,spm}
```
In the absence of a vocabulary file, Marian will build one.

### Training Command
```shell
$MARIAN/marian -c transformer-model.yml \
  -d 0 1 2 3 --workspace 9000 \
  --seed 1234 \
  --model model/model.npz \
  --train-sets data/corpus.clean.{en,de} \
  --vocabs model/vocab.ende.spm model/vocab.ende.spm \
  --dim-vocabs 32000 32000 \
  --valid-sets data/valid.{en,de} \
  --log model/train.log --valid-log model/valid.log
```


## Translation
Test set
```shell
cat data/test.en \
  | $MARIAN/marian-decoder \
      -c model/model.npz.best-bleu-detok.npz.decoder.yml \
      -d 0 1 2 3 \
      --beam-size 12 --normalize 1 \
  | tee evaluation/testset_output.txt \
  | sacrebleu data/test.de --metrics bleu chrf -b -w 3 -f text
```
