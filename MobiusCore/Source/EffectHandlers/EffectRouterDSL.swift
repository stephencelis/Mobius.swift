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

public extension EffectRouter where Input: Equatable {
    /// Add a route for effects which are equal to `equalTo`.
    /// - Parameter `equalTo`: the effect that should be handled by this route
    func routeEffects(
        equalTo constant: Input
    ) -> PartialEffectRouter<Input, Input, Output> {
        return routeEffects(withPayload: { effect in effect == constant ? effect : nil })
    }
}

public extension EffectRouter {
    /// Add a route for effects which satisfy `matching`.
    /// - Parameter matching: The predicate that will be used to determine if this route should be taken for a given effect.
    func routeEffects(
        matching predicate: @escaping (Input) -> Bool
    ) -> PartialEffectRouter<Input, Input, Output> {
        return routeEffects(withPayload: { effect in predicate(effect) ? effect : nil })
    }
}

public extension PartialEffectRouter {
    /// Route to a side-effecting closure.
    /// - Parameter fireAndForget: a function which given some input carries out a side effect.
    func to(
        _ fireAndForget: @escaping (Payload) -> Void
    ) -> EffectRouter<Input, Output> {
        return to(EffectHandler<Payload, Output>(
            handle: { payload, _ in fireAndForget(payload) },
            disposable: AnonymousDisposable {}
        ))
    }

    /// Route to a closure which returns an optional event when given the payload as input.
    /// - Parameter eventFunction: a function which returns an optional event given some input. No events will be propagated if this function returns
    /// `nil`.
    func toEvent(
        _ eventFunction: @escaping (Payload) -> Output?
    ) -> EffectRouter<Input, Output> {
        return to(EffectHandler<Payload, Output>(
            handle: { payload, dispatch in
                if let event = eventFunction(payload) {
                    dispatch(event)
                }
            },
            disposable: AnonymousDisposable {}
        ))
    }
}
