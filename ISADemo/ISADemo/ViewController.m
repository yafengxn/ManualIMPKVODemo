//
//  ViewController.m
//  ISADemo
//
//  Created by yafengxn on 2018/7/4.
//  Copyright © 2018年 yongche. All rights reserved.
//

#import "ViewController.h"
#import "Person.h"
#import "NSObject+yd_observation.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    

    Person *p = [[Person alloc] init];
    
    [p yd_addObserver:self forKey:@"age" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"oldValue : %@ ----  newValue : %@", oldValue, newValue);
    }];
    
    p.age = @(10);
    
    [p yd_removeObserver:self forKey:@"age"];
    
    p.age = @(20);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
