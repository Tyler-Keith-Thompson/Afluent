# Migrating to Afluent 2.0

Afluent 2.0 is a source-breaking release. Each section names a change, what stops compiling, and
what to write instead. The 2.0.0 release notes are drawn from this file.

## Key paths are no longer made `Sendable` for everyone

Afluent 1.x declared `extension KeyPath: @unchecked @retroactive Sendable where Value: Sendable`.
That conformance is unsound: a key path can capture non-`Sendable` subscript arguments. Because it
was retroactive, it also applied to every module that imported Afluent, so code there passed key
paths across isolation boundaries without a diagnostic.

2.0 removes it. `map(_:)` on a unit of work takes `KeyPath<Success, T> & Sendable`, and
`assign(to:on:)` takes `ReferenceWritableKeyPath<Root, Success> & Sendable`.

- **Key-path literals keep working unchanged.** In Swift 6 mode the compiler infers `Sendable` for
  a literal whose captures are all `Sendable` (SE-0418), so `.map(\.name)` and
  `.assign(to: \.value, on: model)` compile as before.
- **A key path stored in a variable** must be typed as one: `let path: KeyPath<User, String> & Sendable = \.name`.
- **Code outside Afluent that relied on the conformance**, such as capturing a `KeyPath` in a
  `@Sendable` closure, now gets a `Sendable` diagnostic. Type the key path as `& Sendable`, as
  above.
