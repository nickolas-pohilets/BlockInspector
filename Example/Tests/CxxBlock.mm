//
//  CxxBlock.m
//  BlockInspector_Example
//
//  Created by Mykola Pokhylets on 30/09/2019.
//  Copyright © 2019 Mykola Pokhylets. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <string>
#import <vector>
#import "CxxSupport.h"
#import "BIBlockInspector.h"

extern "C" {
id GetCxxBlock() {
    BIRegisterCxxType(std::string);
    id x = @"x";
    id y = @"y";
    std::string cxx;
    __block std::string cyy;
    return ^{
        cyy = cxx;
        NSLog(@"%@ %s %@", x, cxx.c_str(), y);
    };
}
}
