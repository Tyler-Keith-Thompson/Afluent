////
////  AUOWCache+CacheUntilCompletionOrCancellation.swift
////
////
////  Created by Annalise Mariottini on 12/17/24.
////
//
//import Foundation
//
//extension AUOWCache {
//    public struct CacheUntilCompletionOrCancellation: AUOWCacheStrategy {
//        public func handle<A: AsynchronousUnitOfWork>(
//            unitOfWork: A, keyedBy key: Int, storedIn cache: AUOWCache
//        ) -> AnyAsynchronousUnitOfWork<A.Success> {
//            cache.retrieveOrCreate(
//                unitOfWork: unitOfWork.handleEvents(
//                    receiveOutput: { [weak cache] _ in
//                        cache?.clearAsynchronousUnitOfWork(withKey: key)
//                    },
//                    receiveError: { [weak cache] _ in
//                        cache?.clearAsynchronousUnitOfWork(withKey: key)
//                    },
//                    receiveCancel: { [weak cache] in
//                        cache?.clearAsynchronousUnitOfWork(withKey: key)
//                    }
//                ).share(),
//                keyedBy: key
//            ).eraseToAnyUnitOfWork()
//        }
//    }
//}
//
//extension AUOWCacheStrategy where Self == AUOWCache.CacheUntilCompletionOrCancellation {
//    /// With the `.cacheUntilCompletionOrCancellation` strategy, the cache
//    /// retains the result until the unit of work completes or is cancelled.
//    public static var cacheUntilCompletionOrCancellation: Self {
//        AUOWCache.CacheUntilCompletionOrCancellation()
//    }
//}
