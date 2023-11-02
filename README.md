![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/Tyler-keith-thompson/Afluent/trunk.yml) ![GitHub](https://img.shields.io/github/license/Tyler-keith-thompson/Afluent) [![swift-version](https://img.shields.io/badge/swift-5.8-brightgreen.svg)](https://github.com/apple/swift) [![xcode-version](https://img.shields.io/badge/xcode-14+-brightgreen)](https://developer.apple.com/xcode/)

# Afluent

[Click here for documentation](https://tyler-keith-thompson.github.io/Afluent/documentation/afluent/)

Afluent is a Swift library that fills the gap between `async/await` and more reactive paradigms. As we move away from Combine, there is a need for a library that gives developers the same powerful, fluent feature set for handling sequences and tasks.

While async/await has simplified asynchronous code, it doesn't offer the full suite of operations for transforming, combining, and error-handling that Combine does. For sequences, you should use [swift-async-algorithms](https://github.com/apple/swift-async-algorithms). For tasks, which emit a single event over time, Afluent introduces a set of methods that bring you the same reactive features you've missed.

## Features
- Fluent, chainable interface
- A rich set of built-in methods like `map`, `flatMap`, `catch`, `retry`, and many more
- Built to work seamlessly with Swift's new `async/await` syntax

## Installation

### Swift Package Manager

Add the Afluent package to your target dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Tyler-Keith-Thompson/Afluent.git", from: "0.1.0")
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
.map(\.data) // Extract the data from the URLSession response
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

## Using `async/await`: With and Without Afluent

`async/await` has streamlined asynchronous programming in Swift, but certain operations can still be verbose or cumbersome. Afluent fills this gap, making complex tasks more concise and readable. Let's delve into a comparison:

### Without Afluent

Fetching, decoding JSON data, and implementing retries using just `async/await`:

```swift
func fetchPosts(retryCount: Int = 3) async throws -> [Post] {
    let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
    var currentAttempt = 0
    
    while currentAttempt < retryCount {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let posts = try decoder.decode([Post].self, from: data)
            return posts
        } catch {
            currentAttempt += 1
            if currentAttempt == retryCount {
                throw error
            }
            // Optionally, add a delay or other logic before retrying
        }
    }
    throw URLError(.cannotConnectToHost) // This is a generic error; you can replace it with a more specific one if needed.
}

do {
    let posts = try await fetchPosts()
    print(posts)
} catch {
    print("Error fetching posts after multiple retries: \(error)")
}```

### With Afluent
Fetching, decoding JSON data, and implementing retries using Afluent:

```swift
let posts = try await DeferredTask {
    try await URLSession.shared.data(from: URL(string: "https://jsonplaceholder.typicode.com/posts")!)
}
.map(\.data) // Extract the data from the URLSession response
.decode(type: [Post].self, decoder: JSONDecoder()) // Decode the JSON into an array of `Post` objects
.retry(3) // Automatically retry the request up to 3 times if it fails
.execute() // Execute the deferred task
```

### Why Afluent is Better

- **Conciseness**: Afluent's chainable interface reduces boilerplate, making complex operations more concise.
  
- **Built-in Error Handling**: Afluent's `retry` method elegantly handles retries, eliminating the need for manual loops and error checks.
  
- **Rich Set of Operations**: Beyond retries, Afluent offers operations like `map`, `flatMap`, `filter`, and more, enriching the `async/await` experience.

- **Readability**: Afluent's fluent design makes the code's intent clearer, enhancing maintainability.

By enhancing `async/await` with a rich set of operations, Afluent simplifies and elevates the asynchronous coding experience in Swift.

<details>
  <summary><strong>Adopting Afluent: A Guide for Combine Users</strong></summary>

If you're familiar with Combine and are looking to transition to Afluent, this guide will help you understand the similarities and differences, making your adoption process smoother. Afluent deliberately uses an API that is very similar to Combine, making the transition easier.

### Key Differences:

1. **Asynchronous Units vs. Publishers**: In Combine, you work with `Publishers`. In Afluent, the primary unit is an `AsynchronousUnitOfWork`.

2. **Single Emission**: Unlike many Combine publishers that can emit multiple values over time, `AsynchronousUnitOfWork` in Afluent represents a single asynchronous operation.

3. **Built for `async/await`**: Afluent is designed around Swift's `async/await` syntax, making it a natural fit for the new concurrency model.

### Mapping Combine to Afluent:

- **`Just` and `Future`**: In Combine, you might use `Just` for immediate values and `Future` for asynchronous operations. In Afluent, `Just` and `Future` are replaced by `DeferredTask`.

- **`map`, `flatMap`**: These operators exist in both Combine and Afluent with similar functionality.

- **`catch` and `retry`**: Afluent provides these methods, similar to Combine, to handle errors and retry operations.

- **`assign`**: Afluent also has an `assign` operator, similar to Combine's.

- **`sink` and `subscribe`**: While Combine uses `sink`, Afluent offers `subscribe` which returns an `AnyCancellable`, and `run()` to create a new task in the background. Additionally, Afluent provides an `execute()` method which is `async throws` allowing you to await the result, and a `result` property, akin to `Task`.

### Transition Tips:

1. **Understand the Scope**: Afluent replaces Combine only where Combine would be operating over a single value. For handling multiple values over time, consider using async algorithms.

2. **Embrace the Differences**: Afluent does not have a customizable `Failure` type like publishers in Combine. Every `AsynchronousUnitOfWork` can throw a `CancellationError`, making the failure type always `Error`.

3. **Use Documentation**: Afluent's [documentation](https://tyler-keith-thompson.github.io/Afluent/documentation/afluent/) is a valuable resource. Refer to it often as you transition.

4. **Join the Community**: Engage with other Afluent users on GitHub. Sharing experiences and solutions can be beneficial.

Remember, while Afluent and Combine have similarities, they are distinct libraries with their own strengths. Embrace the learning curve, and soon you'll be leveraging the power of Afluent in your projects.

</details>


<details>
  <summary><strong>Frequently Asked Questions (FAQs)</strong></summary>

  **1. What is the primary purpose of Afluent?**  
  Afluent is designed to bridge the gap between `async/await` and more reactive paradigms. It provides a fluent interface for handling tasks, offering powerful features for transforming, combining, and error-handling.

  **2. How does Afluent compare to Combine?**  
  While both Afluent and Combine provide reactive features, Afluent is tailored for tasks that emit a single event over time. It's designed to work seamlessly with Swift's new `async/await` syntax, offering a rich set of operations similar to Combine but optimized for the new concurrency model.

  **3. Why should I use Afluent over Combine?**  
  If you're transitioning away from Combine and looking for a library that offers a similar feature set but is built around `async/await`, Afluent is a great choice. It provides a fluent, chainable interface with methods like `map`, `flatMap`, `catch`, `retry`, and more.

  **4. How do I integrate Afluent into my project?**  
  You can integrate Afluent using the Swift Package Manager. Add the Afluent package URL to your target dependencies in `Package.swift`.

  **5. Can I use Afluent for sequences?**  
  Afluent is primarily designed for tasks, which emit a single event over time. For sequences, consider using [swift-async-algorithms](https://github.com/apple/swift-async-algorithms).

  **6. How does error handling work in Afluent?**  
  Afluent provides several methods for error handling, such as `catch` and `retry`. You can transform errors, handle them, or even specify conditions for retrying tasks upon failure.

  **7. Are there any examples or tutorials available for Afluent?**  
  Yes, the README provides a simple example demonstrating how to fetch and decode JSON data using Afluent. For more detailed documentation, you can [click here](https://tyler-keith-thompson.github.io/Afluent/documentation/afluent/).

  **8. How can I contribute to Afluent or report issues?**  
  Afluent is hosted on GitHub. You can fork the repository, make changes, and submit a pull request. For reporting issues, open a new issue on the GitHub repository with a detailed description.

</details>
