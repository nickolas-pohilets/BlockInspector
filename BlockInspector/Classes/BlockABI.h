//
//  BlockABI.h
//  BlockInspector
//
//  Created by Mykola Pokhylets on 29/09/2019.
//

#import <Foundation/Foundation.h>

// See https://clang.llvm.org/docs/Block-ABI-Apple.html
// See https://github.com/apportable/Foundation/blob/master/System/System/src/closure/Block_private.h

typedef void (*BIBlockInvokeFunction)(void *, ...);
typedef void (*BIBlockCopyHelper)(void *dst, void *src);
typedef void (*BIBlockDisposeHelper)(void *src);
typedef void (*BIByrefCopyHelper)(void *dst, void *src);
typedef void (*BIByrefDisposeHelper)(void *src);

typedef NS_ENUM(unsigned, BIExtendedLayoutOpCode) {
    BIExtendedLayoutOpCodeEscape         = 0,    // operand == 0 - halt, rest is non-pointer; operand != 0 - reserved.
    BIExtendedLayoutOpCodeNonObjectBytes = 1,    // operand+1 bytes non-objects
    BIExtendedLayoutOpCodeNonObjectWords = 2,    // operand+1 words non-objects
    BIExtendedLayoutOpCodeStrong         = 3,    // operand+1 words strong pointers
    BIExtendedLayoutOpCodeByref          = 4,    // operand+1 words byref pointers
    BIExtendedLayoutOpCodeWeak           = 5,    // operand+1 words weak pointers
    BIExtendedLayoutOpCodeUnretained     = 6,    // operand+1 words unretained pointers
};

typedef struct __attribute__((packed)) __attribute__((aligned(1))) {
    unsigned operand: 4;
    BIExtendedLayoutOpCode opcode: 4;
} BIExtendedLayoutRun;

/// Extended layout encoding.
///
/// If the layout field is less than 0x1000, then it is a compact encoding
/// of the form 0xXYZ: X strong pointers, then Y byref pointers,
/// then Z weak pointers.

/// If the layout field is 0x1000 or greater, it points to a
/// string of layout bytes. Each byte is of the form 0xPN.
/// Operator P is from the list below. Value N is a parameter for the operator.
/// Byte 0x00 terminates the layout; remaining block data is non-pointer bytes.
typedef union __attribute__((packed)) {
    struct {
        unsigned numWeak: 4;
        unsigned numByref: 4;
        unsigned numStrong: 4;
        unsigned long long zero: sizeof(void*) * CHAR_BIT - 12;
    } inlineLayout;
    BIExtendedLayoutRun *layoutString;
} BIExtendedLayout;

typedef struct {
    unsigned long int reserved;          // NULL
    unsigned long int size;              // sizeof(struct BIBlockLiteral)
} BIBlockDescriptor;

// optional helper functions, present if flags.hasCopyDispose
typedef struct {
    BIBlockCopyHelper copy_helper;
    BIBlockDisposeHelper dispose_helper;
} BIBlockDescriptorHelperFunctions;

// optional signature, present if flags.hasSignature
// required since ABI.2010.3.16
typedef struct {
    const char *signature;
} BIBlockDescriptorSignature;

// optional extendedn layout, present if flags.hasExtendedLayout
typedef struct {
    BIExtendedLayout layout;
} BIBlockDescriptorLayout;

typedef struct {
    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    struct __attribute__((packed)) {
        BOOL isDeallocating: 1;
        unsigned rc: 15;
        unsigned reserved: 7;
        // Set to true on blocks that have captures (and thus are not true
        // global blocks) but are known not to escape for various other
        // reasons. For backward compatiblity with old runtimes, whenever
        // BLOCK_IS_NOESCAPE is set, BLOCK_IS_GLOBAL is set too. Copying a
        // non-escaping block returns the original block and releasing such a
        // block is a no-op, which is exactly how global blocks are handled.
        BOOL isNoEscape: 1;
        BOOL needsFree: 1;
        BOOL hasCopyDispose: 1;
        BOOL hasCtor: 1; // helpers have C++ code
        BOOL isGC: 1;
        BOOL isGlobal: 1;
        BOOL useStructRect: 1; // if hasSignature, otherwise undefined
        BOOL hasSignature: 1;
        BOOL hasExtendedLayout: 1;
    } flags;
    int reserved;
    BIBlockInvokeFunction invoke;
    BIBlockDescriptor *descriptor;
    // imported variables
} BIBlockLiteral;

typedef NS_ENUM(NSUInteger, BIByrefLayout) {
    BIByrefLayoutExtended = 1,
    BIByrefLayoutNonObject = 2,
    BIByrefLayoutStrong = 3,
    BIByrefLayoutWeak = 4,
    BIByrefLayoutUnretained = 4,
};

typedef struct BIByrefVariable {
    void *isa;
    struct BIByrefVariable *forwarding;
    struct __attribute__((packed)) {
        BOOL isDeallocating: 1;
        unsigned rc: 15;
        unsigned reserved_1: 8;
        BOOL needsFree: 1;
        BOOL hasCopyDispose: 1;
        unsigned reserved_2: 1;
        BOOL isGC: 1;
        BIByrefLayout layout: 4;
    } flags;
    int size;
} BIByrefVariable;

// optional helper functions, present if flags.hasCopyDispose
// called via Block_copy() and Block_release()
typedef struct {
    BIByrefCopyHelper keep;
    BIByrefDisposeHelper dispose;
} BIByrefVariableHelperFunctions;

// optional extended layout, present if flags.layout == BIByrefLayoutExtended
typedef struct {
    BIExtendedLayout layout;
} BIByrefVariableLayout;
