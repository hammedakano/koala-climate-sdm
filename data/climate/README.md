Climate layers are not stored in the repository.

* `wc14_cmip5/` WorldClim 1.4 bioclimatic variables (bio1.bil to bio19.bil, 2.5 arc-minutes, cropped to Australia) and ACCESS1-0 RCP8.5 bioclimatic layers for 2050 (`ac85bi50*.tif`) and 2070 (`ac85bi70*.tif`) at 10 arc-minutes. These produced the results in the main README.
* `wc21_cmip6/` created by `R/00_get_climate.R` when `CLIMATE_SOURCE <- "wc21_cmip6"` in `config.R`.
