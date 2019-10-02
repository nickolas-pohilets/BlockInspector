//
//  BlockInspectorTests.m
//  BlockInspectorTests
//
//  Created by Mykola Pokhylets on 09/29/2019.
//  Copyright (c) 2019 Mykola Pokhylets. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <BlockInspector/BIBlockInspector.h>
#import "CxxBlock.h"
#import "BlockInspector_Tests-Swift.h"

struct Inner {
    BOOL d1;
    short d2;
    id obj1;
    BOOL d3;
    __weak id obj2;
    BOOL d4;
};

struct Outer {
    id obj1;
    struct Inner inner;
    BOOL dummy;
    id obj2;
};

struct SimpleArr {
    __weak id obj1;
    __unsafe_unretained id dummy;
    id arr[4];
    __weak id obj2;
};

struct InnerArr {
    id obj1;
    struct Inner inner[2];
    __weak id obj2;
};

struct OuterArr {
    __weak id obj1;
    struct InnerArr inner[2];
    id obj2;
};

@interface Tests : XCTestCase

@end

@implementation Tests

- (BIBlockInspector *)inspectNoEscape:(CGRect (NS_NOESCAPE ^)(void))block {
    return [[BIBlockInspector alloc] initWithBlock:block];
}

- (void)testGlobalVoid {
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{}];
    XCTAssertFalse(bi.isNoEscape);
    XCTAssertTrue(bi.isGlobal);
    XCTAssertFalse(bi.hasStructReturn);
    XCTAssertTrue(bi.hasSignature);
    XCTAssert(strcmp(bi.signatureEncoding, "v8@?0") == 0);
    XCTAssertEqualObjects(bi.nameOfInvoke, @"__23-[Tests testGlobalVoid]_block_invoke");
    XCTAssertEqualObjects(bi.nameOfCopyHelper, nil);
    XCTAssertEqualObjects(bi.nameOfDisposeHelper, nil);
    XCTAssertEqualObjects(bi.capturedVariables, @[]);
}

- (void)testStuctReturn {
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{ return CGRectMake(1, 2, 3, 4); }];
    XCTAssertFalse(bi.isNoEscape);
    XCTAssertTrue(bi.isGlobal);
    XCTAssertTrue(bi.hasStructReturn);
    XCTAssertTrue(bi.hasSignature);
    XCTAssert(strcmp(bi.signatureEncoding, "{CGRect={CGPoint=dd}{CGSize=dd}}8@?0") == 0);
    XCTAssertEqualObjects(bi.nameOfInvoke, @"__24-[Tests testStuctReturn]_block_invoke");
    XCTAssertEqualObjects(bi.nameOfCopyHelper, nil);
    XCTAssertEqualObjects(bi.nameOfDisposeHelper, nil);
    XCTAssertEqualObjects(bi.capturedVariables, @[]);
}

- (void)testCaptureStrong {
    id x = @"foo";
    id y = @"bar";
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{ return @[x, y]; }];
    NSArray<BICapturedVariable *> *vars = @[
        [[BIStrongCapturedVariable alloc] initWithOffset:32],
        [[BIStrongCapturedVariable alloc] initWithOffset:40]
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureWeak {
    __weak id x = @"foo";
    __weak id y = @"bar";
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{ return @[x, y]; }];
    NSArray<BICapturedVariable *> *vars = @[
        [[BIWeakCapturedVariable alloc] initWithOffset:32],
        [[BIWeakCapturedVariable alloc] initWithOffset:40],
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureBlock {
    __auto_type x = ^{};
    __auto_type y = ^NSArray*(id x) { return @[x]; };
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{ return @[x, y]; }];
    NSArray<BICapturedVariable *> *vars = @[
        [[BIBlockCapturedVariable alloc] initWithOffset:32],
        [[BIBlockCapturedVariable alloc] initWithOffset:40],
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureOnlyAssign {
    __unsafe_unretained id x = @"foo";
    short y = 42;
    CGRect z = CGRectMake(1, 2, 3, 4);
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{
        NSLog(@"%@ %hd %@", x, y, NSStringFromCGRect(z));
    }];
    NSArray<BICapturedVariable *> *vars = @[
        [[BIAssignCapturedVariable alloc] initWithOffset:32 size:42]
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureRemainingAssign {
    __unsafe_unretained id x = @"foo";
    short y = 42;
    CGRect z = CGRectMake(1, 2, 3, 4);
    id w = @"dummy";
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{
        NSLog(@"%@ %@ %hd %@", x, w, y, NSStringFromCGRect(z));
    }];
    NSArray<BICapturedVariable *> *vars = @[
        [[BIStrongCapturedVariable alloc] initWithOffset:32],
        [[BIAssignCapturedVariable alloc] initWithOffset:40 size:42]
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureNonTrivialStruct {
    struct Inner inner;
    struct Outer outer;
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{
        NSLog(@"%p %p", &inner, &outer);
    }];
    NSArray<BICapturedVariable *> *vars = @[
        [[BINonTrivialStructCapturedVariable alloc] initWithOffset:32 children:@[
            [[BIAssignCapturedVariable alloc] initWithOffset:0 size:4],
            [[BIStrongCapturedVariable alloc] initWithOffset:8],
            [[BIAssignCapturedVariable alloc] initWithOffset:16 size:1],
            [[BIWeakCapturedVariable alloc] initWithOffset:24],
            [[BIAssignCapturedVariable alloc] initWithOffset:32 size:1],
        ]],
        [[BINonTrivialStructCapturedVariable alloc] initWithOffset:72 children:@[
            [[BIStrongCapturedVariable alloc] initWithOffset:0],
            [[BIAssignCapturedVariable alloc] initWithOffset:8 size:4],
            [[BIStrongCapturedVariable alloc] initWithOffset:16],
            [[BIAssignCapturedVariable alloc] initWithOffset:24 size:1],
            [[BIWeakCapturedVariable alloc] initWithOffset:32],
            [[BIAssignCapturedVariable alloc] initWithOffset:40 size:1],
            [[BIAssignCapturedVariable alloc] initWithOffset:48 size:1],
            [[BIStrongCapturedVariable alloc] initWithOffset:56],
        ]]
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureNonTrivialStructWithArr {
    struct SimpleArr s;
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{
        NSLog(@"%p", &s);
    }];
    __auto_type elementType = [[BINonTrivialStructCapturedVariable alloc] initWithOffset:0 children:@[
        [[BIStrongCapturedVariable alloc] initWithOffset:0],
    ]];
    NSArray<BICapturedVariable *> *vars = @[
        [[BINonTrivialStructCapturedVariable alloc] initWithOffset:32 children:@[
            [[BIWeakCapturedVariable alloc] initWithOffset:0],
            [[BIAssignCapturedVariable alloc] initWithOffset:8 size:8],
            [[BINonTrivialArrayCapturedVariable alloc] initWithOffset:16 elementSize:8 numberOfElements:4 elementType:elementType],
            [[BIWeakCapturedVariable alloc] initWithOffset:48],
        ]],
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureNonTrivialStructWithNestedArr {
    struct OuterArr s;
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{
        NSLog(@"%p", &s);
    }];
    
    __auto_type innerElementType = [[BINonTrivialStructCapturedVariable alloc] initWithOffset:0 children:@[
        [[BIAssignCapturedVariable alloc] initWithOffset:0 size:4],
        [[BIStrongCapturedVariable alloc] initWithOffset:8],
        [[BIAssignCapturedVariable alloc] initWithOffset:16 size:1],
        [[BIWeakCapturedVariable alloc] initWithOffset:24],
        [[BIAssignCapturedVariable alloc] initWithOffset:32 size:1],
    ]];
    __auto_type outerElementType = [[BINonTrivialStructCapturedVariable alloc] initWithOffset:0 children:@[
        [[BIStrongCapturedVariable alloc] initWithOffset:0],
        [[BINonTrivialArrayCapturedVariable alloc] initWithOffset:8 elementSize:40 numberOfElements:2 elementType:innerElementType],
        [[BIWeakCapturedVariable alloc] initWithOffset:88],
    ]];
    NSArray<BICapturedVariable *> *vars = @[
        [[BINonTrivialStructCapturedVariable alloc] initWithOffset:32 children:@[
            [[BIWeakCapturedVariable alloc] initWithOffset:0],
            [[BINonTrivialArrayCapturedVariable alloc] initWithOffset:8 elementSize:96 numberOfElements:2 elementType:outerElementType],
            [[BIStrongCapturedVariable alloc] initWithOffset:200],
        ]],
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testByref {
    __block BOOL x1 = YES;
    __block CGRect x2 = CGRectMake(1, 2, 3, 4);
    __block id x3 = [NSNull null];
    __block __weak id x4 = @"foo";
    __block void (^x5)(void) = ^{};
    __block __unsafe_unretained id x6 = @"bar";
    __block struct SimpleArr x7 = {};
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{
        NSLog(@"%c %@ %@ %@ %@ %@ %@", x1 ? 'Y' : 'N', NSStringFromCGRect(x2), x3, x4, x5, x6, x7.arr[3]);
    }];
    
    NSArray<BICapturedVariable *> *vars = @[
        [[BIByrefCapturedVariable alloc] initWithOffset:32 valueOffset:24 valueSize:8],
        [[BIByrefCapturedVariable alloc] initWithOffset:40 valueOffset:32 valueSize:32],
        [[BIByrefCapturedVariable alloc] initWithOffset:48 valueOffset:40 valueSize:8],
        [[BIByrefCapturedVariable alloc] initWithOffset:56 valueOffset:40 valueSize:8],
        [[BIByrefCapturedVariable alloc] initWithOffset:64 valueOffset:40 valueSize:8],
        [[BIByrefCapturedVariable alloc] initWithOffset:72 valueOffset:24 valueSize:8],
        [[BIByrefCapturedVariable alloc] initWithOffset:80 valueOffset:48 valueSize:56],
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureCxx {
    BIBlockInspector *bi = [[BIBlockInspector alloc] initWithBlock:GetCxxBlock()];
    NSArray<BICapturedVariable *> *vars = @[
        [[BIStrongCapturedVariable alloc] initWithOffset:32],
        [[BIStrongCapturedVariable alloc] initWithOffset:40],
        [[BIByrefCapturedVariable alloc] initWithOffset:48 valueOffset:48 valueSize:24],
        [[BICxxCapturedVariable alloc] initWithOffset:56 mangledCxxClassName:@"_ZTSNSt3__112basic_stringIcNS_11char_traitsIcEENS_9allocatorIcEEEE"],
    ];
    XCTAssertEqualObjects(bi.capturedVariables, vars);
}

- (void)testCaptureSwift {
    // Bridged Swift blocks have neither descriptively named helper functions, nor extended layout.
    // Maybe we could use Swift metadata?
    BIBlockInspector *bi = [[BIBlockInspector alloc] initWithBlock:[SwiftBlock getBlock]];
    XCTAssertNil(bi.capturedVariables);
}

@end

