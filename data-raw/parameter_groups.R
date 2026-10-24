# Build netlogoDuck::parameter_groups (rev13) and
# netlogoDuck::parameter_groups_rev12 datasets.
# Run with: Rscript data-raw/parameter_groups.R
# (from netlogoDuck/ as working directory)

pg_rev12 <- data.frame(
  parameter = c(
    # Group 1: population & spatial structure
    "agent-density", "vision", "neighborhood-type", "mobility-on", "move-radius",
    # Group 2: learning rule
    "learning-strategy", "conformist-weight", "conformity-exponent",
    "minimum-observations", "initial-hunch-bias",
    # Group 3: transmission channel
    "accept-prob", "transmission-fidelity", "transmission-noise", "tie-handling",
    # Group 4: resource / institutional capacity
    "overload-threshold", "capacity-regen", "capacity-growth-per-teach",
    "max-capacity-limit",
    # Group 5: innovation & decision
    "innovate-prob", "innovation-noise", "adoption-threshold"
  ),
  group = c(
    rep("population_spatial", 5L),
    rep("learning_rule", 5L),
    rep("transmission", 4L),
    rep("capacity", 4L),
    rep("innovation_decision", 3L)
  ),
  group_label = c(
    rep("Population & spatial structure", 5L),
    rep("Learning rule", 5L),
    rep("Transmission channel", 4L),
    rep("Resource / institutional capacity", 4L),
    rep("Innovation & decision", 3L)
  ),
  widget = c(
    rep("slider", 4L), "switch",   # agent-density..vision sliders, mobility-on switch, move-radius slider
    "chooser", "slider", "slider", "slider", "chooser",
    "slider", "slider", "slider", "chooser",
    "slider", "slider", "slider", "slider",
    "slider", "slider", "slider"
  ),
  description = c(
    # population & spatial
    "Number of agents in the population (density of the lattice).",
    "Radius (in patches) over which agents observe their neighbors.",
    "Spatial neighborhood topology: Moore / Von Neumann / ...",
    "Whether agents can move during the simulation.",
    "Radius over which mobile agents move.",
    # learning rule
    "Learning rule: Success, Conformist, or Hybrid.",
    "Mixing weight between success and conformity signals in Hybrid mode (0 = pure success, 1 = pure conformity).",
    "Nonlinear exponent applied to observed frequency in Conformist learning (>1 amplifies the majority).",
    "Minimum number of visible agents using a strategy before its payoff evidence counts.",
    "Initial distribution of hunch beliefs across the population.",
    # transmission
    "Teacher acceptance probability (percent): probability a winner accepts a requester.",
    "Fidelity of transmitted hunch value (1 = exact copy, 0 = no influence).",
    "Standard deviation of Gaussian noise added to transmitted hunch.",
    "How tied requests among multiple teachers are handled (retain / sample).",
    # capacity
    "Number of simultaneous requests a winner can receive before overload.",
    "Rate at which a teacher's capacity regenerates each tick.",
    "Growth in capacity per successful teaching event.",
    "Upper bound on any agent's teaching capacity.",
    # innovation & decision
    "Probability per tick that an agent innovates (mutates) instead of copying.",
    "Noise (sd) added to an innovated hunch value.",
    "Threshold above which a strategy is adopted."
  ),
  stringsAsFactors = FALSE
)

stopifnot(length(unique(pg_rev12$parameter)) == nrow(pg_rev12))
stopifnot(all(table(pg_rev12$group) > 0))
stopifnot(nrow(pg_rev12) == 21L)

parameter_groups_rev12 <- pg_rev12

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
usethis::use_data(parameter_groups, parameter_groups_rev12, overwrite = TRUE)
