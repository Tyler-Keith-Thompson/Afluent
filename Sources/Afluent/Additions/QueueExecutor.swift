//
//  QueueExecutor.swift
//
//
//  Created by Annalise Mariottini on 10/10/24.
//

import Foundation

#if swift(>=6)
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public final class QueueExecutor: TaskExecutor, Sendable, CustomStringConvertible {
        let queue: DispatchQueue

        init(queue: DispatchQueue) {
            self.queue = queue
        }

        public func enqueue(_ job: consuming ExecutorJob) {
            let job = UnownedJob(job)
            queue.async {
                job.runSynchronously(on: self.asUnownedTaskExecutor())
            }
        }

        public var description: String {
            "\(Self.self)\(ObjectIdentifier(self))"
        }

        fileprivate static let main = QueueExecutor(queue: .main)
        fileprivate static let globalBackground = QueueExecutor(queue: .global(qos: .background))
        fileprivate static let globalUtility = QueueExecutor(queue: .global(qos: .utility))
        fileprivate static let globalDefault = QueueExecutor(queue: .global(qos: .default))
        fileprivate static let globalUserInitiated = QueueExecutor(
            queue: .global(qos: .userInitiated))
        fileprivate static let globalUserInteractive = QueueExecutor(
            queue: .global(qos: .userInteractive))
        fileprivate static let globalUnspecified = QueueExecutor(queue: .global(qos: .unspecified))
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension TaskExecutor where Self == QueueExecutor {
        public static var mainQueue: QueueExecutor {
            QueueExecutor.main
        }

        public static func globalQueue(qos: DispatchQoS.QoSClass = .default) -> QueueExecutor {
            switch qos {
                case .background:
                    return .globalBackground
                case .utility:
                    return .globalUtility
                case .default:
                    return .globalDefault
                case .userInitiated:
                    return .globalUserInitiated
                case .userInteractive:
                    return .globalUserInteractive
                case .unspecified:
                    return .globalUnspecified
                @unknown default:
                    return .init(queue: .global(qos: qos))
            }
        }

        public static func queue(
            label: String,
            qos: DispatchQoS = .unspecified,
            attributes: DispatchQueue.Attributes = [],
            autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit,
            target: DispatchQueue? = nil
        ) -> QueueExecutor {
            queue(
                DispatchQueue(
                    label: label, qos: qos, attributes: attributes,
                    autoreleaseFrequency: autoreleaseFrequency, target: target))
        }

        public static func queue(_ queue: DispatchQueue) -> QueueExecutor {
            QueueExecutor(queue: queue)
        }
    }
#endif
