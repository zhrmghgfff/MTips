//
//  ViewProtocol.swift
//  DescUI
//
//  Created by Ma,Limin on 2021/3/2.
//

import Foundation

public protocol View {
    
    associatedtype Body: View

    var body: Self.Body { get }
}
