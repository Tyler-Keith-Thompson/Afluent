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

## `AnyAsyncIterator` is no longer `Sendable`

In Afluent 1.x, `AnyAsyncIterator` (the iterator of `AnyAsyncSequence`) claimed `Sendable`. It
honoured that claim with a lock around reading and writing the erased iterator, but not around
`next()`. So two tasks calling `next()` on copies of one iterator could both read the same
position, and one update was lost.

2.0 marks the conformance unavailable, as with other iterators: iterate an `AnyAsyncIterator`
from one task at a time. `AnyAsyncSequence` itself is still `Sendable`, so share the sequence and
let each task call `makeAsyncIterator()`. Each `next()` is also cheaper: it is one dynamic call
with no lock and no cast.

- **Code that sends an `AnyAsyncIterator` to another task**, or stores one in a `Sendable` type,
  now gets a `Sendable` diagnostic. Send the `AnyAsyncSequence` instead and make the iterator
  where it is used.
