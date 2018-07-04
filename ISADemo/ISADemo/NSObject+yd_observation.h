//
//  NSObject+yd_observation.h
//  ISADemo
//
//  Created by yafengxn on 2018/7/4.
//  Copyright © 2018年 yongche. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^YDObservingBlock)(id observedObject,
                                 NSString *observedKey,
                                 id oldValue,
                                 id newValue);

@interface NSObject (yd_observation)

- (void)yd_addObserver:(NSObject *)observer
                forKey:(NSString *)key
             withBlock:(YDObservingBlock)block;

- (void)yd_removeObserver:(NSObject *)observer forKey:(NSString *)key;

@end
