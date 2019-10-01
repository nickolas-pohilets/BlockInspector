//
//  CxxSupport.m
//  BlockInspector
//
//  Created by Mykola Pokhylets on 30/09/2019.
//

#import "CxxSupport.h"
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

void BIRegisterTypeInfo(NSString *mangledName, TypeInfo typeInfo) {
    NSValue *value = [NSValue valueWithBytes:&typeInfo objCType:@encode(TypeInfo)];
    GetTypeRegistry()[mangledName] = value;
}

}
