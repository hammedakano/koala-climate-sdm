# Fit final models, build a weighted ensemble and project to future climates.
source("config.R"); source("R/functions.R")
suppressPackageStartupMessages({ library(terra); library(ggplot2) })
md <- readRDS("outputs/model_data.rds"); dat <- md$dat; vars <- md$vars
summ <- read.csv("outputs/tables/cv_summary.csv")
sp <- summ[summ$scheme == "Spatial block", ]

# Ensemble weights from spatial-block AUC. Models below 0.7 are dropped.
sp$w <- pmax(sp$auc - 0.5, 0); sp$w[sp$auc < 0.7] <- 0
sp$w <- sp$w / sum(sp$w)
write.csv(sp[, c("model", "auc", "w")], "outputs/tables/ensemble_weights.csv", row.names = FALSE)

stacks <- list(current = rast("outputs/climate_current.tif"),
               `2050` = rast("outputs/climate_2050.tif"),
               `2070` = rast("outputs/climate_2070.tif"))
area <- unwrap(md$area)

fits <- lapply(setNames(sp$model[sp$w > 0], sp$model[sp$w > 0]), fit_model, df = dat, vars = vars)

ens <- lapply(stacks, function(s) {
  s <- mask(crop(s, area), area)
  layers <- lapply(names(fits), function(m) predict_raster(fits[[m]], s, vars) * sp$w[sp$model == m])
  Reduce(`+`, layers)
})

# Threshold: 10th percentile of suitability at presence records (P10).
# 90% of known records fall in cells classed as suitable.
p_occ <- extract(ens$current, as.matrix(dat[dat$occ == 1, c("lon", "lat")]))[, 1]
th <- unname(stats::quantile(p_occ, 0.10, na.rm = TRUE))

nov <- lapply(stacks[c("2050", "2070")], function(s) mask(crop(novelty_mask(s, dat, vars), area), area))

ca <- cellSize(ens$current, unit = "km")
area_tab <- do.call(rbind, lapply(names(ens), function(p) {
  suit <- ens[[p]] >= th
  data.frame(period = p,
             suitable_km2 = round(global(suit * ca, "sum", na.rm = TRUE)[1, 1]),
             novel_climate_pct = if (p == "current") 0 else
               round(100 * global(nov[[p]], "mean", na.rm = TRUE)[1, 1], 1))
}))
area_tab$change_pct <- round(100 * (area_tab$suitable_km2 / area_tab$suitable_km2[1] - 1), 1)
write.csv(area_tab, "outputs/tables/suitable_area.csv", row.names = FALSE)
area_tab$threshold_p10 <- round(th, 3)
print(area_tab)

for (p in names(ens)) writeRaster(ens[[p]], paste0("outputs/suitability_", p, ".tif"), overwrite = TRUE)

# Figure: suitability maps
df_maps <- do.call(rbind, lapply(names(ens), function(p) {
  d <- as.data.frame(ens[[p]], xy = TRUE, na.rm = TRUE); names(d)[3] <- "suit"; d$period <- p; d
}))
df_maps$period <- factor(df_maps$period, levels = c("current", "2050", "2070"),
                         labels = c("Current (1960 to 1990)", "2050", "2070"))
occ <- dat[dat$occ == 1, ]
g <- ggplot(df_maps, aes(x, y, fill = suit)) + geom_tile() +
  scale_fill_viridis_c(name = "Suitability", limits = c(0, 1)) +
  facet_wrap(~period, nrow = 1) + coord_equal() +
  labs(x = NULL, y = NULL) + theme_bw(base_size = 10) +
  theme(legend.position = "bottom")
ggsave("outputs/figures/suitability_maps.png", g, width = 10, height = 5, dpi = 200)

# Figure: change in suitable area by 2070, with novel climate hatched as grey
chg <- (ens[["2070"]] >= th) * 2 + (ens$current >= th)
d <- as.data.frame(chg, xy = TRUE, na.rm = TRUE); names(d)[3] <- "code"
d$class <- factor(d$code, levels = 0:3, labels = c("Unsuitable", "Lost by 2070", "Gained by 2070", "Stable"))
g2 <- ggplot(d, aes(x, y, fill = class)) + geom_tile() +
  scale_fill_manual(values = c("grey92", "#C0392B", "#2E86C1", "#1E8449"), name = NULL, drop = FALSE) +
  geom_point(data = occ, aes(lon, lat), inherit.aes = FALSE, size = 0.3, colour = "black") +
  coord_equal() + labs(x = "Longitude", y = "Latitude") + theme_bw(base_size = 10)
ggsave("outputs/figures/range_change_2070.png", g2, width = 6.5, height = 6, dpi = 200)
