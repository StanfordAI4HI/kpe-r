## R CMD check results

0 errors | 0 warnings | 0 notes

* This is a new release.

## Test environments

* Local: macOS, R 4.3.3.
* GitHub Actions (R-CMD-check.yaml): ubuntu-latest (R devel, release, oldrel-1),
  macOS (release), Windows (release).

## Notes for the CRAN maintainer

* The learner backends (`ranger`, `policytree`, `grf`, `glmnet`) are in
  `Suggests` and used conditionally; code paths that need them error inform, and
  examples/vignettes that use them are guarded.
* The JobCorps and Joke vignettes read external data via the `KPE_DATA_DIR`
  environment variable and are **not** evaluated at build time (gated with
  `eval = nzchar(Sys.getenv("KPE_DATA_DIR"))`), so the package builds without
  the data present.
