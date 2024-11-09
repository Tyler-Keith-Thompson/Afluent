//
//  WaitUntilCondition.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/9/24.
//

import Afluent

/// Waits for some condition to proceeds, unless the specified timeout is reached, in which case an error is thrown.
func wait(until condition: @autoclosure @escaping @Sendable () async -> Bool, timeout: Duration)
    async throws
{
    try await DeferredTask {
        while await condition() == false {
            try await Task.sleep(nanoseconds: 100)
        }
    }
    .timeout(timeout)
    .execute()
}
