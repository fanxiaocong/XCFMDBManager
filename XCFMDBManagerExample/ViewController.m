//
//  ViewController.m
//  数据库操作测试
//
//  Created by 樊小聪 on 2017/4/6.
//  Copyright © 2017年 樊小聪. All rights reserved.
//

#import "ViewController.h"

#import "Person.h"
#import "Student.h"

#import "NSObject+FMDB.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *ageF;

@property (weak, nonatomic) IBOutlet UITextField *nameF;

@property (weak, nonatomic) IBOutlet UITextField *queryAgeF;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)save:(id)sender {
    
    Person *p = [[Person alloc] init];
    
    p.name = self.nameF.text;
    p.age  = self.ageF.text.integerValue;
    p.infos = @[self.nameF.text, self.nameF.text, self.nameF.text];
    
    [Person createTable];
    
    BOOL success = [p save];
    
    if (success)
    {
        NSLog(@"插入成功");
    }
    else
    {
        NSLog(@"插入失败");
    }
    
    [self printPerson];
}

- (IBAction)update:(id)sender {
    
    Person *p = [[Person fetchAll] lastObject];

    p.age = self.ageF.text.integerValue;
    p.name = self.nameF.text;
    
//    Person *p = [Person new];
//    p.age = 999;
//    p.name = @"错误数据";
    
    BOOL success = [p update];
    
    if (success)
    {
        NSLog(@"更新成功");
    }
    else
    {
        NSLog(@"更新失败");
    }
    
    [self printPerson];
}

- (IBAction)clear:(id)sender {
    
    BOOL success = [Person clearTable];
    
    if (success)
    {
        NSLog(@"清空表格成功");
    }
    else
    {
        NSLog(@"清空表格失败");
    }
    
    [self printPerson];
}

- (IBAction)delete:(id)sender
{
//    BOOL success = [Person removeObjectsByCriteria:@"age > %@", self.queryAgeF.text];
    
//    BOOL success = [[Person new] remove];
    
//    Person *p = [[Person fetchAll] firstObject];
//    BOOL success = [p remove];
    
    Person *p = [Person new];
    BOOL success = [p remove];
    
    if (success)
    {
        NSLog(@"删除成功");
    }
    else
    {
        NSLog(@"删除失败");
    }
    
    [self printPerson];
}

- (IBAction)query:(id)sender
{
    [self printPerson];
}

- (void)printPerson
{
    NSArray *array = [NSArray array];
    
    if (!self.queryAgeF.text.length) 
    {
        // 查询所有数据
        array = [Person fetchAll];
    }
    else
    {        
        // 查询指定数据
        array = [Person fetchObjectsByCriteria:@"age > %@", self.queryAgeF.text];
    }
    
    for (Person *p in array)
    {
        NSLog(@"p---name:   %@", p.name);
        NSLog(@"p---age:    %zi", p.age);
        NSLog(@"p---infos:  %@", p.infos);
    }
}


@end


