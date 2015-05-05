//
//  test2Tests.swift
//  test2Tests
//
//  Created by Kyle Maxwell on 4/2/15.
//  Copyright (c) 2015 Kyle Maxwell. All rights reserved.
//

import UIKit
import XCTest
import test2

class test2Tests: XCTestCase {
    
    var searcher: Search!
    
    override func setUp() {
        super.setUp()

        var dataString = String(
            contentsOfFile: NSBundle.mainBundle().pathForResource("data", ofType: "txt")!,
            encoding: NSUTF8StringEncoding, error: nil)
        
        var data: [String] = split(dataString!, isSeparator: { $0 == "\n" })
        
        var synonymsString = String(
            contentsOfFile: NSBundle.mainBundle().pathForResource("synonyms", ofType: "txt")!,
            encoding: NSUTF8StringEncoding, error: nil)
        
        var synonyms: [[String]] = split(synonymsString!, isSeparator: { $0 == "\n" }).map {
            split($0, isSeparator: { $0 == "\t" })
        }
        
        self.searcher = Search(corpus: data, synonyms: synonyms) 
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    
}
