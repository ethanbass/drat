My [drat](http://dirk.eddelbuettel.com/code/drat.html) repository for hosting non-CRAN/BioConductor packages that my own packages rely on. The GitHub repo for this R package repository is [here](https://github.com/ethanbass/drat).

## Current Packages

<!-- drat:packages:start -->

- **[chromConverterExtraTests](https://github.com/ethanbass/chromConverterExtraTests)**
    - *v0.4.9: [f2b7f70](https://github.com/ethanbass/chromConverterExtraTests/commit/f2b7f7036b35eaa25c36ac1344f8847141d7e690)*

- **[entab](https://github.com/bovee/entab)**
    - *v0.3.1: [46f050b](https://github.com/bovee/entab/commit/46f050ba28dde4b9d6a87f4c1752da5b9aa902ba)*

- **[VPdtw](https://github.com/ethanbass/VPdtw)**
    - *v2.2.1: [ff9d561](https://github.com/ethanbass/VPdtw/commit/ff9d561b30d04874293d6a00f9562ca7f88dbd15)*

<!-- drat:packages:end -->

## Notes for maintenance

Use the helper script in `tools/`, which builds the source and macOS binary
packages, inserts them, archives superseded sources, regenerates every
`PACKAGES` index, and rewrites the package list above:

```sh
tools/drat-add ~/R_packages/chromConverterExtraTests
```

It stops before touching git, so review `git status` and commit yourself. Other
entry points:

```sh
tools/drat-add --reindex   # rebuild indexes + README/index.html, no new package
tools/drat-add --check     # report any index that disagrees with the files on disk
tools/drat-add --help
```

The package list above is generated from `docs/src/contrib/PACKAGES` joined to
`manifest.dcf`, which records the source commit each published version was built
from. Edit anything outside the `drat:packages` markers freely; that text is
never rewritten.

## Installation

Install packages as follows from your R console:

```
install.packages("chromConverterExtraTests", repos = "https://ethanbass.github.io/drat")
```

