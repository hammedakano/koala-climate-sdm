# Download climate layers. Run once before run_all.R.
#
# Two sources are supported, set in config.R:
#   "wc21_cmip6"   WorldClim 2.1 baseline plus a CMIP6 model, downloaded with
#                  the geodata package (recommended for new runs).
#   "wc14_cmip5"   WorldClim 1.4 baseline plus ACCESS1-0 RCP8.5 (CMIP5). These
#                  are the layers used for the results in the README. Place the
#                  files in data/climate/wc14_cmip5/ (bio1.bil ... bio19.bil and
#                  ac85bi50*.tif, ac85bi70*.tif).
source("config.R")

if (CLIMATE_SOURCE == "wc21_cmip6") {
  if (!requireNamespace("geodata", quietly = TRUE)) install.packages("geodata")
  dir <- file.path("data", "climate", "wc21_cmip6")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  geodata::worldclim_global(var = "bio", res = RES_ARCMIN, path = dir)
  for (p in names(FUTURE_PERIODS)) {
    geodata::cmip6_world(model = CMIP6_MODEL, ssp = CMIP6_SSP, time = FUTURE_PERIODS[[p]],
                         var = "bioc", res = RES_ARCMIN, path = dir)
  }
  message("Downloaded WorldClim 2.1 and ", CMIP6_MODEL, " SSP", CMIP6_SSP, " to ", dir)
} else {
  message("Using local WorldClim 1.4 and CMIP5 layers in data/climate/wc14_cmip5/")
}
