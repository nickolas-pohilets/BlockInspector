//
//  CxxSupport.m
//  BlockInspector
//
//  Created by Mykola Pokhylets on 30/09/2019.
//

#import "CxxSupport.h"
#import "BIBlockInspector.h"
#import "BICapturedVariable.h"
#import <cxxabi.h>

static NSMutableDictionary *GetTypeRegistry() {
    static NSMutableDictionary *res;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        res = [NSMutableDictionary new];
    });
    return res;
}

extern "C" {

NSString * BIDemangleCxxType(NSString *mangledName) {
    int status = 0;
    char * result = __cxxabiv1::__cxa_demangle([mangledName UTF8String], nullptr, 0, &status);
    if (result == nullptr) {
        return nil;
    }
    NSString *s = [NSString stringWithUTF8String:result];
    free(result);
    return s;
}

BOOL BIGetTypeInfo(NSString *mangledName, TypeInfo *typeInfo) {
    NSValue *value = GetTypeRegistry()[mangledName];
    if (value == nil) {
        return NO;
    }
    [value getValue:typeInfo size:sizeof(TypeInfo)];
    return YES;
}

void BIRegisterTypeInfo(id prototypeBlock, TypeInfo typeInfo) {
    BIBlockInspector* bi = [[BIBlockInspector alloc] initWithBlock:prototypeBlock];
    NSArray<BICapturedVariable *> *vars = bi.capturedVariables;
    NSCAssert(vars.count == 2, @"Prototype block should contain exactly one captured variable");
    BICxxCapturedVariable* cxxVar = (BICxxCapturedVariable *)vars.firstObject;
    BIAssignCapturedVariable* placeholder = (BIAssignCapturedVariable *)vars.lastObject;
    NSCAssert([cxxVar isKindOfClass:BICxxCapturedVariable.class], @"Captured variable should be a C++ object");
    NSCAssert([placeholder isKindOfClass:BIAssignCapturedVariable.class], @"Captured variable should be a C++ object");
    NSCAssert(placeholder.offset == cxxVar.offset && placeholder.size == typeInfo.size, @"Placeholder should match the object");
    NSString *mangledName = cxxVar.mangledCxxClassName;
    NSValue *value = [NSValue valueWithBytes:&typeInfo objCType:@encode(TypeInfo)];
    GetTypeRegistry()[mangledName] = value;
}

}
