//
//  GITUser.m
//  CocoaGit
//
//  Created by Geoffrey Garside on 01/07/2008.
//  Copyright 2008 ManicPanda.com. All rights reserved.
//

#import "GITActor.h"

@interface GITActor ()
@property(readwrite,copy) NSString * name;
@property(readwrite,copy) NSString * email;
@end

@implementation GITActor

@synthesize name;
@synthesize email;

- (id)initWithName:(NSString*)theName
{
    return [self initWithName:theName andEmail:nil];
}
- (id)initWithName:(NSString*)theName andEmail:(NSString*)theEmail
{
    if (self = [super init])
    {
        self.name = theName;
        self.email = theEmail;
    }
    return self;
}
- (void)dealloc
{
    self.name = nil;
    self.email = nil;
    [super dealloc];
}
- (NSString*)description
{
    if (self.email)
        return [NSString stringWithFormat:@"%@ <%@>",
                self.name, self.email];
    else
        return self.name;
}

@end