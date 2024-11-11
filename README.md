![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/Tyler-keith-thompson/Afluent/trunk.yml) ![GitHub](https://img.shields.io/github/license/Tyler-keith-thompson/Afluent) [![swift-version](https://img.shields.io/badge/swift-5.8-brightgreen.svg)](https://github.com/apple/swift) [![xcode-version](https://img.shields.io/badge/xcode-14+-brightgreen)](https://developer.apple.com/xcode/)

# Afluent
![AfluentLogo](https://github.com/Tyler-Keith-Thompson/Afluent/assets/33705774/ba1b24b2-cd70-4c9c-824a-e89ee89348a8)


Documentation:
- [Afluent](https://tyler-keith-thompson.github.io/Afluent/documentation/afluent/)
- [AfluentTesting](https://tyler-keith-thompson.github.io/Afluent/documentation/afluenttesting/)

Afluent is a Swift library that lives between [swift-async-algorithms](https://github.com/apple/swift-async-algorithms) and foundation, adding reactive operators to async/await and AsyncSequence. The goal of Afluent is to provide a reactive friendly operator style API to enhance Apple's offerings. As a consequence, Afluent will add features that Apple has either already built or is actively building.
While async/await has simplified asynchronous code, it doesn't offer the full suite of operations for transforming, combining, and error-handling that Combine does. Afluent deliberately keeps as much of the Combine API as makes sense to make moving from Combine to Afluent much easier. As a consequence, you may have some minor symbol collisions when you import both Combine and Afluent in the same file.

## Features
- Fluent, chainable interface
- A rich set of built-in methods like `map`, `flatMap`, `catch`, `retry`, and many more
- Built to work seamlessly with Swift's new `async/await` syntax
- Test utilities to facilitate common `async/await` testing needs

## Installation

### Swift Package Manager

Add the Afluent package to your target dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Tyler-Keith-Thompson/Afluent.git", from: "0.3.0")
]
```

Then, add the Afluent target as a dependency to your package targets:

```swift
dependencies: [
    .product(name: "Afluent", package: "Afluent"),
]
```

For test targets where you'd like to use Afluent's testing utilities, add the AfluentTesting target as a dependency:

```swift
dependencies: [
    .product(name: "AfluentTesting", package: "Afluent"),
]
```

## Usage

### AsynchronousUnitOfWork
While Combine always deals with sequences, `async/await` offers tasks. Tasks differ from sequences in that they will only ever emit one value eventually, a sequence may emit zero or more values eventually. This means instead of the Combine approach of dealing with a sequence of one element, you can use tasks for a more guaranteed execution. This is very ergonomic when working with network requests, check out the following example:
```swift
struct Post: Codable {
    let userId: UInt
    let id: UInt
    let title: String
    let body: String
}

let posts = try await DeferredTask {
    try await URLSession.shared.data(from: URL(string: "https://jsonplaceholder.typicode.com/posts")!)
}
.map(\.0) // Extract the data from the URLSession response
.decode(type: [Post].self, decoder: JSONDecoder()) // Decode the JSON into an array of `Post` objects
.retry() // Automatically retry the request if it fails
.execute() // Execute the deferred task and await the result.
//.run() // Run could've also been used to execute the task without awaiting the result.
```

In this example:

- `DeferredTask` initiates the asynchronous task.
- `map` extracts the data payload from the URLSession data task response.
- `decode` takes that data and decodes it into an array of Post objects.
- `retry` will retry the task if it encounters an error.
- `execute` runs the entire chain and awaits the result.
- `run` runs the entire chain without awaiting the result.

### AsyncSequence
There are times when you need sequence mechanics and Afluent is there to help! Here's the same example, but converted to an AsyncSequence with all the same operators.
```swift
let posts = try await DeferredTask {
    try await URLSession.shared.data(from: URL(string: "https://jsonplaceholder.typicode.com/posts")!)
}
.toAsyncSequence() // Convert this to an AsyncSequence, thus enabling Swift Async Algorithms and standard library methods
.map(\.0) // Extract the data from the URLSession response
.decode(type: [Post].self, decoder: JSONDecoder()) // Decode the JSON into an array of `Post` objects
.retry() // Automatically retry the request if it fails
.first() // Get the first result from the sequence
```

### Why Afluent is Better than just using `async/await`

- **Conciseness**: Afluent's chainable interface reduces boilerplate, making complex operations more concise.
  
- **Built-in Error Handling**: Afluent's `retry` method elegantly handles retries, eliminating the need for manual loops and error checks.
  
- **Rich Set of Operations**: Beyond retries, Afluent offers operations like `map`, `flatMap`, and over 20 more, enriching the `async/await` experience.

- **Readability**: Afluent's fluent design makes the code's intent clearer, enhancing maintainability.

By enhancing `async/await` with a rich set of operations, Afluent simplifies and elevates the asynchronous coding experience in Swift.

<details>
  <summary><strong>Adopting Afluent: A Guide for Combine Users</strong></summary>

If you're familiar with Combine and are looking to transition to Afluent, this guide will help you understand the similarities and differences, making your adoption process smoother. Afluent deliberately uses an API that is very similar to Combine, making the transition easier.

### Key Differences:

1. **Asynchronous Units of Work vs. Publishers vs. AsyncSequence**: 
- In Combine, you work with `Publishers`. 
- In Afluent, there are 2 choices. 
    - For an asynchronous operation that emits one value eventually, use `AsynchonousUnitOfWork`. This is perfect for network requests or other "one-time" async operations and comes with all the operators that Combine comes with (including `share`).
    - For async operations that emit multiple values over time, use `AsyncSequence` and simply rely on Afluent operators that extend both the standard library and Apple's open source Swift Async Algorithms package. This does not have 100% parity with Combine on its own, but almost entirely gives the same operators as Combine when combined with both of Apple's libraries.

2. **Built for `async/await`**: Afluent is designed around Swift's `async/await` ans `AsyncSequence` syntax, making it a natural fit for the new concurrency model.

### Mapping Combine to Afluent:

- **`Just` and `Future`**: In Combine, you might use `Just` for immediate values and `Future` for asynchronous operations.
    - For an `AsynchronousUnitOfWork` `DeferredTask` will replace both `Just` and `Future`.
    - For `AsyncSequence` Afluent offers a `Just` sequence and the standard library's `AsyncStream` or `AsyncThrowingStream` provide the same mechanics as Combine's `Future`.

- **`map`, `flatMap`, `filter`, `merge`, `zip`, etc...**:
    - For an `AsynchronousUnitOfWork` the operators that make sense are all available within Afluent directly. For example, `map`, and `flatMap` make perfect sense, but `filter` doesn't, because an `AsynchronousUnitOfWork` only ever emits one value.
    - For an `AsyncSequence` these operators are almost entirely provided by either Foundation or AsyncAlgorithms. 

- **`catch` and `retry`**: Afluent provides these methods, similar to Combine, to handle errors and retry operations.

- **`assign`**: Afluent also has an `assign` operator, similar to Combine's.

- **`sink` and `subscribe`**:
    - For an `AsynchronousUnitOfWork` `subscribe` is the method Afluent provides. It's deliberately a little different than `sink` as only one value will be emitted. However, they serve the same general purpose.
    - For an `AsyncSequence` Afluent provides a `sink` method that works the same way Combine's does.

### Transition Tips:

1. **Understand the Scope**:
    - If you only emit one value eventually, Afluent can completely replace Combine. You'll probably use a `DeferredTask` and go from there.
    - If you emit multiple values over time, you'll probably want to use a combination of Afluent, Foundation, and AsyncAlgorithms to supplement Combine. With all 3 of these you can get the majority of behavior Combine offered.

2. **Embrace the Differences**: Afluent does not have a customizable `Failure` type like publishers in Combine. Every `AsynchronousUnitOfWork` can throw a `CancellationError`, making the failure type always `Error`.

3. **Use Documentation**: Afluent's [documentation](https://tyler-keith-thompson.github.io/Afluent/documentation/afluent/) is a valuable resource. Refer to it often as you transition.

4. **Join the Community**: Engage with other Afluent users on GitHub. Sharing experiences and solutions can be beneficial.

Remember, while Afluent and Combine have similarities, they are distinct libraries with their own strengths. Embrace the learning curve, and soon you'll be leveraging the power of Afluent in your projects.

</details>


<details>
  <summary><strong>Frequently Asked Questions (FAQs)</strong></summary>
  
  **1. How can I contribute to Afluent or report issues?**  
  Afluent is hosted on GitHub. You can fork the repository, make changes, and submit a pull request. For reporting issues, open a new issue on the GitHub repository with a detailed description.

  **2. Why isn't there a `share` operator for sequences?**  
  Afluent strives to not interfere with ongoing work from Apple. The desire for multicast or share functionality has been strong in the community and the [swift-async-algorithms team is working on a broadcast operator to help](https://github.com/apple/swift-async-algorithms). It's also worth noting that solving this problem is non-trivial, like timing operations. As a consequence, the Afluent team prefers to leave that complexity to Apple to manage.

  **3. If you won't build `share` why did you build `Deferred`?**  
  It's worth noting that the async algorithms team introduced a `deferred` global function that operates similarly to Afluent's `Deferred` sequence. The reason Afluent implemented this was because of the ease of implementation coupled with the more immediate need. At the time of writing Async Algorithms will not release `deferred` until v1.1 and Afluent can fill the gap easily until that happens. 

  **4. Why is it Afluent and not Affluent?**
  Async/Await + Fluent == Afluent

</details>