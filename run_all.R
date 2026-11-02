# Run the full pipeline from the repository root:  Rscript run_all.R
t0 <- Sys.time()
for (s in c("R/01_prepare_data.R", "R/02_validate.R", "R/03_project.R")) {
  message("\n== ", s); source(s, echo = FALSE)
}
message("\nDone in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
