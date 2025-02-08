# Rowhammer Experiment

This is the main Rowhammer experiment to determine the hammer count on DDR5.

## Components

1. `cnXXX.json`: These configuration files contains the rows to be hammered
and the range of tested hammer counts. They are read by `make_images.sh`
and `run.sh`. For machines where SPD readout is broken, you also have
to specify the DIMM size. Otherwise that is done automatically.

2. `make_images.sh`: This compiles the Memtest images with each possible
combination of hammer count and row. It must be started first.

3. `run.sh`: This runs the actual Rowhammer experiment and decides which
of the Memtest images gets sent to the PXE server. It retrieves the data
and stores it in its `$DATA_DIR`.

## Setup
1. Make sure you performed the setup described in the top-level README, i.e.,
verify that all nodes are linked to their injection controller in
`/etc/hosts` and that the TFTP/PXE setup is working.
2. Clone `memtest` here and rename it to `memtest-cnXXX`.
Do this for every experiment machine.
3. Check notification settings (e-mail), data directory and experiment name in `run.sh`.
4. Install dialog `apt-get install dialog` for TUI dialogs or remove that functionality from `make_images.sh`

## Run
1. Adjust `cnXXX.json` to match the desired rows/hammer counts.
2. Start a tmux session and run `./make_images.sh cnXXX`.
3. In another tmux pane, run `./run.sh cnXXX`.

(Repeat for every experiment machine)

## Analysis
Always use the "raw" data, i.e., the "expected X, got Y" data bytes.
Do not rely on the number of bit errors reported by Memtest.
This does not use `__builtin_popcount` because of an unresolved linker
issue and it does not check whether the errors are due to Rowhammer, or
due to complete data corruption (which happens occasionally).
Calculate the number of bitflips in post processing and add a plausibility
check.
