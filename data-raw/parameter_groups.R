# Build the netlogoDuck::parameter_groups dataset.
# Run with: Rscript data-raw/parameter_groups.R
# (from netlogoDuck/ as working directory)

parameter_groups <- data.frame(
  parameter = c(
    "agent-density", "vision", "accept-prob", "transmission-fidelity",
    "transmission-noise", "learning-strategy"
  ),
  group = c(
    "population_spatial", "population_spatial", "transmission",
    "transmission", "transmission", "learning_rule"
  ),
  group_label = c(
    "Population & spatial structure", "Population & spatial structure",
    "Transmission channel", "Transmission channel", "Transmission channel",
    "Learning rule"
  ),
  widget = c("slider", "slider", "slider", "slider", "slider", "chooser"),
  description = c(
    "Number of agents in the population (density of the lattice).",
    "Radius (in patches) over which agents observe their neighbors.",
    "Teacher acceptance probability (percent).",
    "Fidelity of transmitted hunch value (1 = exact copy, 0 = no influence).",
    "Standard deviation of Gaussian noise added to transmitted hunch.",
    "Learning rule: Success or Conformist."
  ),
  stringsAsFactors = FALSE
)

stopifnot(length(unique(parameter_groups$parameter)) == nrow(parameter_groups))
stopifnot(nrow(parameter_groups) == 6L)
usethis::use_data(parameter_groups, overwrite = TRUE)
