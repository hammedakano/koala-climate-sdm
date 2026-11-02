# Settings for the whole pipeline.
CLIMATE_SOURCE <- "wc14_cmip5"   # or "wc21_cmip6"
RES_ARCMIN     <- 10             # model resolution in arc-minutes (about 18 km)
CMIP6_MODEL    <- "ACCESS-CM2"
CMIP6_SSP      <- "585"
FUTURE_PERIODS <- list(`2050` = "2041-2060", `2070` = "2061-2080")

BUFFER_KM      <- 300            # background is drawn within this distance of records
RANGE_MIN_LON  <- 136            # drop records west of this longitude (outside the native range)
N_BACKGROUND   <- 10000          # capped at the number of land cells in the study area
COR_CUTOFF     <- 0.7
BLOCK_DEG      <- 2              # spatial block size for cross-validation
K_FOLDS        <- 5
SEED           <- 2026

# Candidate predictors in order of ecological priority for koalas
# (heat and drought stress first).
CANDIDATES <- c("bio5", "bio12", "bio17", "bio15", "bio1", "bio6", "bio4",
                "bio14", "bio2", "bio3", "bio7", "bio8", "bio9", "bio10",
                "bio11", "bio13", "bio16", "bio18", "bio19")
