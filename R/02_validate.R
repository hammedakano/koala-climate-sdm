# Compare random and spatial block cross-validation for four model types.
source("config.R"); source("R/functions.R")
suppressPackageStartupMessages({ library(terra); library(ggplot2) })
md <- readRDS("outputs/model_data.rds"); dat <- md$dat; vars <- md$vars

f_rand <- random_folds(nrow(dat), K_FOLDS, SEED)
f_spat <- spatial_block_folds(dat$lon, dat$lat, BLOCK_DEG, K_FOLDS, SEED)

cv <- rbind(cross_validate(dat, vars, f_rand, "Random"),
            cross_validate(dat, vars, f_spat, "Spatial block"))
write.csv(cv, "outputs/tables/cv_by_fold.csv", row.names = FALSE)

summ <- aggregate(cbind(auc, tss) ~ scheme + model, cv, function(x) round(mean(x), 3))
sdv  <- aggregate(cbind(auc, tss) ~ scheme + model, cv, function(x) round(sd(x), 3))
names(sdv)[3:4] <- c("auc_sd", "tss_sd")
summ <- merge(summ, sdv)
write.csv(summ, "outputs/tables/cv_summary.csv", row.names = FALSE)
print(summ)

p <- ggplot(cv, aes(model, auc, fill = scheme)) +
  geom_boxplot(width = 0.6, outlier.shape = NA, alpha = 0.8) +
  geom_point(position = position_jitterdodge(jitter.width = 0.1, dodge.width = 0.6), size = 1.2) +
  scale_fill_manual(values = c(Random = "#9AA5B1", `Spatial block` = "#2F6F8F")) +
  labs(x = NULL, y = "AUC on held-out fold", fill = "Cross-validation") +
  theme_bw(base_size = 11) + theme(legend.position = "top")
ggsave("outputs/figures/cv_random_vs_spatial.png", p, width = 6, height = 4, dpi = 200)

# Fold layout map
fl <- dat; fl$fold <- factor(f_spat)
p2 <- ggplot(fl[order(fl$occ), ], aes(lon, lat, colour = fold, shape = factor(occ))) +
  geom_point(size = 0.6) + coord_equal() +
  scale_shape_manual(values = c(`0` = 46, `1` = 17), labels = c("Background", "Presence"), name = NULL) +
  labs(x = "Longitude", y = "Latitude", colour = "Fold") + theme_bw(base_size = 10)
ggsave("outputs/figures/spatial_folds.png", p2, width = 6, height = 5, dpi = 200)
