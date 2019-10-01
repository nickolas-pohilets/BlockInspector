//
//  BIBlockInspector.h
//  BlockInspector
//
//  Created by Mykola Pokhylets on 29/09/2019.
//

#import "BlockABI.h"
#import "BICapturedVariable.h"

NS_ASSUME_NONNULL_BEGIN

@interface BIBlockInspector : NSObject

+ (NSString *)nameOfFunction:(void *)function;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBlock:(id)block NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) id block;
@property (nonatomic, readonly) BIBlockLiteral *blockLiteral;
@property (nonatomic, readonly) BIBlockDescriptor *blockDescriptor;
@property (nonatomic, readonly) BIBlockInvokeFunction invoke;
@property (nonatomic, readonly, copy) NSString *nameOfInvoke;
@property (nonatomic, readonly, nullable) BIBlockCopyHelper copyHelper;
@property (nonatomic, readonly, copy, nullable) NSString *nameOfCopyHelper;
@property (nonatomic, readonly, nullable) BIBlockDisposeHelper disposeHelper;
@property (nonatomic, readonly, copy, nullable) NSString *nameOfDisposeHelper;
@property (nonatomic, readonly) NSUInteger size;
@property (nonatomic, readonly) BOOL isNoEscape;
@property (nonatomic, readonly) BOOL isGlobal;
@property (nonatomic, readonly) BOOL hasStructReturn;
@property (nonatomic, readonly) BOOL hasSignature;
@property (nonatomic, readonly, nullable) char const * signatureEncoding;
@property (nonatomic, readonly, nullable) NSMethodSignature *signature;
@property (nonatomic, readonly, copy, nullable) NSArray<BICapturedVariable *> *capturedVariables;

@end

NS_ASSUME_NONNULL_END
