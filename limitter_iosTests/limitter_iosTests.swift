//
//  limitter_iosTests.swift
//  limitter_iosTests
//
//  Created by Jan Dittmer on 10/14/16.
//  Copyright © 2016 Jan Dittmer. All rights reserved.
//

import XCTest
@testable import limitter_ios

class limitter_iosTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    func doDecode(_ a: String, _ b: String) {
        let vc = ViewController()

        let c = vc.decodeSensor(a)
        print(c);
        assert(c == b)

    }
    func testDecodeSensor() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        self.doDecode("LOW 3100", "Battery soon low! 3100")
        self.doDecode("", "Wrong component length 1")
        self.doDecode("12345 3621 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116",
                      "GLUCOSE 9 TREND -0.0970873786407767 BATTERY 3621 MINUTES 12345")

    }
    func testSha1() {
        let str = "nightscout"
        print(str.sha1())
        assert(str.sha1() == "b0193185a6e5fe70dd102f701db350fbd0e79aa5")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
