// CVConfig.mm

#include "CVConfig.h"

BOOL CVTimeStampEqual(const CVTimeStamp *s1, const CVTimeStamp *s2) {
    return !memcmp(s1, s2, sizeof(CVTimeStamp));
}

CVTimeStamp CVGetFileTimeStamp(NSString *filename) {
    const char *f=[filename UTF8String];
    struct stat s;
    CVTimeStamp t;
    bzero(&t, sizeof(t));
    if (f && !stat(f, &s)) t=s.st_mtimespec;
    return t;
}

NSMutableDictionary *CVReadPropertyList(NSString *filename) {
    NSData *d=[NSData dataWithContentsOfFile:filename];
    if (d) {        
        NSString *errMsg;
        NSPropertyListFormat fmt;
        
        // note p is already autoreleased (just like [NSString stringWith...])
        id p=[NSPropertyListSerialization propertyListFromData:d
            mutabilityOption:NSPropertyListMutableContainersAndLeaves 
            format:&fmt errorDescription:&errMsg];
        if (p) {
            if ([p isKindOfClass: [NSMutableDictionary class]]) {
                fprintf(stderr, "data read! content=%s\n",
                    [[p description] UTF8String]);
                return p;
            }
        }
    }
    return nil;
}

CVTimeStamp CVWritePropertyList(NSString *filename, NSDictionary *dict) {
    NSString *errMsg;
    NSData *d=[NSPropertyListSerialization dataFromPropertyList:dict
        format:NSPropertyListXMLFormat_v1_0 errorDescription:&errMsg];
    [d writeToFile:filename atomically:YES];
    return CVGetFileTimeStamp(filename);
}

@implementation CVConfig
-(CVConfig*)initWithFile:(NSString*)f defaultData:(NSDictionary*)d
{
    if (self=[super init]) {
        filename=[[NSString alloc] initWithString: [f stringByStandardizingPath]];
        dict=[NSMutableDictionary new];
        backup=[NSMutableDictionary new];
        
        stamp=CVGetFileTimeStamp(filename);
        NSDictionary *p=CVReadPropertyList(filename);
        if (!p) p=d;
        
        if (p) {
            [dict addEntriesFromDictionary:p];
            [backup release];
            backup=[[NSMutableDictionary alloc] initWithDictionary:dict copyItems:YES];
        }
    }
    return self;
}
-(void)dealloc {
    [filename release];
    [dict release];
    [backup release];
    [super dealloc];
}
-(CVTimeStamp)timeStamp {
    return stamp;
}
-(CVTimeStamp)sync {
    // check timestamp
    CVTimeStamp newstamp=CVGetFileTimeStamp(filename);
    if (!CVTimeStampEqual(&newstamp, &stamp)) {
        NSDictionary *p=CVReadPropertyList(filename);
        if (p) {
            [dict removeAllObjects];
            [dict addEntriesFromDictionary: p];
            [backup release];
            backup=[[NSMutableDictionary alloc] initWithDictionary:dict copyItems:YES];
        }
        return stamp=newstamp;
    }

    if ([dict isEqualToDictionary:backup]) return stamp;
    stamp=CVWritePropertyList(filename, dict);
    [backup release];
    backup=[[NSMutableDictionary alloc] initWithDictionary:dict copyItems:YES];
    return stamp;
}
-(NSMutableDictionary*)dictionary {
    return dict;
}
-(BOOL)needSync {
    // first we check if there's any need to read
    CVTimeStamp newstamp=CVGetFileTimeStamp(filename);
    if (!CVTimeStampEqual(&newstamp, &stamp)) return YES;
    
    // now check if there's any need to write
    if (![dict isEqualToDictionary:backup]) return YES;
    return NO;
}
@end