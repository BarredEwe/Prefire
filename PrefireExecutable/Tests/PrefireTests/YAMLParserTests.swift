import Foundation
@testable import prefire
import XCTest

class YAMLParserTests: XCTestCase {
    func test_simpleObject() {
        let content: [String: Any?] = [
            "arrayKey": ["value1"],
            "dictionaryKey": [
                "key1": "value1"
            ],
            "key1": "value1",
        ]
        let expectation = """
        arrayKey:
          - value1
        dictionaryKey:
          key1: value1
        key1: value1

        """

        let result = YAMLParser().string(from: content)

        XCTAssertEqual(expectation, result)
    }
}
