//
//  AUOWCache+Strategy.swift
//
//
//  Created by Annalise Mariottini on 12/17/24.
//

import Foundation

/// ``AUOWCacheStrategy`` represents the available caching strategies for the ``AUOWCache``.
public protocol AUOWCacheStrategy {
    /// A caching strategy implementation that handles some work, keyed by some hashed key, which may be stored in or retrieved from the passed cache.
    func handle<A: AsynchronousUnitOfWork>(
        unitOfWork: A, keyedBy key: Int, storedIn cache: AUOWCache
    ) -> AnyAsynchronousUnitOfWork<A.Success>
}
