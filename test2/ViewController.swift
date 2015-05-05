//
//  ViewController.swift
//  test2
//
//  Created by Kyle Maxwell on 4/2/15.
//  Copyright (c) 2015 Kyle Maxwell. All rights reserved.
//

import UIKit
import Foundation

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var searchField: UITextField!
    
    var searcher: Search!
    
    var answers = ["Nothing yet"]
    
    let textCellIdentifier = "TextCell"

    @IBAction func editing(sender: AnyObject) {
        self.answers = self.searcher.search(searchField.text, results: 10).map({(result: Result) -> String in
            return result.text + " " + String(result.score)
        })
        self.tableView.reloadData()
//        self.resufslts.
    }
    
    @IBOutlet weak var tableView: UITableView!

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return answers.count
    }
  
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(textCellIdentifier, forIndexPath: indexPath) as! UITableViewCell
        
        let row = indexPath.row
        cell.textLabel?.text = answers[row]
        
        return cell
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

