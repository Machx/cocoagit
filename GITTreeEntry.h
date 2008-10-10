//
//  GITTreeEntry.h
//  CocoaGit
//
//  Created by Geoffrey Garside on 05/08/2008.
//  Copyright 2008 ManicPanda.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern const NSUInteger kGITPackedSha1Length;
extern const NSUInteger kGITUnpackedSha1Length;

@class GITRepo;
@interface GITTreeEntry : NSObject
{
    GITRepo  * repo;
    NSString * name;
    NSUInteger mode;
    
    NSString * sha1;
    id object;
}

@property(readonly,copy) GITRepo * repo;
@property(readonly,copy) NSString * name;
@property(readonly,assign) NSUInteger mode;
@property(readonly,copy) NSString * sha1;
@property(readonly,copy) id object;

- (id)initWithTreeLine:(NSString*)treeLine repo:(GITRepo*)theRepo;
- (id)initWithMode:(NSUInteger)mode name:(NSString*)name hash:(NSString*)hash repo:(GITRepo*)theRepo;
- (id)initWithModeString:(NSString*)mode name:(NSString*)name hash:(NSString*)hash repo:(GITRepo*)theRepo;

@end
