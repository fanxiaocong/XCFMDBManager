//
//  Person.h
//  数据库操作测试
//
//  Created by 樊小聪 on 2017/4/6.
//  Copyright © 2017年 樊小聪. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Student.h"

@interface Person : NSObject

@property(nonatomic, copy)NSString *name;
@property(nonatomic, assign)NSInteger age;
@property(nonatomic, strong)NSArray *infos;
@property(nonatomic, strong)Student *user;

@end
