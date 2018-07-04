//
//  NSObject+yd_observation.m
//  ISADemo
//
//  Created by yafengxn on 2018/7/4.
//  Copyright © 2018年 yongche. All rights reserved.
//

#import "NSObject+yd_observation.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface YDObserverationInfo : NSObject

@property (nonatomic, weak) NSObject *observer;

@property (nonatomic, copy) NSString *key;

@property (nonatomic, copy) YDObservingBlock block;

- (instancetype)initWithObserver:(NSObject *)observer
                             key:(NSString *)key
                           block:(YDObservingBlock)block;

@end

@implementation YDObserverationInfo

- (instancetype)initWithObserver:(NSObject *)observer
                             key:(NSString *)key
                           block:(YDObservingBlock)block
{
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}

@end


static NSString *kYDKVOClassPrefix = @"YDKVONotifying_";

const char *kKVOObserverKey = "kKVOObserverKey";

NSString *setterForGetter(NSString *key) {
    
    NSString *setterName = [NSString stringWithFormat:@"set%@:", [key capitalizedString]];
    
    return setterName;
}

NSString *getterForSetter(NSString *key) {
    
    NSString *getterName = [key substringFromIndex:3];
    getterName = [[getterName lowercaseString] substringToIndex:getterName.length - 1];
    
    return getterName;
}


static Class kvo_class(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}

static void kvo_setter(id self, SEL _cmd, id newValue)
{
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(setterName);
    
    if (!getterName) {
        NSString *exceptionString = [NSString stringWithFormat:@"invalid argument %@", getterName];
        NSException *exception = [NSException exceptionWithName:@"YDException" reason:exceptionString userInfo:nil];
        [exception raise];
    }
    
    // 获取旧值
    id oldValue = [self valueForKey:getterName];
    
    struct objc_super superclazz = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    
    // 调用父类 setter 方法
    objc_msgSendSuperCasted(&superclazz, _cmd, newValue);
    
    NSMutableArray *observers = objc_getAssociatedObject(self, kKVOObserverKey);
    for (YDObserverationInfo *info in observers) {
        if ([info.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                info.block(info.observer, info.key, oldValue, newValue);
            });
        }
    }
    
}


@interface NSObject ()

@property (nonatomic, strong) NSMutableArray *observers;

@end

@implementation NSObject (yd_observation)

- (void)yd_addObserver:(NSObject *)observer
                forKey:(NSString *)key
             withBlock:(YDObservingBlock)block
{
    // 1.查找不到该key对应的setter方法，抛出异常
    SEL setterSelector = NSSelectorFromString(setterForGetter(key));
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (!setterMethod) { // 如果该类没有实现 key 的setter方法，抛出异常
        NSString *exceptionString = [NSString stringWithFormat:@"invalid %@ for class %@",  NSStringFromSelector(setterSelector), [self class]];
        NSException *exception = [NSException exceptionWithName:@"YDException" reason:exceptionString userInfo:nil];
        [exception raise];
    }
    
    // 2.创建观察者类
    Class clazz = object_getClass(self);
    NSString *clazzName = NSStringFromClass(clazz);
    if (![clazzName hasPrefix:kYDKVOClassPrefix]) { // 如果当前类没有观察者类的前缀，创建观察者并实现 setter 方法，将实例 isa 指向新创建的观察者类
        clazz = [self createKVOClassWithOriginalClassName:clazzName];
        object_setClass(self, clazz);
    }
    
    // 3.如果观察者类没有实现我们自己的 setter 方法，则添加
    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(clazz, setterSelector, (IMP)kvo_setter, types);
    }
    
    
    // 4.添加观察者信息
    YDObserverationInfo *info = [[YDObserverationInfo alloc] initWithObserver:observer key:key block:block];
    NSMutableArray *observers = [self observers];
    if (!observers) {
        observers = [NSMutableArray array];
        [self setObservers:observers];
    }
    [observers addObject:info];
}

- (void)yd_removeObserver:(NSObject *)observer forKey:(NSString *)key
{
    YDObserverationInfo *observation;
    NSMutableArray *observers = [self observers];
    for (YDObserverationInfo *info in observers) {
        if (observer == info.observer && [info.key isEqualToString:key]) {
            observation = info;
            break;
        }
    }
    if (observation) {
        [observers removeObject:observation];
    }
}


- (Class)createKVOClassWithOriginalClassName:(NSString *)originalClazzName
{
    NSString *kvoClazzName = [kYDKVOClassPrefix stringByAppendingString:originalClazzName];
    
    Class clazz = NSClassFromString(kvoClazzName);
    
    // 如果clazz已存在，就直接返回该类
    if (clazz) {
        return clazz;
    }
    
    // 如果 clazz 不存在，就创建
    Class originalClazz = object_getClass(self);
    Class kvoClazz = objc_allocateClassPair(originalClazz, kvoClazzName.UTF8String, 0);
    Method clazzMethod = class_getInstanceMethod(kvoClazz, @selector(class));
    const char *types = method_getTypeEncoding(clazzMethod);
    class_addMethod(kvoClazz, @selector(class), (IMP)kvo_class, types);
    
    objc_registerClassPair(kvoClazz);
    
    return kvoClazz;
}


- (BOOL)hasSelector:(SEL)selector
{
    Class clazz = object_getClass(self);
    unsigned int count;
    Method *methodList = class_copyMethodList(clazz, &count);
    for (unsigned int i = 0; i < count; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    
    free(methodList);
    return NO;
}


- (void)setObservers:(NSMutableArray *)observers {
    objc_setAssociatedObject(self, kKVOObserverKey, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray *)observers {
    return objc_getAssociatedObject(self, kKVOObserverKey);
}

@end
