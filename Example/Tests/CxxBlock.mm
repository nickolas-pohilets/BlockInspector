//
//  CxxBlock.m
//  BlockInspector_Example
//
//  Created by Mykola Pokhylets on 30/09/2019.
//  Copyright © 2019 Mykola Pokhylets. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <vector>
#import <string>
//#import <BlockInspector/BlockInspector.h>

id GetCxxBlock() {
    id x = @"x";
    id y = @"y";
    std::vector<std::string> cxx;
    return ^{
        NSLog(@"%@ %s %@", x, cxx[0].c_str(), y);
    };
}

//BIRegisterCxxType(std::vector<std::string>)
