//
//  BIBlockInspector.m
//  BlockInspector
//
//  Created by Mykola Pokhylets on 29/09/2019.
//

#import "BIBlockInspector.h"
#import <execinfo.h>

#define let __auto_type const
#define RE(pattern) ({ \
    static NSRegularExpression *re; \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil]; \
    }); \
    re; \
})

static BOOL AreEqual(id a, id b) {
    return (a == b) || [a isEqual:b];
}

@implementation BIBlockInspector

+ (NSString *)nameOfFunction:(void *)function {
    if (function == NULL) {
        return nil;
    }
    char **names = backtrace_symbols(&function, 1);
    if (names == NULL) {
        return nil;
    }
    NSString *name = [NSString stringWithUTF8String:names[0]];
    free(names);
    
    NSRegularExpression *re = RE(@"^0\\s.*\\s0x[0-9a-fA-F]+ (.*) \\+ 0$");
    NSTextCheckingResult *match = [re firstMatchInString:name options:0 range:NSMakeRange(0, name.length)];
    if (match == nil) {
        return nil;
    }
    NSRange range = [match rangeAtIndex:1];
    return [name substringWithRange:range];
}

- (instancetype)initWithBlock:(id)block {
    if (![block isKindOfClass:NSClassFromString(@"NSBlock")]) {
        return [self parsingFailure];
    }
    self = [super init];
    if (self) {
        _block = [block copyWithZone:nil];
    }
    return self;
}

- (BIBlockLiteral *)blockLiteral {
    return (__bridge BIBlockLiteral *)_block;
}

- (BIBlockDescriptor *)blockDescriptor {
    return self.blockLiteral->descriptor;
}

- (BIBlockInvokeFunction)invoke {
    return self.blockLiteral->invoke;
}

- (BIBlockCopyHelper)copyHelper {
    if (self.blockLiteral->flags & BLOCK_HAS_COPY_DISPOSE) {
        return self.blockDescriptor->copy_helper;
    } else {
        return nil;
    }
}

- (BIBlockDisposeHelper)disposeHelper {
    if (self.blockLiteral->flags & BLOCK_HAS_COPY_DISPOSE) {
        return self.blockDescriptor->dispose_helper;
    } else {
        return nil;
    }
}

- (NSString *)nameOfInvoke {
    return [BIBlockInspector nameOfFunction:self.invoke];
}

- (NSString *)nameOfCopyHelper {
    return [BIBlockInspector nameOfFunction:self.copyHelper];
}

- (NSString *)nameOfDisposeHelper {
    return [BIBlockInspector nameOfFunction:self.disposeHelper];
}

- (NSUInteger)size {
    return self.blockDescriptor->size;
}

- (BOOL)isNoEscape {
    return self.blockLiteral->flags & BLOCK_IS_NOESCAPE;
}

- (BOOL)isGlobal {
    int flags = self.blockLiteral->flags;
    return (flags & BLOCK_IS_GLOBAL) && !(flags & BLOCK_IS_NOESCAPE);
}

- (BOOL)hasStructReturn {
    int flags = self.blockLiteral->flags;
    NSAssert(flags & BLOCK_HAS_SIGNATURE, @"BLOCK_HAS_STRET cannot be trusted in old ABI");
    return (flags & BLOCK_HAS_SIGNATURE) && (flags & BLOCK_HAS_STRET);
}

- (BOOL)hasSignature {
    return self.signatureEncoding != NULL;
}

- (const char *)signatureEncoding {
    int flags = self.blockLiteral->flags;
    BIBlockDescriptor *descriptor = self.blockDescriptor;
    if (flags & BLOCK_HAS_SIGNATURE) {
        if (flags & BLOCK_HAS_COPY_DISPOSE) {
            return descriptor->signature;
        } else {
            return (char const *)descriptor->copy_helper;
        }
    } else {
        return nil;
    }
}

- (NSMethodSignature *)signature {
    char const * types = self.signatureEncoding;
    if (types == NULL) {
        return [self parsingFailure];
    }
    return [NSMethodSignature signatureWithObjCTypes:types];
}

- (NSArray<BICapturedVariable *> *)capturedVariables {
    NSRange bytesRange = { sizeof(BIBlockLiteral), self.size - sizeof(BIBlockLiteral) };
    NSMutableIndexSet *remainingBytes = [NSMutableIndexSet indexSetWithIndexesInRange:bytesRange];
    
    NSMutableArray<BICapturedVariable *> *capturedVariables = [NSMutableArray new];
    
    void * copyHelper = self.copyHelper;
    if (copyHelper != nil) {
        NSString* name = self.nameOfCopyHelper;
        if (name == nil) {
            return [self parsingFailure];
        }
        
        NSScanner* s = [NSScanner scannerWithString:name];
        if (![s scanString:@"__copy_helper_block_" intoString:nil]) { return [self parsingFailure]; }
        [s scanString:@"e" intoString:nil]; // exceptions flag, optional
        [s scanString:@"a" intoString:nil]; // objCAutoRefCountExceptions flag, optional
        if (![s scanUnsignedLongLong:nil]) { return [self parsingFailure]; } // block alignment
        if (![s scanString:@"_" intoString:nil]) { return [self parsingFailure]; }
            
        while (!s.atEnd) {
            BICapturedVariable *v = [self parseCapturedVariable:s];
            if (v == nil) {
                return [self parsingFailure];
            }
            [remainingBytes removeIndexesInRange:NSMakeRange(v.offset, v.size)];
            [capturedVariables addObject:v];
        }
    }
    [remainingBytes enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        if (range.length > 0) {
            let v = [[BIAssignCapturedVariable alloc] initWithOffset:range.location size:range.length];
            [capturedVariables addObject:v];
        }
    }];
    [capturedVariables sortUsingComparator:^NSComparisonResult(BICapturedVariable *obj1, BICapturedVariable *obj2) {
        NSInteger offset1 = obj1.offset, offset2 = obj2.offset;
        if (offset1 < offset2) return NSOrderedAscending;
        if (offset1 > offset2) return NSOrderedDescending;
        NSInteger size1 = obj1.size, size2 = obj2.size;
        if (size1 < size2) return NSOrderedAscending;
        if (size1 > size2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return capturedVariables;
}

- (nullable BICapturedVariable *)parseCapturedVariable:(NSScanner *)s {
    NSInteger offset;
    if (![s scanInteger:&offset]) { return [self parsingFailure]; }
    NSString* kind;
    if (![s scanCharactersFromSet:NSCharacterSet.letterCharacterSet intoString:&kind]) { return [self parsingFailure]; }

    switch ([kind characterAtIndex:0]) {
       case 'c': return [self parseCxxCaptureVariable:s offset:offset];
       case 'w': return [[BIWeakCapturedVariable alloc] initWithOffset:offset];
       case 's': return [[BIStrongCapturedVariable alloc] initWithOffset:offset];
       case 'r': return [[BIByrefCapturedVariable alloc] initWithOffset:offset];
       case 'b': return [[BIBlockCapturedVariable alloc] initWithOffset:offset];
       case 'o': return [self parsingFailure];
       case 'n': return [self parseNonTrivialStructCaptureVariable:s offset:offset];
       default: return [self parsingFailure];
    }
}

- (nullable NSString *)scanStringOfLength:(NSUInteger)length from:(NSScanner *)s {
    NSUInteger scanLocation = s.scanLocation;
    NSString* str = s.string;
    if (length <= 0 || scanLocation + length > str.length) {
        return [self parsingFailure];
    }
    
    NSString* result = [str substringWithRange:NSMakeRange(scanLocation, length)];
    s.scanLocation = scanLocation + length;
    return result;
}

- (nullable BICxxCapturedVariable *)parseCxxCaptureVariable:(NSScanner *)s offset:(NSInteger)offset {
    NSInteger size;
    if (![s scanInteger:&size]) { return [self parsingFailure]; }
    
    NSString *className = [self scanStringOfLength:size from:s];
    if (className == nil) { return [self parsingFailure]; }
    return [[BICxxCapturedVariable alloc] initWithOffset:offset mangledCxxClassName:className];
}

- (nullable BINonTrivialStructCapturedVariable *)parseNonTrivialStructCaptureVariable:(NSScanner *)s offset:(NSInteger)offset {
    NSInteger size;
    if (![s scanInteger:&size]) { return [self parsingFailure]; }
    if (![s scanString:@"_" intoString:nil]) { return [self parsingFailure]; }
    
    NSString* str = [self scanStringOfLength:size from:s];
    let children = [self parseStructChildren:str];
    if (children == nil) return [self parsingFailure];
    return [[BINonTrivialStructCapturedVariable alloc] initWithOffset:offset children:children];
}

- (nullable NSArray<BICapturedVariable *> *)parseStructChildren:(NSString *)str {
    NSScanner *s = [NSScanner scannerWithString:str];
    if (![s scanInteger:nil]) { return [self parsingFailure]; } // src alignment
    if (![s scanString:@"_" intoString:nil]) { return [self parsingFailure]; }
    if (![s scanInteger:nil]) { return [self parsingFailure]; } // dst alignment
    
    NSMutableArray *children = [NSMutableArray new];
    
    while (!s.atEnd) {
        BICapturedVariable *v = [self parseStructChild:s stop:NULL baseOffset:0];
        if (v == nil) {
            return [self parsingFailure];
        }
        [children addObject:v];
    }
    return children;
}

- (nullable BICapturedVariable *)parseStructChild:(NSScanner *)s stop:(BOOL *)stop baseOffset:(NSInteger)baseOffset {
    NSString *kind;
    while (true) {
        if (![s scanString:@"_" intoString:nil]) { return [self parsingFailure]; }
        
        if (![s scanCharactersFromSet:NSCharacterSet.letterCharacterSet intoString:&kind]) {
            return [self parsingFailure];
        }
        
        if ([kind isEqualToString:@"S"]) {
            // Start marker of the nested struct
            // There is no end marker, so we cannot really parse nested structs recursively.
            // And all offsets are from the beginning of the root.
            // Just skip it
            continue;
        }
        
        if ([kind isEqualToString:@"AE"]) {
            if (stop) {
                *stop = YES;
                return nil;
            } else {
                return [self parsingFailure];
            }
        }
        
        break;
    }
    
    NSInteger offset;
    if (![s scanInteger:&offset]) { return [self parsingFailure]; }
    
    if ([kind isEqualToString:@"AB"]) {
        return [self parseArrayChild:s offset:offset baseOffset:baseOffset];
    } else if ([kind isEqualToString:@"s"]) {
        return [[BIStrongCapturedVariable alloc] initWithOffset:offset - baseOffset];
    } else if ([kind isEqualToString:@"w"]) {
        return [[BIWeakCapturedVariable alloc] initWithOffset:offset - baseOffset];
    } else if ([kind isEqualToString:@"t"]) {
        if (![s scanString:@"w" intoString:nil]) { return [self parsingFailure]; }
        NSInteger size;
        if (![s scanInteger:&size]) { return [self parsingFailure]; }
        return [[BIAssignCapturedVariable alloc] initWithOffset:offset - baseOffset size:size];
    } else {
        return [self parsingFailure];
    }
}

- (nullable BINonTrivialArrayCapturedVariable *)parseArrayChild:(NSScanner *)s offset:(NSInteger)offset baseOffset:(NSInteger)baseOffset {
    if (![s scanString:@"s" intoString:nil]) { return [self parsingFailure]; }
    NSInteger elementSize;
    if (![s scanInteger:&elementSize]) { return [self parsingFailure]; }
    if (![s scanString:@"n" intoString:nil]) { return [self parsingFailure]; }
    NSInteger numberOfElements;
    if (![s scanInteger:&numberOfElements]) { return [self parsingFailure]; }
    
    NSMutableArray *children = [NSMutableArray new];
    
    while (true) {
        BOOL stop = NO;
        BICapturedVariable *v = [self parseStructChild:s stop:&stop baseOffset:offset];
        if (stop) break;
        if (v == nil) {
            return [self parsingFailure];
        }
        [children addObject:v];
    }
    let elementType = [[BINonTrivialStructCapturedVariable alloc] initWithOffset:0 children:children];
    return [[BINonTrivialArrayCapturedVariable alloc] initWithOffset:offset - baseOffset
                                                         elementSize:elementSize
                                                    numberOfElements:numberOfElements
                                                         elementType:elementType];
}

- (id)parsingFailure {
    return nil;
}

@end

