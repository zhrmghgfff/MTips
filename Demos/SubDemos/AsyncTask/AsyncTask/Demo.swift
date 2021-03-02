//
//  Demo.swift
//  AsyncTask
//
//  Created by Ma,Limin on 2020/11/30.
//

import Foundation

public class Demo {
    
    public func start() {
        log()
    }
    
    func log() {
        print("\(self) Start ------")
    }
}

extension AsyncTask {
    public static var demo: Demo {
        get {
            Demo()
        }
    }
}
