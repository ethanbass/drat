My [drat](http://dirk.eddelbuettel.com/code/drat.html) repository for hosting non-CRAN/BioConductor packages that my own packages rely on. The GitHub repo for this R package repository is [here](https://github.com/ethanbass/drat).

## Current Packages
- **[VPdtw](https://github.com/ethanbass/VPdtw)**
    - *v2.2.1: [ff9d561](https://github.com/ethanbass/VPdtw/commit/ff9d561b30d04874293d6a00f9562ca7f88dbd15)*

- **[entab](https://github.com/bovee/entab)**
    - *v0.3.1: [46f050b](https://github.com/bovee/entab/commit/46f050ba28dde4b9d6a87f4c1752da5b9aa902ba)*

- **[chromConverterExtraTests](https://github.com/ethanbass/chromConverterExtraTests)**
    - *v0.4.6: [0fe7461](https://github.com/ethanbass/chromConverterExtraTests/commit/0fe74614a97cbe69f6335ad977fe3ad650e1a937)*

## Notes for maintenance

```
library(drat)
options(dratBranch="docs")   # to default to using docs/ as we set up
insertPackage(file=c("quacking/quacking_1.2.3.tar.gz", "quacking/quacking_1.2.3.zip"), 
              repodir="drat/")
```

To add a package, use `drat::insertPackage("pathTo.tar.gz", repodir = "~/Github/drat/")`.
`drat:insertPackage` should update `src/conrib/PACKAGES`, `src/contrib/PACKAGES.gz`, `src/contrib/PACKAGES.rds` and add the source package file to `src/contrib`. After adding the new package, update this README and commit/push the changes.

## Installation

Install packages as follows from your R console:

```
install.packages("chromConverterExtraTests", repos="ethanbass.github.io/drat")
```

