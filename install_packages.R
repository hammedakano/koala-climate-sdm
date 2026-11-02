pkgs <- c("terra", "ranger", "mgcv", "gbm", "pROC", "ggplot2", "geodata")
install.packages(setdiff(pkgs, rownames(installed.packages())))
