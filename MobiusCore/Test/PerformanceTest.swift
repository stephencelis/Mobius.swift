//
//  PerformanceTest.swift
//  MobiusCoreTests
//
//  Created by Michael Brandon Williams on 12/17/19.
//

import Foundation
import XCTest
import MobiusCore

class PerformanceTest: XCTestCase {
    func testPerformance() {
        struct State {
            var array = Array(1...1_000_000)
            var count = 0
        }
        let update = Update<State, Void, Never> { model, event in
            model.count += 1
            return []
        }
        //        let loop = Mobius.loop(update: update)
        var state = State()

        self.measure {
            (1...100_000).forEach { _ in
                _ = update.update(into: &state, event: ())
            }
        }

        XCTAssertEqual(state.count, 1_000_000)
    }
}
