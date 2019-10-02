//
//  BICapturedVariable.m
//  BlockInspector
//
//  Created by Mykola Pokhylets on 01/10/2019.
//

#import "BICapturedVariable.h"
#import "CxxSupport.h"

@interface BICapturedVariable()

- (instancetype)initWithOffset:(NSInteger)offset size:(NSInteger)size kind:(BICapturedVariableKind)kind;

@end

@implementation BICapturedVariable

@synthesize offset = _offset;

- (instancetype)initWithOffset:(NSInteger)offset size:(NSInteger)size kind:(BICapturedVariableKind)kind {
    self = [super init];
    if (self) {
        _offset = offset;
        _size = size;
        _kind = kind;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (NSUInteger)hash {
    return (_offset * 17 + _kind);
}

- (BOOL)isEqual:(id)object {
    if (self.class != [object class]) {
        return NO;
    }
    BICapturedVariable *other = object;
    return _offset == other->_offset && _size == other->_size && _kind == other->_kind;
}

- (NSString *)kindDescription {
    switch (_kind) {
        case BICapturedVariableKindCXX: return @"cxx";
        case BICapturedVariableKindStrong: return @"strong";
        case BICapturedVariableKindWeak: return @"weak";
        case BICapturedVariableKindAssign: return @"assign";
        case BICapturedVariableKindByref: return @"byref";
        case BICapturedVariableKindBlock: return @"block";
        case BICapturedVariableKindNonTrivialStruct: return @"struct";
        case BICapturedVariableKindNonTrivialArray: return @"array";
    }
}

- (NSString *)subclassDescription {
    return @"";
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p offset=%lld size=%lld kind=%@%@>",
        self.class,
        (__bridge void*)self,
        (long long)_offset,
        (long long)_size,
        [self kindDescription],
        [self subclassDescription]
    ];
}

@end

@implementation BICxxCapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset mangledCxxClassName:(NSString *)mangledCxxClassName {
    NSInteger size = 0;
    struct TypeInfo typeInfo;
    if (BIGetTypeInfo(mangledCxxClassName, &typeInfo)) {
        size = typeInfo.size;
    }
    self = [super initWithOffset:offset size:size kind:BICapturedVariableKindCXX];
    if (self) {
        _mangledCxxClassName = [mangledCxxClassName copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    BICxxCapturedVariable *other = object;
    return [super isEqual:object] && [_mangledCxxClassName isEqualToString:other->_mangledCxxClassName];
}

- (NSString *)subclassDescription {
    return [NSString stringWithFormat:@" className=%@ (%@)", _mangledCxxClassName, self.demangledCxxClassName ?: @"???"];
}

- (NSString *)demangledCxxClassName {
    return BIDemangleCxxType(_mangledCxxClassName);
}

@end

@implementation BIWeakCapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset {
    return [self initWithOffset:offset size:sizeof(void*) kind:BICapturedVariableKindWeak];
}

@end

@implementation BIStrongCapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset {
    return [self initWithOffset:offset size:sizeof(void*) kind:BICapturedVariableKindStrong];
}

@end

@implementation BIAssignCapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset size:(NSInteger)size{
    return [self initWithOffset:offset size:size kind:BICapturedVariableKindAssign];
}

@end

@implementation BIByrefCapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset
                   valueOffset:(NSInteger)valueOffset
                     valueSize:(NSInteger)valueSize {
    self = [self initWithOffset:offset size:sizeof(void*) kind:BICapturedVariableKindByref];
    if (self) {
        _valueOffset = valueOffset;
        _valueSize = valueSize;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    BIByrefCapturedVariable *other = object;
    return [super isEqual:object] && _valueOffset == other->_valueOffset && _valueSize == other->_valueSize;
}

- (NSString *)subclassDescription {
    return [NSString stringWithFormat:@" valueOffset=%lld valueSize=%lld", (long long)_valueOffset, (long long)_valueSize];
}

@end

@implementation BIBlockCapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset {
    return [self initWithOffset:offset size:sizeof(void*) kind:BICapturedVariableKindBlock];
}

@end

@implementation BINonTrivialStructCapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset children:(NSArray<BICapturedVariable *> *)children {
    NSInteger size = 0;
    for (BICapturedVariable *child in children) {
        NSInteger end = child.offset + child.size;
        size = MAX(size, end);
    }
    NSInteger alignment = sizeof(void *);
    size = (size + alignment - 1) / alignment * alignment;
    
    self = [super initWithOffset:offset size:size kind:BICapturedVariableKindNonTrivialStruct];
    if (self) {
        _children = [children copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    BINonTrivialStructCapturedVariable *other = object;
    return [super isEqual:object] && [_children isEqual:other->_children];
}

- (NSString *)subclassDescription {
    return [NSString stringWithFormat:@" children=%@", _children];
}

@end

@implementation BINonTrivialArrayCapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset
                   elementSize:(NSInteger)elementSize
              numberOfElements:(NSInteger)numberOfElements
                   elementType:(BINonTrivialStructCapturedVariable *)elementType {
    self = [super initWithOffset:offset size:elementSize * numberOfElements kind:BICapturedVariableKindNonTrivialArray];
    if (self) {
        _elementSize = elementSize;
        _numberOfElements = numberOfElements;
        _elementType = [elementType copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    BINonTrivialArrayCapturedVariable *other = object;
    return [super isEqual:object]
        && _elementSize == other->_elementSize
        && _numberOfElements == other->_numberOfElements
        && [_elementType isEqual:other->_elementType];
}

- (NSString *)subclassDescription {
    return [NSString stringWithFormat:@" elementSize=%lld numberOfElements=%lld elementType=%@", (long long)_elementSize, (long long)_numberOfElements, _elementType];
}

@end
