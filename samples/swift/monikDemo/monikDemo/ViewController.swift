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
        
        let fmt = InstanceIdFormatter(instanceId: "0:0")
        
        let tvl = TextViewLogger(view: textView)
        Monik.default.loggers.append(tvl)
        
        Monik.default.loggers.forEach { $0.formatter = fmt }
        
        log("reset")
        
        log("\(self): viewDidLoad")
        
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(updateTick), userInfo: nil, repeats: true)
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
    
    @objc private func updateTick() {
        tick += 1
        log("onTick: \(tick)")
    }
    
    
    @IBOutlet weak var textView: UITextView!
    private var timer: Timer?
    

    private var tick = 0
}

final class TextViewLogger: Logger {
    
    init(view: UITextView) {
        textView = view
        textView.text = ""
    }
    
    static var identifier: String = "TextViewLogger"
    
    var level: Monik.level = .trace
    
    var formatter: monik.Formatter?
    
    func log(_ source: Monik.source, _ level: Monik.level, _ message: String) {
        DispatchQueue.main.async {
            self.textView.text = self.textView.text + "\n\(message)"
        }
    }
    
    private let textView: UITextView
}
