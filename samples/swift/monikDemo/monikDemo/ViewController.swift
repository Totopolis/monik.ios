//
//  ViewController.swift
//  monikDemo
//
//  Created by Sergey Pestov on 13/01/2017.
//  Copyright © 2017 SmartDriving. All rights reserved.
//

import UIKit
import monik

func log( _ text: @autoclosure (Void) -> String) {
    Monik.default.log(.application, .info, text())
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let fmt = InstanceIdFormatter(instanceId: "<instanceId>")
        
        Monik.default.loggers.forEach { $0.formatter = fmt }
        
        log("reset")
        
        log("\(self): viewDidLoad")
    }
    
    deinit {
        Monik.default.close()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        log("\(self): viewWillAppear")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        log("\(self): viewDidLayoutSubviews")
    }
    
    @IBAction func sendMessage(_ sender: Any) {
        log("\(sender) click at \(Date())")
    }
}

