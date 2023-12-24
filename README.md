My [drat](http://dirk.eddelbuettel.com/code/drat.html) repository for hosting non-CRAN/BioConductor packages that my own packages rely on. The GitHub repo for this R package repository is [here](https://github.com/ethanbass/drat).

## Current Packages
- **[VPdtw](https://github.com/ethanbass/VPdtw)**
    - *v2.2.0: [f79b078](https://github.com/ethanbass/VPdtw/commit/f79b07891240edb2717735c003a2c3358e37a06b)*
- **[entab](https://github.com/bovee/entab)**
    - *v0.3.1: [9660d9a](https://github.com/bovee/entab/commit/9660d9a3ab6bc7147262cfeef383cf0b51d41cbf)*
- **[chromConverterExtraTests](https://github.com/ethanbass/chromConverterExtraTests)**
    - *v0.2.0: [454d277](https://github.com/ethanbass/chromConverterExtraTests/commit/454d277b7eb0eb58aabc77de805ff867f403857a)*

## Notes for maintenance

To add a package, use `drat::insertPackage("pathTo.tar.gz", repodir = "~/Github/drat/")`.
`drat:insertPackage` should update `src/conrib/PACKAGES`, `src/contrib/PACKAGES.gz`, `src/contrib/PACKAGES.rds` and add the source package file to `src/contrib`. After adding the new package, update this README and commit/push the changes.

