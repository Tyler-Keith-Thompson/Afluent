![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/Tyler-keith-thompson/Afluent/trunk.yml) ![GitHub](https://img.shields.io/github/license/Tyler-keith-thompson/Afluent) 
# Afluent

[Click here for documentation](https://tyler-keith-thompson.github.io/Afluent/documentation/afluent/)

Afluent is a Swift library that fills the gap between `async/await` and more reactive paradigms. As we move away from Combine,there is a need for a library that gives developers the same powerful, fluent feature set for handling sequences and tasks.

While async/await has simplified asynchronous code, it doesn't offer the full suite of operations for transforming, combining, and error-handling that Combine does. For sequences, Afluent re-exports `async-algorithms`. For tasks, which emit a single event over time, Afluent introduces a set of methods that bring you the same reactive features you've missed.

## Features
- Fluent, chainable interface
- A rich set of built-in methods like `map`, `flatMap`, `catch`, `retry`, and many more
- Built to work seamlessly with Swift's new `async/await` syntax
- Extends upon `async-algorithms` for sequences

## Installation

### Swift Package Manager

Add the Afluent package to your target dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Tyler-Keith-Thompson/Afluent.git", from: "0.0.1")
]
```


## Usage

Here's a simple example that demonstrates how to fetch and decode JSON data using Afluent.
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
.execute() // Execute the deferred task
```

In this example:

- `DeferredTask` initiates the asynchronous task.
- `map` extracts the data payload from the URLSession data task response.
- `decode` takes that data and decodes it into an array of Post objects.
- `retry` will retry the task if it encounters an error.
- `execute` runs the entire chain.
