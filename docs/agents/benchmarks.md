# Judging a speed change

Judge a speed change by `just bench-simulated-compare --target <Module>Benchmarks`: its
instruction, cache-miss and branch counts don't move when the machine is busy, as wall clock
does. Allocation counts and absolute times still come from `just bench`, on a quiet machine.
Re-record the `simulated` baseline for the targets a change touches
(`just bench-simulated --target X`) and commit it with the change. Its `results.json` is
pretty-printed with sorted keys, one benchmark's entry on lines of its own, and a benchmark
whose instruction and malloc counts moved less than compare's 5% threshold keeps its recorded
entry. So the file changes only where a benchmark did, and pull requests that change different
benchmarks of one target merge without a conflict. Resolve a conflict by re-recording after
the merge, never by hand. A benchmark whose mallocs drop to zero, or that was measured over a
different number of iterations, counts as moved. Harness options (`--iterations`, `--filter`)
measure uncached and write the same format, keeping the entries that didn't move. To rewrite
every entry (a change aimed at cache misses alone), delete the file first.
