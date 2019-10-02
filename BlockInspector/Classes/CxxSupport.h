//
//  CxxSupport.h
//  BlockInspector
//
//  Created by Mykola Pokhylets on 30/09/2019.
//

#import <Foundation/Foundation.h>

struct TypeInfo {
    size_t size;
    bool (*compare)(void const * a, void const * b);
    size_t (*hash)(void const * ptr);
};

#ifdef __cplusplus
extern "C" {
#endif

NSString * BIDemangleCxxType(NSString *mangledName);
BOOL BIGetTypeInfo(NSString *mangledName, struct TypeInfo *typeInfo);
void BIRegisterTypeInfo(id prototypeBlock, struct TypeInfo typeInfo);

#ifdef __cplusplus
}

#import <typeinfo>
#import <functional>

template<class T>
class _BICxxRegistryHelper {
    static bool compare(void const * a, void const * b) {
        return *static_cast<T const *>(a) == *static_cast<T const *>(b);
    }
    
    static size_t hash(void const * ptr) {
        return std::hash<T>()(*static_cast<T const*>(ptr));
    }
public:
    _BICxxRegistryHelper(): _BICxxRegistryHelper(T()) {}
    _BICxxRegistryHelper(T x) {
        typedef void (*Func)(T const &);
        id block = ^{ ((Func)nullptr)(x); };
        BIRegisterTypeInfo(block, (TypeInfo){
            .size = sizeof(T),
            .compare = &_BICxxRegistryHelper<T>::compare,
            .hash = &_BICxxRegistryHelper<T>::hash
        });
    };
};

#define _BIRegisterCxxType1(T, L) static _BICxxRegistryHelper<T> _biCxxType##L
#define _BIRegisterCxxType2(T, L) _BIRegisterCxxType1(T, L)
#define BIRegisterCxxType(T) _BIRegisterCxxType2(T, __LINE__)

#endif
