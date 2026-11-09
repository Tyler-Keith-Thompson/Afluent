//
//  PlatformLock.swift
//  Afluent
//

#if canImport(Darwin)
    import Darwin
#endif
import Synchronization

/// State that one critical region at a time can read and change.
///
/// It is a `Synchronization.Mutex` wherever the OS has one: macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2 and
/// later, and Linux. Older Apple OSes get an `os_unfair_lock` beside the state in one allocation. The tier is chosen
/// once, in `init`.
struct CriticalState<State>: Sendable {
    private var storage: any AnyObject & Sendable

    init(_ initial: consuming sending State) {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            storage = MutexStorage(initial)
        } else {
            #if canImport(Darwin)
                storage = UnfairLockStorage.make(initial)
            #else
                preconditionFailure("Every non-Apple platform has Mutex")
            #endif
        }
    }

    /// Runs `body` with exclusive access to the state.
    ///
    /// - Complexity: O(1) plus the cost of `body`.
    @inline(__always)
    func withCriticalRegion<R>(_ body: (inout sending State) throws -> sending R) rethrows -> sending R {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            assert(storage is MutexStorage<State>)
            return try unsafeDowncast(storage, to: MutexStorage<State>.self).mutex.withLock(body)
        } else {
            #if canImport(Darwin)
                assert(storage is UnfairLockStorage<State>)
                return try unsafeDowncast(storage, to: UnfairLockStorage<State>.self).withLock(body)
            #else
                preconditionFailure("Every non-Apple platform has Mutex")
            #endif
        }
    }

    /// Whether this is the only value that refers to the state.
    mutating func isKnownUniquelyReferenced() -> Bool {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            return isKnownUniquelyReferenced(as: MutexStorage<State>.self)
        } else {
            #if canImport(Darwin)
                return isKnownUniquelyReferenced(as: UnfairLockStorage<State>.self)
            #else
                preconditionFailure("Every non-Apple platform has Mutex")
            #endif
        }
    }

    /// Checks the storage as the tier's class. `isKnownUniquelyReferenced(&storage)` on the existential checks a copy
    /// in unoptimized Swift 6 builds, which is never unique; the slot holds one class reference either way.
    private mutating func isKnownUniquelyReferenced<Storage: AnyObject>(as _: Storage.Type) -> Bool {
        assert(storage is Storage)
        return withUnsafeMutablePointer(to: &storage) { slot in
            slot.withMemoryRebound(to: Storage.self, capacity: 1) { Swift.isKnownUniquelyReferenced(&$0.pointee) }
        }
    }
}

/// The ``CriticalState`` tier for OSes with `Mutex`.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
final class MutexStorage<State>: Sendable {
    let mutex: Mutex<State>

    init(_ initial: consuming sending State) {
        mutex = Mutex(initial)
    }
}

#if canImport(Darwin)
    /// The ``CriticalState`` tier for Apple OSes without `Mutex`: the state and an `os_unfair_lock` in one buffer,
    /// which keeps the lock at a fixed address.
    ///
    /// It is `@unchecked Sendable` because every access to the state goes through ``withLock(_:)``, which holds the
    /// lock. `ManagedBuffer` opts out of `Sendable`, so the buffer is held rather than subclassed.
    final class UnfairLockStorage<State>: @unchecked Sendable {
        /// The lock as the header and the state as the one element; `deinit` deinitializes the state.
        private final class Buffer: ManagedBuffer<os_unfair_lock, State> {
            deinit {
                _ = withUnsafeMutablePointerToElements { $0.deinitialize(count: 1) }
            }
        }

        private let buffer: ManagedBuffer<os_unfair_lock, State>
        private let lock: UnsafeMutablePointer<os_unfair_lock>
        private let state: UnsafeMutablePointer<State>

        private init(_ initial: consuming sending State) {
            let buffer = Buffer.create(minimumCapacity: 1) { _ in os_unfair_lock() }
            self.buffer = buffer
            // The pointers stay valid while `buffer`, which this object holds, is alive.
            lock = buffer.withUnsafeMutablePointerToHeader { $0 }
            state = buffer.withUnsafeMutablePointerToElements { $0 }
            state.initialize(to: initial)
        }

        static func make(_ initial: consuming sending State) -> UnfairLockStorage<State> {
            UnfairLockStorage(initial)
        }

        func withLock<R>(_ body: (inout sending State) throws -> sending R) rethrows -> sending R {
            os_unfair_lock_lock(lock)
            defer { os_unfair_lock_unlock(lock) }
            return try body(&state.pointee)
        }
    }
#endif
