//
//  SwiftBlock.swift
//  BlockInspector_Tests
//
//  Created by Nickolas Pokhylets on 02/10/2019.
//  Copyright © 2019 Mykola Pokhylets. All rights reserved.
//

import Foundation

enum Foo {
    case foo
    case bar
}

@objc
public class SwiftBlock: NSObject {
    @objc
    public static func getBlock() -> () -> Void {
        let foo: Foo = .foo
        return { print(foo) }
    }
}
