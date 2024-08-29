My [drat](http://dirk.eddelbuettel.com/code/drat.html) repository for hosting non-CRAN/BioConductor packages that my own packages rely on. The GitHub repo for this R package repository is [here](https://github.com/ethanbass/drat).

## Current Packages
- **[VPdtw](https://github.com/ethanbass/VPdtw)**
    - *v2.2.0: [f79b078](https://github.com/ethanbass/VPdtw/commit/f79b07891240edb2717735c003a2c3358e37a06b)*

- **[entab](https://github.com/bovee/entab)**
    - *v0.3.1: [46f050b](https://github.com/bovee/entab/commit/46f050ba28dde4b9d6a87f4c1752da5b9aa902ba)*

- **[chromConverterExtraTests](https://github.com/ethanbass/chromConverterExtraTests)**
    - *v0.4.1: [072ed1e](https://github.com/ethanbass/chromConverterExtraTests/commit/072ed1e5862dd51333a498e000f3c894205e2a13)*

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

