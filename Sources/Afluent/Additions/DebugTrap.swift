//
//  DebugTrap.swift
//  Afluent
//

import Foundation

/// Stops the program where a debugger can inspect it: `SIGTRAP`, or a WebAssembly trap on WASI.
///
/// The breakpoint operators call it when their condition holds. Without a debugger attached, the
/// process ends.
@_transparent @usableFromInline func debugTrap() {
    #if os(WASI)
        // WASI has no signals, so there is no SIGTRAP to raise; a trap is what a debugger attached
        // to a WebAssembly runtime stops on. Leaving the breakpoint operators out on WASI was
        // rejected: code that uses them while debugging would stop compiling there. Making them do
        // nothing was rejected too: it would silently skip a stop the caller asked for.
        fatalError("Afluent breakpoint")
    #else
        raise(SIGTRAP)
    #endif
}
