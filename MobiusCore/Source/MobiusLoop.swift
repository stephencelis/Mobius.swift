// Copyright (c) 2019 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Foundation

/// - Callout(Instantiating): Use `Mobius.loop(update:effectHandler:)` to create an instance.
public final class MobiusLoop<Model, Event, Effect>: Disposable, CustomDebugStringConvertible {
    private let eventProcessor: EventProcessor<Model, Event, Effect>
    private let consumeEvent: Consumer<Event>
    private let modelPublisher: ConnectablePublisher<Model>
    private let disposable: Disposable
    private var disposed = false
    private var access: ConcurrentAccessDetector
    private var workBag: WorkBag

    public var debugDescription: String {
        return access.guard {
            if disposed {
                return "disposed loop!"
            }
            return "\(type(of: self)) \(eventProcessor)"
        }
    }

    init(
        eventProcessor: EventProcessor<Model, Event, Effect>,
        consumeEvent: @escaping Consumer<Event>,
        modelPublisher: ConnectablePublisher<Model>,
        disposable: Disposable,
        accessGuard: ConcurrentAccessDetector,
        workBag: WorkBag
    ) {
        self.eventProcessor = eventProcessor
        self.consumeEvent = consumeEvent
        self.modelPublisher = modelPublisher
        self.disposable = disposable
        self.access = accessGuard
        self.workBag = workBag
    }

    /// Add an observer of model changes to this loop. If `getMostRecentModel()` is non-nil,
    /// the observer will immediately be notified of the most recent model. The observer will be
    /// notified of future changes to the model until the loop or the returned `Disposable` is
    /// disposed.

    /// - Parameter consumer: an observer of model changes
    /// - Returns: a `Disposable` that can be used to stop further notifications to the observer
    @discardableResult
    public func addObserver(_ consumer: @escaping Consumer<Model>) -> Disposable {
        return access.guard {
            modelPublisher.connect(to: consumer)
        }
    }

    public func dispose() {
        return access.guard {
            if !disposed {
                modelPublisher.dispose()
                eventProcessor.dispose()
                disposable.dispose()
                disposed = true
            }
        }
    }

    deinit {
        dispose()
    }

    public var latestModel: Model {
        return access.guard { eventProcessor.latestModel }
    }

    public func dispatchEvent(_ event: Event) {
        return access.guard {
            guard !disposed else {
                // Callers are responsible for ensuring dispatchEvent is never entered after dispose.
                MobiusHooks.onError("event submitted after dispose")
                return
            }

            workBag.submit {
                self.consumeEvent(event)
            }
            workBag.service()
        }
    }

    // swiftlint:disable:next function_parameter_count
    static func createLoop<C: Connectable>(
        update: @escaping Update<Model, Event, Effect>,
        effectHandler: C,
        initialModel: Model,
        initiator: @escaping Initiator<Model, Effect>,
        eventSource: AnyEventSource<Event>,
        eventConsumerTransformer: ConsumerTransformer<Event>,
        logger: AnyMobiusLogger<Model, Event, Effect>
    ) -> MobiusLoop where C.InputType == Effect, C.OutputType == Event {
        let accessGuard = ConcurrentAccessDetector()
        let loggingInitiator = LoggingInitiator(initiator, logger)
        let loggingUpdate = LoggingUpdate(update, logger)
        let workBag = WorkBag(accessGuard: accessGuard)

        // create somewhere for the event processor to push nexts to; later, we'll observe these nexts and
        // dispatch models and effects to the right places
        let nextPublisher = ConnectablePublisher<Next<Model, Effect>>(accessGuard: accessGuard)

        // event processor: process events, publish Next:s, retain current model
        let eventProcessor = EventProcessor(
            update: loggingUpdate.update,
            publisher: nextPublisher,
            accessGuard: accessGuard
        )

        let consumeEvent = eventConsumerTransformer(eventProcessor.accept)

        // effect handler: handle effects, push events to the event processor
        let effectHandlerConnection = effectHandler.connect(consumeEvent)

        let eventSourceDisposable = eventSource.subscribe(consumer: consumeEvent)

        // model observer support
        let modelPublisher = ConnectablePublisher<Model>()

        // ensure model updates get published and effects dispatched to the effect handler
        let nextConsumer: Consumer<Next<Model, Effect>> = { next in
            if let model = next.model {
                modelPublisher.post(model)
            }

            next.effects.forEach({ (effect: Effect) in
                workBag.submit {
                    effectHandlerConnection.accept(effect)
                }
            })
            workBag.service()
        }
        let nextConnection = nextPublisher.connect(to: nextConsumer)

        // everything is hooked up, start processing!
        eventProcessor.start(from: loggingInitiator.initiate(initialModel))

        return MobiusLoop(
            eventProcessor: eventProcessor,
            consumeEvent: consumeEvent,
            modelPublisher: modelPublisher,
            disposable: CompositeDisposable(disposables: [eventSourceDisposable, nextConnection, effectHandlerConnection]),
            accessGuard: accessGuard,
            workBag: workBag
        )
    }
}
