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
void BIRegisterTypeInfo(NSString *mangledName, struct TypeInfo typeInfo);

#ifdef __cplusplus
}

#import <typeinfo>
#import <functional>

template<class T>
class BIRegisterCxxType {
    static bool compare(void const * a, void const * b) {
        return *static_cast<T const *>(a) == *static_cast<T const *>(b);
    }
    
    static size_t hash(void const * ptr) {
        return std::hash<T>()(*static_cast<T const*>(ptr));
    }
    BIRegisterCxxType() {
        NSString *name = [NSString stringWithUTF8String:typeid(T).name()];
        BIRegisterTypeInfo(name, (TypeInfo){
            .size = sizeof(T),
            .compare = &BIRegisterCxxType<T>::compare,
            .hash = &BIRegisterCxxType<T>::hash
        });
    };
};

#define BIRegisterCxxType(T) static BIRegisterCxxType<T> _biCxxType##__LINE__;

#endif
