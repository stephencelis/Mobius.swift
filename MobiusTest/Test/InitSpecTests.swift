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
import MobiusCore
import MobiusTest
import Nimble
import Quick

class InitSpecTests: QuickSpec {
    override func spec() {
        describe("InitSpec") {
            context("when setting up a test scenario") {
                var initiator: Initiator<String, String>!
                var spec: InitSpec<String, String>!
                var testModel: String!
                var testEffects: [String]!
                var assertionClosureCalled = false

                beforeEach {
                    testModel = UUID().uuidString
                    testEffects = ["1", "2", "3"]
                    initiator = { (model: String) in
                        First<String, String>(model: model + model, effects: testEffects)
                    }

                    spec = InitSpec(initiator)
                }

                it("should run the test provided") {
                    spec.when(testModel).then({ (first: First<String, String>) in
                        assertionClosureCalled = true
                        expect(first.model).to(equal(testModel + testModel))
                        expect(first.effects).to(equal(testEffects))
                    })

                    expect(assertionClosureCalled).to(beTrue())
                }
            }
        }
    }
}
