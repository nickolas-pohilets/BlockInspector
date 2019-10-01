//
//  BICapturedVariable.h
//  BlockInspector
//
//  Created by Mykola Pokhylets on 01/10/2019.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BICapturedVariableKind) {
    BICapturedVariableKindCXX = 1,
    BICapturedVariableKindWeak,
    BICapturedVariableKindStrong,
    BICapturedVariableKindAssign,
    BICapturedVariableKindByref,
    BICapturedVariableKindBlock,
    BICapturedVariableKindNonTrivialStruct,
    BICapturedVariableKindNonTrivialArray,
};

@interface BICapturedVariable : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) NSInteger offset;
@property (nonatomic, readonly) NSInteger size;
@property (nonatomic, readonly) BICapturedVariableKind kind;

@end

@interface BICxxCapturedVariable: BICapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset mangledCxxClassName:(NSString *)mangledCxxClassName;

@property (nonatomic, readonly, copy) NSString *mangledCxxClassName;
@property (nonatomic, readonly, copy, nullable) NSString *demangledCxxClassName;

@end

@interface BIWeakCapturedVariable: BICapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset;

@end

@interface BIStrongCapturedVariable: BICapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset;

@end

@interface BIAssignCapturedVariable: BICapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset size:(NSInteger)size;

@end

@interface BIByrefCapturedVariable: BICapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset;

@end

@interface BIBlockCapturedVariable: BICapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset;

@end

@interface BINonTrivialStructCapturedVariable: BICapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset children:(NSArray<BICapturedVariable *> *)children;

@property (nonatomic, readonly, copy) NSArray<BICapturedVariable *> *children;

@end

@interface BINonTrivialArrayCapturedVariable: BICapturedVariable

- (instancetype)initWithOffset:(NSInteger)offset
                   elementSize:(NSInteger)elementSize
              numberOfElements:(NSInteger)numberOfElements
                   elementType:(BINonTrivialStructCapturedVariable *)elementType;

@property (nonatomic, readonly) NSInteger elementSize;
@property (nonatomic, readonly) NSInteger numberOfElements;
@property (nonatomic, readonly, copy) BINonTrivialStructCapturedVariable *elementType;

@end

NS_ASSUME_NONNULL_END
