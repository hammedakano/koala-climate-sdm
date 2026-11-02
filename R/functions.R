# Helper functions for the koala climate SDM.

# Keep one record per raster cell to reduce sampling bias from clustered records.
thin_one_per_cell <- function(xy, template) {
  cells <- terra::cellFromXY(template, as.matrix(xy[, c("lon", "lat")]))
  keep <- !is.na(cells) & !duplicated(cells)
  xy[keep, , drop = FALSE]
}

# Drop predictors so that no retained pair has |Spearman r| above the cut-off.
# Variables are considered in the order given, so put the most ecologically
# meaningful ones first.
select_uncorrelated <- function(df, vars, cutoff = 0.7) {
  keep <- character(0)
  for (v in vars) {
    if (length(keep) == 0) { keep <- v; next }
    r <- abs(stats::cor(df[[v]], df[, keep, drop = FALSE],
                        method = "spearman", use = "complete.obs"))
    if (all(r < cutoff)) keep <- c(keep, v)
  }
  keep
}

# Assign points to k folds using square spatial blocks of block_deg degrees.
# Whole blocks are allocated to folds, so nearby points never sit on both
# sides of a train and test split.
spatial_block_folds <- function(lon, lat, block_deg = 2, k = 5, seed = 1) {
  bx <- floor(lon / block_deg)
  by <- floor(lat / block_deg)
  block <- paste(bx, by)
  ub <- unique(block)
  set.seed(seed)
  fold_of_block <- sample(rep_len(seq_len(k), length(ub)))
  names(fold_of_block) <- ub
  unname(fold_of_block[block])
}

random_folds <- function(n, k = 5, seed = 1) {
  set.seed(seed)
  sample(rep_len(seq_len(k), n))
}

# Weights that give presences and background equal total weight.
balance_weights <- function(y) {
  w <- ifelse(y == 1, 1, sum(y == 1) / sum(y == 0))
  w
}

# True skill statistic at the threshold that maximises sensitivity + specificity.
tss_max <- function(y, p) {
  ths <- stats::quantile(p, probs = seq(0.01, 0.99, by = 0.01), na.rm = TRUE)
  best <- -Inf; best_t <- NA
  for (t in ths) {
    sens <- mean(p[y == 1] >= t)
    spec <- mean(p[y == 0] < t)
    s <- sens + spec - 1
    if (s > best) { best <- s; best_t <- t }
  }
  c(tss = best, threshold = unname(best_t))
}

auc <- function(y, p) {
  as.numeric(pROC::auc(pROC::roc(y, p, quiet = TRUE, direction = "<")))
}

# Model definitions. Each returns a function that predicts probability of
# presence for a data frame of predictors.
fit_model <- function(name, df, vars) {
  y <- df$occ
  w <- balance_weights(y)
  if (name == "GLM") {
    f <- stats::as.formula(paste("occ ~", paste(c(vars, paste0("I(", vars, "^2)")), collapse = " + ")))
    m <- suppressWarnings(stats::glm(f, data = df, family = stats::binomial, weights = w))
    return(function(nd) as.numeric(stats::predict(m, nd, type = "response")))
  }
  if (name == "GAM") {
    f <- stats::as.formula(paste("occ ~", paste0("s(", vars, ", k = 4)", collapse = " + ")))
    m <- mgcv::gam(f, data = df, family = stats::binomial, weights = w, method = "REML")
    return(function(nd) as.numeric(stats::predict(m, nd, type = "response")))
  }
  if (name == "RF") {
    d <- df[, c("occ", vars)]
    d$occ <- factor(d$occ, levels = c(0, 1))
    m <- ranger::ranger(occ ~ ., data = d, probability = TRUE, num.trees = 500,
                        case.weights = w, min.node.size = 5, seed = 42)
    return(function(nd) stats::predict(m, nd[, vars, drop = FALSE])$predictions[, "1"])
  }
  if (name == "BRT") {
    d <- df[, c("occ", vars)]
    m <- gbm::gbm(occ ~ ., data = d, distribution = "bernoulli", weights = w,
                  n.trees = 1500, interaction.depth = 3, shrinkage = 0.01,
                  bag.fraction = 0.75, verbose = FALSE)
    return(function(nd) gbm::predict.gbm(m, nd[, vars, drop = FALSE], n.trees = 1500, type = "response"))
  }
  stop("unknown model ", name)
}

MODELS <- c("GLM", "GAM", "RF", "BRT")

# Cross-validate every model with a given fold vector.
cross_validate <- function(df, vars, folds, scheme) {
  out <- list()
  for (mname in MODELS) {
    for (k in sort(unique(folds))) {
      tr <- df[folds != k, ]; te <- df[folds == k, ]
      if (length(unique(te$occ)) < 2) next
      pred <- fit_model(mname, tr, vars)(te)
      ts <- tss_max(te$occ, pred)
      out[[length(out) + 1]] <- data.frame(scheme = scheme, model = mname, fold = k,
                                           n_test = nrow(te), auc = auc(te$occ, pred),
                                           tss = ts[["tss"]])
    }
  }
  do.call(rbind, out)
}

# Predict a fitted model function over a SpatRaster, block by block.
predict_raster <- function(pred_fun, stack, vars) {
  terra::predict(stack[[vars]], model = list(),
                 fun = function(model, data, ...) {
                   out <- rep(NA_real_, nrow(data))
                   ok <- stats::complete.cases(data)
                   if (any(ok)) out[ok] <- pred_fun(data[ok, , drop = FALSE])
                   out
                 }, na.rm = FALSE)
}

# Cells where any predictor lies outside the range seen in training.
novelty_mask <- function(stack, df, vars) {
  rng <- sapply(vars, function(v) range(df[[v]], na.rm = TRUE))
  out <- NULL
  for (v in vars) {
    nov <- stack[[v]] < rng[1, v] | stack[[v]] > rng[2, v]
    out <- if (is.null(out)) nov else (out | nov)
  }
  names(out) <- "novel"
  out
}
