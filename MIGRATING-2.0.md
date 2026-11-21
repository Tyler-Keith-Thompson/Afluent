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

## `BackoffJitter` is now `Jitter`

The jitter type randomizes every wait in Afluent, not only retry backoff: `ExponentialBackoffStrategy`,
`TimerSequence` and `delay` on units of work and sequences all take it as their `jitter:` parameter.
2.0 names it for what it does. No typealias keeps the old name.

- **Write `Jitter` where you wrote `BackoffJitter`**: `let jitter: Jitter = .full(using: generator)`.
- **Arguments written as `.none`, `.full()`, `.equal()` or `.decorrelated()`** compile unchanged.

## Closures no longer capture `self` implicitly

In 1.x, the closures passed to `DeferredTask`, `map`, `flatMap`, `catch`, `handleEvents`, `retry`,
`zip` and the matching sequence operators were marked `@_implicitSelfCapture`, so they could call
`self`'s methods without writing `self.`, the way `Task { }` can. `Task` gets away with that because
it runs once and is released when it finishes. A unit of work lives as long as whoever holds it: a
stored property, `share()`, a cache. So a closure that implicitly captured `self`, stored on
`self`, was a retain cycle the compiler never pointed out.

2.0 drops the attribute, and these closures follow Swift's ordinary rules.

- **Inside a class, a closure that uses `self` now needs it spelled out.** The compiler says "call
  to method … in closure requires explicit use of 'self'". Write `[weak self]` when the unit of
  work is stored on, or outlives, `self`; write `self.` when a strong reference is intended.
- **In a struct or enum, implicit `self` keeps working** (SE-0269): a value can't form a cycle.
  In a class, a `[self]` capture list also turns implicit `self` back on, stating the strong
  capture.
- Closures still inherit the caller's actor isolation (`@_inheritActorContext`), as before.

## `SerialTaskQueue.queue(_:)` is removed

It was deprecated in 1.x in favour of `enqueue(_:)`, which does the same thing. Write
`try await queue.enqueue { … }` where you wrote `try await queue.queue { … }`.
