////
////  AUOWCache+CancelAndRetry.swift
////
////
////  Created by Annalise Mariottini on 12/17/24.
////
//
//import Foundation
//
//extension AUOWCache {
//    public struct CancelAndRetry: AUOWCacheStrategy {
//        public func handle<A: AsynchronousUnitOfWork>(
//            unitOfWork: A, keyedBy key: Int, storedIn cache: AUOWCache
//        ) -> AnyAsynchronousUnitOfWork<A.Success> {
//            if let cachedWork = cache.retrieve(keyedBy: key) {
//                cachedWork.cancel()
//            }
//            return cache.create(
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
//extension AUOWCacheStrategy where Self == AUOWCache.CancelAndRetry {
//    /// This strategy indicates that any existing work should be cancelled before restarting the upstream work again.
//    public static var cancelAndRestart: Self { AUOWCache.CancelAndRetry() }
//}
