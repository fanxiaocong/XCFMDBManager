//
//  NSObject+FMDB.h
//  数据库操作测试
//
//  Created by 樊小聪 on 2017/4/6.
//  Copyright © 2017年 樊小聪. All rights reserved.
//

/*
 *  备注：根据模型创建对应的数据库表：基于FMDB 🐾
 */

#import <Foundation/Foundation.h>

@interface NSObject (FMDB)

/**
 *  创建 数据库表（表名为：类名）
 *
 *  @return 创建成功返回 YES，创建失败返回 NO
 */
+ (BOOL)createTable;

/**
 *  清空 数据库表
 *
 *  @return 清空成功返回 YES，创建失败返回 NO
 */
+ (BOOL)clearTable;

/**
 *  不需要存到数据库表中的属性名称：由具体的模型去实现
 */
+ (NSArray<NSString *> *)ignorePropertyNames;

#pragma mark - 👀 增 👀 💤
/**
 *  保存模型数据到数据库
 */
- (BOOL)save;
+ (BOOL)saveObjects:(NSArray *)objects;

#pragma mark - 👀 删 👀 💤
/**
 *  从数据库是移除数据
 */
- (BOOL)remove;
+ (BOOL)removeObjects:(NSArray *)objects;
/**
 *  根据条件删除数据
 *
 *  @param criteria 删除条件，类似于："age > 10 AND name = li"
 */
+ (BOOL)removeObjectsByCriteria:(NSString *)criteria, ...;

#pragma mark - 👀 改 👀 💤
/**
 *  更新数据
 */
- (BOOL)update;
+ (BOOL)updateObjects:(NSArray *)objects;

#pragma mark - 👀 查 👀 💤
/**
 *  从数据库中读取指定条件的数据
 *
 *  @param criteria 查询条件，类似于："age > 10 ORDER BY score DESC LIMIT 10"
 */
+ (NSArray *)fetchObjectsByCriteria:(NSString *)criteria, ...;
+ (NSArray *)fetchAll;

@end
