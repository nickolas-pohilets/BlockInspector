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
    void *dummy;
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
    struct SimpleArr outerStruct;
    
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{
        NSLog(@"%p", &outerStruct);
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

//- (void)testCaptureObject {
//    __strong id s = @"foo";
//    id b = ^{};
//    int k = 42;
//    CGRect rect = CGRectMake(1, 2, 3, 4);
//    BOOL fl;
//    void* ptr = &ptr;
//    __weak id w = s;
//    __unsafe_unretained id o = s;
//    struct Inner nts1;
//    struct Outer nts2;
//    __block int rk = 0;
//    __block id rs = @"bar";
//    __block __weak id rw = rs;
//    __block struct Outer rnts;
//    
//    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:^{
//        NSLog(@"%@ %@ %d %@ %c %p %@ %@ %@ %@ %d %@ %@ %@",
//              s, b, k, NSStringFromCGRect(rect), fl ? 'Y' : 'N', ptr,
//              w, o, nts1.obj1, nts2.obj2, rk, rs, rw, rnts.obj1
//        );
//        return @[];
//    }];
//    XCTAssertFalse(bi.isNoEscape);
//    XCTAssertFalse(bi.isGlobal);
//    XCTAssertFalse(bi.hasStructReturn);
//    XCTAssertTrue(bi.hasSignature);
//    XCTAssert(strcmp(bi.signatureEncoding, "@\"NSArray\"8@?0") == 0);
//    XCTAssertEqualObjects(bi.nameOfInvoke, @"__26-[Tests testCaptureObject]_block_invoke");
//    XCTAssertEqualObjects(bi.nameOfCopyHelper, @"__copy_helper_block_ea8_32s40s48r56r64r72r80w88c89_ZTSNSt3__16vectorINS_12basic_stringIcNS_11char_traitsIcEENS_9allocatorIcEEEENS4_IS6_EEEE160c22_ZTS16NonTrivialStruct");
//    XCTAssertEqualObjects(bi.nameOfDisposeHelper, @"__destroy_helper_block_ea8_32s40s48r56r64r72r80w88c89_ZTSNSt3__16vectorINS_12basic_stringIcNS_11char_traitsIcEENS_9allocatorIcEEEENS4_IS6_EEEE160c22_ZTS16NonTrivialStruct");
//    NSArray<BICapturedVariable *> *vars = @[
//        [[BICapturedVariable alloc] initWithOffset:32 kind:BICapturedVariableKindStrong mangledCxxClassName:nil]
//    ];
//    XCTAssertEqualObjects(bi.capturedVariables, vars);
//}

@end

