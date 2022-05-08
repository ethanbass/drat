My [drat](http://dirk.eddelbuettel.com/code/drat.html) repository for hosting non-CRAN/BioConductor packages that my own packages rely on. The GitHub repo for this R package repository is [here](https://github.com/ethanbass/drat).

## Current Packages
- **[VPdtw](https://github.com/ethanbass/VPdtw)**
    - *v2.1-12: [0d9d819](https://github.com/ethanbass/VPdtw/commit/0d9d819214f637e984df0c130ce0a087a9f5abc9)*
- **[entab](https://github.com/bovee/entab)**
    - *v0.2.2: [1ec25c6](https://github.com/bovee/entab/commit/1ec25c655d134f437147c1d5d792249193151a42)*

## Notes for maintenance

To add a package, use `drat::insertPackage("pathTo.tar.gz", repodir = "~/Github/drat/")`.
`drat:insertPackage` should update `src/conrib/PACKAGES`, `src/contrib/PACKAGES.gz`, `src/contrib/PACKAGES.rds` and add the source package file to `src/contrib`. 
After adding the new package, update this README and commit/push the changes.

