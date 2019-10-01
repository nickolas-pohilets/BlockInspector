//
//  BlockABI.h
//  BlockInspector
//
//  Created by Mykola Pokhylets on 29/09/2019.
//

#import <Foundation/Foundation.h>

// See https://clang.llvm.org/docs/Block-ABI-Apple.html

typedef NS_OPTIONS(int, BIBlockFlags) {
    // Set to true on blocks that have captures (and thus are not true
    // global blocks) but are known not to escape for various other
    // reasons. For backward compatiblity with old runtimes, whenever
    // BLOCK_IS_NOESCAPE is set, BLOCK_IS_GLOBAL is set too. Copying a
    // non-escaping block returns the original block and releasing such a
    // block is a no-op, which is exactly how global blocks are handled.
    BLOCK_IS_NOESCAPE      =  (1 << 23),

    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30),
};

typedef void (*BIBlockInvokeFunction)(void *, ...);
typedef void (*BIBlockCopyHelper)(void *dst, void *src);
typedef void (*BIBlockDisposeHelper)(void *src);

typedef struct {
    unsigned long int reserved;          // NULL
    unsigned long int size;              // sizeof(struct BIBlockLiteral)
    // optional helper functions
    BIBlockCopyHelper copy_helper;       // IFF (1<<25)
    BIBlockDisposeHelper dispose_helper; // IFF (1<<25)
    // required ABI.2010.3.16
    const char *signature;               // IFF (1<<30)
} BIBlockDescriptor;

typedef struct {
    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    int flags;
    int reserved;
    BIBlockInvokeFunction invoke;
    BIBlockDescriptor *descriptor;
    // imported variables
} BIBlockLiteral;
