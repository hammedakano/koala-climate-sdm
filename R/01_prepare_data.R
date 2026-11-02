# Clean occurrences, build the climate stacks and sample background points.
source("config.R"); source("R/functions.R")
suppressPackageStartupMessages({ library(terra) })
set.seed(SEED)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

aus <- ext(110, 155, -45, -9)

read_stacks <- function() {
  if (CLIMATE_SOURCE == "wc14_cmip5") {
    d <- file.path("data", "climate", "wc14_cmip5")
    cur <- rast(file.path(d, paste0("bio", 1:19, ".bil")))
    names(cur) <- paste0("bio", 1:19)
    fac <- round(RES_ARCMIN / 2.5)
    if (fac > 1) cur <- aggregate(cur, fac, mean, na.rm = TRUE)
    fut <- lapply(c(`2050` = "ac85bi50", `2070` = "ac85bi70"), function(code) {
      r <- rast(file.path(d, paste0(code, 1:19, ".tif")))
      names(r) <- paste0("bio", 1:19)
      resample(crop(r, aus), cur, method = "bilinear")
    })
  } else {
    d <- file.path("data", "climate", "wc21_cmip6")
    cur <- crop(geodata::worldclim_global(var = "bio", res = RES_ARCMIN, path = d), aus)
    names(cur) <- paste0("bio", 1:19)
    fut <- lapply(FUTURE_PERIODS, function(tp) {
      r <- crop(geodata::cmip6_world(CMIP6_MODEL, CMIP6_SSP, tp, "bioc", RES_ARCMIN, d), aus)
      names(r) <- paste0("bio", 1:19)
      resample(r, cur, method = "bilinear")
    })
  }
  cur <- crop(cur, aus)
  crs(cur) <- "EPSG:4326"
  for (i in seq_along(fut)) crs(fut[[i]]) <- "EPSG:4326"
  list(current = cur, future = fut)
}

st <- read_stacks()
land <- !is.na(st$current[["bio1"]])

# Occurrences (GBIF records of Phascolarctos cinereus)
occ <- read.csv("data/raw/koala_gbif_presence.csv")
occ <- data.frame(lon = occ$decimalLongitude, lat = occ$decimalLatitude)
n_raw <- nrow(occ)
occ <- occ[complete.cases(occ), ]
occ <- occ[!duplicated(occ), ]
# Koalas are native only to eastern and south-eastern Australia. Records west of
# 136 E (Western Australia and central Australia) are captive or erroneous.
n_outside <- sum(occ$lon < RANGE_MIN_LON)
occ <- occ[occ$lon >= RANGE_MIN_LON, ]
occ <- occ[!is.na(extract(st$current[["bio1"]], as.matrix(occ))[, 1]), ]
occ <- thin_one_per_cell(occ, st$current)
message("Occurrences: ", n_raw, " raw, ", n_outside, " outside native range removed, ", nrow(occ), " after cleaning and thinning")

# Study area and background
pts <- vect(occ, geom = c("lon", "lat"), crs = "EPSG:4326")
area <- aggregate(buffer(pts, BUFFER_KM * 1000))
area_r <- mask(land, area)
area_r[area_r == 0] <- NA
n_cells <- global(!is.na(area_r), "sum")[1, 1]
bg <- spatSample(area_r, size = min(N_BACKGROUND, n_cells), method = "random", na.rm = TRUE,
                 xy = TRUE, values = FALSE)
bg <- data.frame(lon = bg[, 1], lat = bg[, 2])

dat <- rbind(cbind(occ, occ = 1), cbind(bg, occ = 0))
env <- extract(st$current, as.matrix(dat[, c("lon", "lat")]))
dat <- cbind(dat, env)
dat <- dat[complete.cases(dat), ]

vars <- select_uncorrelated(dat, CANDIDATES, COR_CUTOFF)
message("Predictors retained: ", paste(vars, collapse = ", "))

saveRDS(list(dat = dat, vars = vars, area = wrap(area)), "outputs/model_data.rds")
writeRaster(st$current, "outputs/climate_current.tif", overwrite = TRUE)
for (p in names(st$future))
  writeRaster(st$future[[p]], paste0("outputs/climate_", p, ".tif"), overwrite = TRUE)

write.csv(data.frame(step = c("raw records", "removed outside native range", "after cleaning and thinning", "background points (one per cell, capped at N_BACKGROUND)", "predictors retained"),
                     value = c(n_raw, n_outside, nrow(occ), sum(dat$occ == 0), paste(vars, collapse = " "))),
          "outputs/tables/data_summary.csv", row.names = FALSE)
