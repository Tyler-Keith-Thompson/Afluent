# Swift sources generated at build time

Generate a Swift source at build time (overloads for each arity, tables from a data file): the
generator is a Bazel executable that writes the source to standard output, or, given output
names, gets their paths before a `--`. List it in `GENERATED_SOURCES` under the module or test
target (`{"<Module>": [("<Name>", "//tools/<generator>", [<input labels>], [])]}`), create an
empty `Generated/<Name>.swift` in the target's directory, then `just modules` and `just sources`.
Bazel compiles the generator's output; SwiftPM compiles the copy under `Generated/`, which
`just sources` rewrites and `<Name>_test` fails on while it differs from what the generator
writes. Commit the copy, and run `just sources` after a change to the generator or its inputs.
`check()` refuses a copy that doesn't exist, and a speed-reliant, iOS or firmware target.
Simulated benchmarks measure the generator's output, at the copy's path.
