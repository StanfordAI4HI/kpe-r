# Package index

## Core estimators

The three public entry points. All share the same signature and return a
`"kpe"` S3 object.

- [`kpe()`](https://stanfordai4hi.github.io/kpe-r/reference/kpe.md) :
  K-Fold Personalization Estimator
- [`train_eval()`](https://stanfordai4hi.github.io/kpe-r/reference/train_eval.md)
  : TrainEval baseline: 50/50 split AIPW repeated across shuffles.
- [`papd()`](https://stanfordai4hi.github.io/kpe-r/reference/papd.md) :
  PAPD baseline (Imai's Population Average Prescriptive Difference,
  centered).

## S3 methods

Generics dispatched on the `"kpe"` class.

- [`print(`*`<kpe>`*`)`](https://stanfordai4hi.github.io/kpe-r/reference/print.kpe.md)
  : Print a short summary of a kpe fit.
- [`summary(`*`<kpe>`*`)`](https://stanfordai4hi.github.io/kpe-r/reference/summary.kpe.md)
  : Summary of a kpe fit.
- [`confint(`*`<kpe>`*`)`](https://stanfordai4hi.github.io/kpe-r/reference/confint.kpe.md)
  : Confidence interval for a kpe fit.
- [`coef(`*`<kpe>`*`)`](https://stanfordai4hi.github.io/kpe-r/reference/coef.kpe.md)
  : Extract the point estimate from a kpe fit.
