//
//  GITRepo.m
//  CocoaGit
//
//  Created by Geoffrey Garside on 05/08/2008.
//  Copyright 2008 ManicPanda.com. All rights reserved.
//

#import "GITRepo.h"
#import "GITRepo+Protected.h"

#import "GITBranch.h"
#import "GITTag.h"

@interface GITRepo ()
@property(readwrite,copy) NSString * root;
@end

@implementation GITRepo

@synthesize root;
@synthesize desc;

- (id)initWithRoot:(NSString*)repoRoot
{
    if (self = [super init])
    {
        self.root = [repoRoot stringByAppendingPathComponent:@".git"];
        
        NSString * descFile = [self.root stringByAppendingPathComponent:@"description"];
        self.desc = [NSString stringWithContentOfFile:descFile];
    }
    return self;
}
- (NSString*)objectPathFromHash:(NSString*)hash
{
    NSString * dir = [self.root stringByAppendingPathComponent:@"objects"];
    NSString * ref = [NSString stringWithFormat:@"%@/%@",
        [hash substringToIndex:2], [hash substringFromIndex:2]];
    
    return [dir stringByAppendingPathComponent:ref];
}
- (NSData*)dataWithContentsOfHash:(NSString*)hash
{
    NSString * objectPath = [self objectPathFromHash:hash];
    return [[NSData dataWithContentsOfFile:objectPath] zlibInflate];
}
- (void)extractFromData:(NSData*)data
                   type:(NSString**)theType
                   size:(NSUInteger*)theSize
                andData:(NSData**)theData
{
    NSRange range = [data rangeOfNullTerminatedBytesFrom:0];
    NSData * meta = [data subdataWithRange:range];
    *theData = [data subdataFromIndex:range.length + 1];
    
    NSString * metaStr = [[NSString alloc] initWithData:meta
                                               encoding:NSASCIIStringEncoding];
    NSUInteger indexOfSpace = [metaStr rangeOfString:@" "].location;
    
    *theType = [metaStr substringToIndex:indexOfSpace];
    *theSize = [metaStr substringFromIndex:indexOfSpace + 1];
}

@end
