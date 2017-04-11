//
//  NSObject+FMDB.m
//  数据库操作测试
//
//  Created by 樊小聪 on 2017/4/6.
//  Copyright © 2017年 樊小聪. All rights reserved.
//

/*
 *  备注：根据模型创建对应的数据库表：基于FMDB 🐾
 */

#import "NSObject+FMDB.h"

#import "FMDB.h"

#import <objc/runtime.h>


#define DB_TEXT         @"TEXT"
#define DB_INTEGER      @"INTEGER"
#define DB_REAL         @"REAL"
#define DB_BLOB         @"BLOB"
#define DB_NULL         @"NULL"
#define DB_MODEL        @"MODEL"

#define DB_PRIMARY_KEY_TYPE  @"INTEGER PRIMARY KEY"
#define DB_PRIMARY_KEY_ID    @"PRIMARY_KEY_ID"

#define PROPERTY_NAME   @"name"
#define PROPERTY_TYPE   @"type"

/* 🐖 ***************************** 🐖 FMDBManager 🐖 *****************************  🐖 */

@interface FMDBManager : NSObject
@property (nonatomic, strong)FMDatabaseQueue *dbQueue;
/**
 *  单例实例创建方法
 */
+ (instancetype)shareInstance;
/**
 *  数据库文件的路径
 */
+ (NSString *)dbPath;
@end

@implementation FMDBManager
static FMDBManager *_instance = nil;
+ (instancetype)shareInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init];
    });
    return _instance;
}

+ (NSString *)dbPath
{
    /// 获取 document 文件的路径
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    /// 数据库文件路径
    NSString *filePath = [documentPath stringByAppendingPathComponent:@"Data"];
    
    /// 是否是 文件夹
    BOOL isDir;
    
    /// 标记文件夹路径是否存在
    BOOL isExist = [fileMgr fileExistsAtPath:filePath isDirectory:&isDir];
    
    if (!isExist || !isDir)
    {
        /// 路径不存在，创建文件夹路径
        [fileMgr createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:NULL error:NULL];
    }
    
    /// 获取文件的根路径
    filePath = [filePath stringByAppendingPathComponent:@"db.sqlite"];
    
    return filePath;
}

- (FMDatabaseQueue *)dbQueue
{
    if (_dbQueue == nil)
    {
        _dbQueue = [[FMDatabaseQueue alloc] initWithPath:[self.class dbPath]];
    }
    
    return _dbQueue;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    return _instance;
}

- (id)copyWithZone:(struct _NSZone *)zone
{
    return _instance;
}

@end



/* 🐖 ***************************** 🐖 FMDB 🐖 *****************************  🐖 */

@interface NSObject ()

/** 👀 主键 👀 */
@property (assign, nonatomic) NSInteger PRIMARY_KEY_ID;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation NSObject (FMDB)
#pragma clang diagnostic pop

#pragma mark - 👀 Setter & Getter Method 👀 💤

- (void)setPRIMARY_KEY_ID:(NSInteger)PRIMARY_KEY_ID
{
    objc_setAssociatedObject(self, @selector(PRIMARY_KEY_ID), @(PRIMARY_KEY_ID), OBJC_ASSOCIATION_ASSIGN);
}

- (NSInteger)PRIMARY_KEY_ID
{
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

#pragma mark - 🔓 👀 Public Method 👀

/**
 *  创建 数据库表（表名为：类名）
 *
 *  @return 创建成功返回 YES，创建失败返回 NO
 */
+ (BOOL)createTable
{
    /**
     *  建表规则：
            创建数据库 -> 通过运行时拿到模型所有的属性，属性类型 -> 添加一个主键属性 -> 将所有的属性，主键拼接成（符合sqlite语法）字段定义语句 -> 执行语句，创建表以及表字段 -> 重新拿到所有的属性名，以及数据库中所有的字段名；将这2个数组进行对比，一旦发现某个属性在数据库没有对应的字段（漏掉了），数据库立即新增字段 -> 关闭数据库
     */
    
    __weak typeof(self)weakSelf = self;
    
    /// 标记是否创建成功
    __block BOOL isSuccessful = YES;
    
    /// 拿到数据库操作对象
    FMDBManager *mgr = [FMDBManager shareInstance];
    
    [mgr.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        /// 创建库打开失败
        if (!db.open)
        {
            NSLog(@"数据库打开失败！");
            isSuccessful = NO;
            return;
        }
        
        /// 要创建的表的名称：根据当前模型的类名
        NSString *tableName = NSStringFromClass(weakSelf.class);
        
        /// 每个属性的数据库语言
        NSString *propertySql = [self fetchPropertyNameAndTypeSql];
        
        /// 创建表的数据库语言
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@);", tableName, propertySql];
        
        if (![db executeUpdate:sql])
        {
            /// 创建数据表失败
            isSuccessful = NO;
            *rollback = YES;
            return;
        }
        
        /// 数据库创建成功
        
        NSMutableArray *columns = [NSMutableArray array];

        /// 获取表格中的所有字段集合
        FMResultSet *resultSet = [db getTableSchema:tableName];
        
        while ([resultSet next]) {
            
            /// 取出 所有字段的名称
            NSString *column = [resultSet stringForColumn:PROPERTY_NAME];
            [columns addObject:column];
        }
        
        /// 获取模型中所有需要存储的属性
        NSDictionary *dic = [self fetchAllProperties];
        /// 获取模型中所有需要存储的属性的名称
        NSArray *propertyNames = dic[PROPERTY_NAME];
        NSArray *propertyTypes = dic[PROPERTY_TYPE];
        
        /// 匹配正则，将遗漏的属性重新添加到表中
        NSPredicate *predict = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columns];
        
        /// 遗漏的属性，需要重新添加到表中的属性
        NSArray *results = [propertyNames filteredArrayUsingPredicate:predict];
        
        /// 将遗漏的属性重新添加到表中
        for (NSString *propertyName in results)
        {
            /// 需要添加的属性的下标
            NSUInteger index = [propertyNames indexOfObject:propertyName];
            
            /// 需要添加的属性的类型
            NSString *propertyType = propertyTypes[index];
            
            NSString *fieldSql = [NSString stringWithFormat:@"%@ %@", propertyName, propertyType];
            
            /// 添加字段的 sql 语句
            NSString *addSql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@;", tableName, fieldSql];
            
            /// 添加失败
            if (![db executeUpdate:addSql])
            {
                isSuccessful = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    
    return isSuccessful;
}

/**
 *  清空 数据库表
 *
 *  @return 清空成功返回 YES，创建失败返回 NO
 */
+ (BOOL)clearTable
{
    FMDBManager *mgr = [FMDBManager shareInstance];
    
    __block BOOL isSuccess = NO;
    
     __weak typeof(self)weakSelf = self;
    
    [mgr.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *tableName = NSStringFromClass(weakSelf.class);
        
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@", tableName];
        
        isSuccess = [db executeUpdate:sql];
    }];
    
    return isSuccess;
}

#pragma mark  👀 增 👀 💤
/**
 *  保存模型数据到数据库
 */
- (BOOL)save
{
    return [self updateDatabaseWithUpdating:^NSString *(NSString *propertyName) {
        
        /// 当正在遍历模型属性的回调
        return [NSString stringWithFormat:@"%@,", propertyName];
        
    } updated:^NSString *(NSString *tableName, NSString *key, NSString *placeValue) {
        
        /// 当遍历完成之后的回调
        return [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@);", tableName, key, placeValue];
    }];
}

+ (BOOL)saveObjects:(NSArray *)objects
{
    __block BOOL isSuccess = YES;
    
    for (NSObject *obj in objects)
    {
        if ([obj isKindOfClass:self.class])
        {
            isSuccess = NO;
        }
        else
        {
            /// 存入数据库
            BOOL flag = [obj save];
            
            if (!flag)
            {
                isSuccess = NO;
            }
        }
    }
    
    return isSuccess;
}

#pragma mark  👀 删 👀 💤
/**
 *  从数据库是移除数据
 */
- (BOOL)remove
{
    /**
     *  删除思路分析：
        1. 判断该模型是否存在于数据库中
            通过模型的 主键字段 DB_PRIMARY_KEY_ID 来判断 该模型是否存在于数据库；因为 这个字段是我们动态添加进去的，所以 只有数据库中已经存在的模型才有这个字段
        2. 如果存在于数据库中，找到 DB_PRIMARY_KEY_ID 相匹配的值进行删除操作
     */
    
    __block BOOL isSuccess = NO;
    
    // 如果当前要删除的模型没有 DB_PRIMARY_KEY_ID 这个属性，则直接返回，删除失败
    if ([self containPropertyWithPropertyName:DB_PRIMARY_KEY_ID])
    {
        return NO;
    }
    
    __weak typeof(self)weakSelf = self;
    
    FMDBManager *mgr = [FMDBManager shareInstance];
    
    [mgr.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *tableName = NSStringFromClass(weakSelf.class);
        
        /// 获取模型中对应主键属性的值
        NSString *primaryValue = [weakSelf valueForKey:DB_PRIMARY_KEY_ID];
        
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = %@;", tableName, DB_PRIMARY_KEY_ID, primaryValue];
        
        isSuccess = [db executeUpdate:sql];
    }];
    
    return isSuccess;
}

+ (BOOL)removeObjects:(NSArray *)objects
{
    __block BOOL isSuccess = YES;
    
    for (NSObject *obj in objects)
    {
        if ([obj isKindOfClass:self.class])
        {
            isSuccess = NO;
        }
        else
        {
            /// 存入数据库
            BOOL flag = [obj remove];
            
            if (!flag)
            {
                isSuccess = NO;
            }
        }
    }
    
    return isSuccess;
}

/**
 *  根据条件删除数据
 *
 *  @param criteria 删除条件，类似于："age > 10 and name = li"
 */
+ (BOOL)removeObjectsByCriteria:(NSString *)criteria, ...
{
    /// 获取可变参数
    va_list ap;
    
    va_start(ap, criteria);
    NSString *fmt = [[NSString alloc] initWithFormat:criteria locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    __block BOOL isSuccess = NO;
    
    __weak typeof(self)weakSelf = self;
    
    FMDBManager *mgr = [FMDBManager shareInstance];
    
    [mgr.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *tableName = NSStringFromClass(weakSelf.class);

        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@;", tableName, fmt];
        
        isSuccess = [db executeUpdate:sql];
    }];
    
    return isSuccess;
}

#pragma mark 👀 改 👀 💤
/**
 *  更新数据
 */
- (BOOL)update
{
    /**
     *  根据主键 DB_PRIMARY_KEY_ID 从数据库中找到匹配的模型并将属性值修改
     */
    
    /// 如果当前要修改的模型没有 DB_PRIMARY_KEY_ID 这个属性，则直接返回，修改失败
    if ([self containPropertyWithPropertyName:DB_PRIMARY_KEY_ID])
    {
        return NO;
    }
    
    __weak typeof(self)weakSelf = self;
    
    return [self updateDatabaseWithUpdating:^NSString *(NSString *propertyName) {
        
        /// 当正在遍历模型属性的回调
        /**
         *  类型于："age=?,name=?"
         */
        return [NSString stringWithFormat:@"%@=?,", propertyName];
        
    } updated:^NSString *(NSString *tableName, NSString *key, NSString *placeValue) {
        
        /// 获取模型中对应主键属性的值
        NSString *primaryValue = [weakSelf valueForKey:DB_PRIMARY_KEY_ID];
        
        /// 当遍历完成之后的回调
        return [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = %@;", tableName, key, DB_PRIMARY_KEY_ID, primaryValue];
    }];

}

+ (BOOL)updateObjects:(NSArray *)objects
{
    __block BOOL isSuccess = YES;
    
    for (NSObject *obj in objects)
    {
        if ([obj isKindOfClass:self.class])
        {
            isSuccess = NO;
        }
        else
        {
            /// 更新数据库
            BOOL flag = [obj update];
            
            if (!flag)
            {
                isSuccess = NO;
            }
        }
    }
    
    return isSuccess;
}

#pragma mark 👀 查 👀 💤
/**
 *  从数据库中读取指定条件的数据
 *
 *  @param criteria 查询条件，类似于："age > 10 ORDER BY score DESC LIMIT 10"
 */
+ (NSArray *)fetchObjectsByCriteria:(NSString *)criteria, ...
{
    va_list ap;
    va_start(ap, criteria);
    NSString *fmt = [[NSString alloc] initWithFormat:criteria locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    /// 查询指定条件的数据
    return [self queryDatabaseWithFormat:[NSString stringWithFormat:@"WHERE %@", fmt]];

}

+ (NSArray *)fetchAll
{
    /// 查询数据库表中的所有模型
    return [self queryDatabaseWithFormat:NULL];
}

#pragma mark - 🔒 👀 Privite Method 👀

/**
 *  数据库操作（插入、更新）
 *
 *  updating：当遍历模型属性的时候的回调，有多少个属性就会执行多少次回调：返回一个拼接的属性名（sql）
 *  updated： 当遍历完成时的回调，返回具体的 sql 执行语句
 */
- (BOOL)updateDatabaseWithUpdating:(NSString *(^)(NSString *propertyName))updating
                           updated:(NSString *(^)(NSString *tableName, NSString *key, NSString *placeValue))updated
{
    __block BOOL isSuccess = NO;
    
    /**
     *  要存取的模型的属性的值
     */
    NSMutableArray *values = [NSMutableArray array];
    
    /**
     *  要存取的模型的属性名（sql语句：类似于 name,age,height）
     */
    NSMutableString *key = [NSMutableString string];
    
    /**
     *  要存取的模型属性的值的占位值（sql语句：?,?）
     */
    NSMutableString *placeValue = [NSMutableString string];
    
    /// 获取模型中所有需要存储的属性
    NSDictionary *dic = [self.class fetchAllProperties];
    
    /// 获取模型中所有需要存储的属性的名称
    NSArray *propertyNames = dic[PROPERTY_NAME];
    NSArray *propertyTypes = dic[PROPERTY_TYPE];
    
    for (NSInteger i = 0; i < propertyNames.count; i ++)
    {
        NSString *propertyName = propertyNames[i];
        NSString *propertyType = propertyTypes[i];
        
        /// 如果是主键，不处理
        if ([propertyName isEqualToString:DB_PRIMARY_KEY_ID])
        {
            continue;
        }
        
        id value = nil;
        
        /// 如果 属性类型是 数组 或者 其他模型 类型，要先进行反序列化为二进制数据
        if ([propertyType isEqualToString:DB_BLOB])
        {
            // 数组
            NSArray *array = [self valueForKey:propertyName];
            value = [NSKeyedArchiver archivedDataWithRootObject:array];
        }
        else if ([propertyType isEqualToString:DB_MODEL])
        {
            // 模型
            id model = [self valueForKey:propertyName];
            value = [NSKeyedArchiver archivedDataWithRootObject:model];
        }
        else
        {
            // 其他
            value = [self valueForKey:propertyName];
        }
        
        if (!value)
        {
            value = @"";
        }
        
        /// 添加到数组
        [values addObject:value];
        
        /// 拼接字符串
        if (updating)
        {
            [key appendString:updating(propertyName)];
        }
        
        [placeValue appendFormat:@"?,"];
    }
    
    /// 删除最后一个 ","
    [key deleteCharactersInRange:NSMakeRange(key.length-1, 1)];
    [placeValue deleteCharactersInRange:NSMakeRange(placeValue.length-1, 1)];
    
    /// 表名
    NSString *tableName = NSStringFromClass(self.class);
    
    NSString *sql = nil;
    
    if (updated)
    {
        sql = updated(tableName, key, placeValue);
    }
    
    if (!key.length || !sql)
    {
        return NO;
    }
    
    /// 执行数据库操作
    FMDBManager *mgr = [FMDBManager shareInstance];
    
    __weak typeof(self)weakSelf = self;
    
    [mgr.dbQueue inDatabase:^(FMDatabase *db) {
    
        isSuccess = [db executeUpdate:sql withArgumentsInArray:values];
        
        weakSelf.PRIMARY_KEY_ID = isSuccess ? [NSNumber numberWithLongLong:db.lastInsertRowId].intValue : 0;
    }];
    
    return isSuccess;
}

/**
 *  数据库查询操作
 *
 *  @param format 查询条件，类似于： "WHRER name > 10  ORDER BY score DESC LIMIT 10"，传空表示查询所有
 */
+ (NSArray *)queryDatabaseWithFormat:(NSString *)format
{
    FMDBManager *mgr = [FMDBManager shareInstance];
    
    NSMutableArray *objs = [NSMutableArray array];
    
    __weak typeof(self)weakSelf = self;
    
    [mgr.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *tableName = NSStringFromClass(weakSelf.class);
        
        /// 查询语句
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@;", tableName];
        
        if (format.length)
        {
            /// 查询指定条件
            sql = [NSString stringWithFormat:@"SELECT * FROM %@ %@;", tableName, format];
        }
        
        FMResultSet *resultSet = [db executeQuery:sql];
        
        while ([resultSet next])
        {
            NSObject *obj = [[weakSelf.class alloc] init];
            
            /// 获取模型中所有需要存储的属性
            NSDictionary *dic = [self fetchAllProperties];
            /// 获取模型中所有需要存储的属性的名称
            NSArray *propertyNames = dic[PROPERTY_NAME];
            NSArray *propertyTypes = dic[PROPERTY_TYPE];
            
            for (NSInteger i = 0; i < propertyNames.count; i ++)
            {
                // 属性名
                NSString *propertyName = propertyNames[i];
                // 属性类型
                NSString *propertyType = propertyTypes[i];
                
                id value = nil;
                
                if ([propertyType isEqualToString:DB_BLOB] ||
                    [propertyType isEqualToString:DB_MODEL])
                {
                    // 数组
                    // 模型
                    NSData *data = [resultSet dataForColumn:propertyName];
                    value = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                }
                else if ([propertyType isEqualToString:DB_TEXT])
                {
                    // 字符串
                    value = [resultSet stringForColumn:propertyName];
                }
                else
                {
                    // 整数
                    value = [NSNumber numberWithInteger:[resultSet intForColumn:propertyName]];
                }
                
                /// 给模型赋值
                [obj setValue:value forKey:propertyName];
            }
            
            
            [objs addObject:obj];
            FMDBRelease(obj);
        }
    }];
    
    return objs;
}

/**
 *  判断模型中是否存在对应的属性
 *
 *  @param name 属性名称
 */
- (BOOL)containPropertyWithPropertyName:(NSString *)name
{
    unsigned int outCount, i;
    
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    
    for (i = 0; i < outCount; i ++)
    {
        objc_property_t property = properties[i];
        
        /// 获取属性名称
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        
        BOOL hasContain = [propertyName isEqualToString:name];
        
        if (!hasContain)
        {
            free(properties);
            return NO;
        }
    }
    
    free(properties);
    
    return YES;
}

/**
 *  将模型的 属性名 和 属性类型 拼接成 sqlite 语句：integer a,real b,...
 */
+ (NSString *)fetchPropertyNameAndTypeSql
{
    NSMutableString *sql = [NSMutableString string];
   
    /*
        @{name:[@"primaryId",   propertyName1, propertyName2,...],
          type:[@"primaryType", propertyType1, propertyType2,...]}
     */
    NSDictionary *dic = [self fetchAllProperties];
    
    NSMutableArray *propertyNames = dic[PROPERTY_NAME];
    NSMutableArray *propertyTypes = dic[PROPERTY_TYPE];
    
    [propertyNames enumerateObjectsUsingBlock:^(NSString * _Nonnull propertyName, NSUInteger idx, BOOL * _Nonnull stop) {
        
        /// 属性类型
        NSString *propertyType = propertyTypes[idx];
        
        /*
         *  假如某个 模型对象有 age(NSInteger)，name(NSString) 等字段，则它们转化而成的数据库语句为：
         *  PRIMARY_KEY_ID INTEGER PRIMARY KEY, age INTEGER, name TEXT
         */
        [sql appendFormat:@"%@ %@", propertyName, propertyType];
        
        if (idx != propertyNames.count-1)
        {
            [sql appendFormat:@","];
        }
    }];
    
    return sql;
}

/**
 *  获取模型中的所有属性，并且添加一个主键字段pk。这些数据都存入一个字典中
 *
 *  @return   @{name:[@"primaryId",   propertyName1, propertyName2,...],
                type:[@"primaryType", propertyType1, propertyType2,...]}
 */
+ (NSDictionary *)fetchAllProperties
{
    NSDictionary *dic = [self fetchClassProperties];
    
    NSMutableArray *propertyNames = [NSMutableArray array];
    NSMutableArray *propertyTypes = [NSMutableArray array];
    
    /// 添加一个 主键 和 主键类型
    [propertyNames addObject:DB_PRIMARY_KEY_ID];
    [propertyNames addObjectsFromArray:dic[PROPERTY_NAME]];
    
    [propertyTypes addObject:DB_PRIMARY_KEY_TYPE];
    [propertyTypes addObjectsFromArray:dic[PROPERTY_TYPE]];
    
    return @{PROPERTY_NAME : propertyNames,
             PROPERTY_TYPE : propertyTypes};
}

/**
 *  获取该类中所有属性以及属性对应的类型
 *
 *  @return     @{name:[propertyName1, propertyName2,...],
                  type:[propertyType1, propertyType2,...]}
 */
+ (NSDictionary *)fetchClassProperties
{
    /// 存放模型中所有的属性名称
    NSMutableArray *propertyNames = [NSMutableArray array];
    
    /// 存放模型中所有属性对应的类型
    NSMutableArray *propertyTypes = [NSMutableArray array];
    
    /// 存放要忽略的属性的名称
    NSArray *ignorePropertyNames = [NSArray array];
    
    if ([self respondsToSelector:@selector(ignorePropertyNames)])
    {
        ignorePropertyNames = [self ignorePropertyNames];
    }
    
    unsigned int outCount, i;
    
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    
    for (i = 0; i < outCount; i ++)
    {
        objc_property_t property = properties[i];
        
        /// 获取属性名称
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        
        /// 过滤掉需要忽略的属性名称
        if ([ignorePropertyNames containsObject:propertyName])
        {
            continue;
        }
        
        /// 添加到 数据中
        [propertyNames addObject:propertyName];
        
        /// 获取 属性对应的类型
        NSString *propertyType = [NSString stringWithCString: property_getAttributes(property) encoding:NSUTF8StringEncoding];
        /*
         c char         C unsigned char
         i int          I unsigned int
         l long         L unsigned long
         s short        S unsigned short
         d double       D unsigned double
         f float        F unsigned float
         q long long    Q unsigned long long
         B BOOL
         @ 对象类型 //指针 对象类型 如NSString 是@“NSString”
         
         
         64位下long 和long long 都是Tq
         SQLite 默认支持五种数据类型TEXT、INTEGER、REAL、BLOB、NULL
         */
        
        if ([propertyType hasPrefix:@"T@\"NSArray\""]) {//属性类型是数组
            [propertyTypes addObject:DB_BLOB];
        }else if ([propertyType hasPrefix:@"T@\"NSString\""]){//@:字符串
            [propertyTypes addObject:DB_TEXT];
        }else if ([propertyType hasPrefix:@"T@"]){//以T@开头的类型，除了数组，字符串，也就只剩下模型类型了
            [propertyTypes addObject:DB_MODEL];
        }else if ([propertyType hasPrefix:@"Ti"]||[propertyType hasPrefix:@"TI"]    ||
                  [propertyType hasPrefix:@"Tq"]||[propertyType hasPrefix:@"TQ"]    ||
                  [propertyType hasPrefix:@"Ts"]||[propertyType hasPrefix:@"TS"]    ||
                  [propertyType hasPrefix:@"TB"]) {//i,I(integer):整型； s(short):短整型； B(BOOL):布尔；
            [propertyTypes addObject:DB_INTEGER];
        } else {
            [propertyTypes addObject:DB_REAL];
        }
    }
    
    free(properties);
    
    return @{PROPERTY_NAME : propertyNames,
             PROPERTY_TYPE : propertyTypes};
}

@end


