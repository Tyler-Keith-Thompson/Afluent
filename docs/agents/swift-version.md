# Raising the Swift floor

Raise the Swift floor (a dependency's manifest needs a newer Swift): set `SWIFT` (every
manifest's tools version, CI's and the Docker image's Swift, the minimum the docs state) and
`SWIFT_TOOLCHAIN` (the swift.org release swiftly installs where Xcode's toolchain falls short)
in `scripts/modules.py`, then `just modules`. It writes them into the generated manifests and
replaces the previous ones in every other file that names them (`SWIFT_SITES`), from the record
in `tools/swift_version.bzl`. Never edit a version in those files by hand. `just template-update`
keeps the project's versions, and says when the template's have passed them.
`just wasi-test` builds with `SWIFT_TOOLCHAIN` and its WebAssembly SDK.
CI needs a `swift-bazel` image of the new version, published from the project template's
`ci-image/build.sh`.

## The CI image

CI's Bazel jobs run in `ghcr.io/tyler-keith-thompson/swift-bazel:<swift>-<bazel>`, Swift with the
Bazel in `.bazelversion` already in it, built by the project template's `ci-image/build.sh`.
Changing `.bazelversion` or the workflows' Swift version means a new tag from there. The package
is private; a repository pulls it once added under its Manage Actions access.
