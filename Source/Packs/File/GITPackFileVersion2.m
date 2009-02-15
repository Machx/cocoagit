//
//  GITPackFileVersion2.m
//  CocoaGit
//
//  Created by Geoffrey Garside on 04/11/2008.
//  Copyright 2008 ManicPanda.com. All rights reserved.
//

#import "GITPackFileVersion2.h"
#import "GITPackIndex.h"
#import "GITUtilityBelt.h"
#import "NSData+Hashing.h"
#import "NSData+Compression.h"
#import "NSData+Patching.h"

static const NSRange kGITPackFileObjectCountRange = { 8, 4 };

enum {
    // Base Types - These mirror those of GITObjectType
    kGITPackFileTypeCommit = 1,
    kGITPackFileTypeTree   = 2,
    kGITPackFileTypeBlob   = 3,
    kGITPackFileTypeTag    = 4,

    // Delta Types
    kGITPackFileTypeDeltaOfs  = 6,
    kGITPackFileTypeDeltaRefs = 7
};

/*! \cond */
@interface GITPackFileVersion2 ()
@property(readwrite,copy) NSString * path;
@property(readwrite,retain) NSData * data;
@property(readwrite,retain) GITPackIndex * index;
- (NSData*)objectAtOffset:(NSUInteger)offset;
- (NSRange)rangeOfPackedObjects;
- (NSRange)rangeOfChecksum;
- (NSData*)checksum;
- (NSString*)checksumString;
- (BOOL)verifyChecksum;
@end
/*! \endcond */

@implementation GITPackFileVersion2
@synthesize path;
@synthesize data;
@synthesize index;

#pragma mark -
#pragma mark Primitive Methods
- (void) dealloc
{
    [path release], path = nil;
    [data release], data = nil;
    [index release], index = nil;
    [super dealloc];
}

- (NSUInteger)version
{
    return 2;
}
- (id)initWithData:(NSData *)packData error:(NSError **)error;
{
    if (! [super init])
        return nil;
    
    if (!packData) {
        [self release];
        return nil;
    }
    
    [self setData:packData];
    
    // Verify the data checksum
    if (! [self verifyChecksum]) {
        NSString * errDesc = NSLocalizedString(@"PACK file checksum failed", @"GITErrorPackFileChecksumMismatch");
        GITErrorWithInfo(error, GITErrorPackFileChecksumMismatch, errDesc, NSLocalizedDescriptionKey, nil);
        [self release];
        return nil;
    }
        
    return self;
}

- (id)initWithPath:(NSString*)thePath indexPath:(NSString *)idxPath error:(NSError **)error;
{
    NSData *packData = [NSData dataWithContentsOfFile:thePath
                                              options:NSUncachedRead
                                                error:error];
    
    if (! packData)
        return nil;
    
    if (! [self initWithData:packData error:error])
        return nil;
    
    self.path = thePath;
    self.index  = [GITPackIndex packIndexWithPath:idxPath error:error];
    
    if (! index) {
        [self release];
        return nil;
    }
    
    return self;
}

- (id)initWithPath:(NSString*)thePath error:(NSError **)error
{
    NSString * idxPath = [[thePath stringByDeletingPathExtension]
                          stringByAppendingPathExtension:@"idx"];
    return [self initWithPath:thePath indexPath:idxPath error:error];
}

- (NSUInteger)numberOfObjects
{
    if (!numberOfObjects)
    {
        uint32_t value;
        [self.data getBytes:&value range:kGITPackFileObjectCountRange];
        numberOfObjects = CFSwapInt32BigToHost(value);
    }
    return numberOfObjects;
}
- (NSData*)dataForObjectWithSha1:(NSString*)sha1
{
    // We've defined it this way so if we can determine a better way
    // to test for hasObjectWithSha1 then packOffsetForSha1 > 0
    // then we can simply change the implementation in GITPackIndex.
    if (![self hasObjectWithSha1:sha1]) return nil;
    
    if (! self.index) return nil;

    NSUInteger offset = [self.index packOffsetForSha1:sha1];
    NSData * raw = [self objectAtOffset:offset];
    return [raw zlibInflate];
}
- (BOOL)loadObjectWithSha1:(NSString*)sha1 intoData:(NSData**)objectData
                      type:(GITObjectType*)objectType error:(NSError**)error
{
    uint8_t buf = 0x0;    // a single byte buffer
    NSUInteger size, type, shift = 4;
    
    if (! self.index) {
        GITError(error, GITErrorPackIndexNotAvailable, @"This packfile is not indexed");
    }
    
    NSUInteger offset = [self.index packOffsetForSha1:sha1 error:error];

    if (offset == NSNotFound)
        return NO;
	
	[self.data getBytes:&buf range:NSMakeRange(offset++, 1)];
	NSAssert(buf != 0x0, @"buf should not be NULL");
	
	size = buf & 0xf;
	type = (buf >> 4) & 0x7;
	
	while ((buf & 0x80) != 0)
	{
		[self.data getBytes:&buf range:NSMakeRange(offset++, 1)];
		NSAssert(buf != 0x0, @"buf should not be NULL");
		
		size |= ((buf & 0x7f) << shift);
		shift += 7;
	}
	
    NSData *objData;
	switch (type) {
		case kGITPackFileTypeCommit:
		case kGITPackFileTypeTree:
		case kGITPackFileTypeTag:
		case kGITPackFileTypeBlob:
			objData = [[self.data subdataWithRange:NSMakeRange(offset, size)] zlibInflate];
			break;
		case kGITPackFileTypeDeltaOfs:
			NSAssert(NO, @"Cannot handle Delta-Offset Object types yet");
			break;
        case kGITPackFileTypeDeltaRefs:
        {
            NSData *baseSha1Data = [self.data subdataWithRange:NSMakeRange(offset, 20)];
            NSData *deltaData = [self.data subdataWithRange:NSMakeRange(offset + 20, size)];

            NSString *baseObjectSha1 = unpackSHA1FromData(baseSha1Data);
            if (! [self hasObjectWithSha1:baseObjectSha1]) {
                GITError(error, GITErrorObjectNotFound, NSLocalizedString(@"Object not found for PACK delta", @"GITErrorObjectNotFound (GITPackFile)"));
                return NO;
            }

            NSData *baseObjectData;

            if (! [self loadObjectWithSha1:baseObjectSha1 intoData:&baseObjectData type:objectType error:error]) {
                return NO;
            }

            [baseObjectData retain];
            objData = [baseObjectData dataByPatchingWithDelta:deltaData];
            [baseObjectData release];
            break;
        }
		default:
			NSLog(@"bad object type %d", type);
			break;
	}
	
	// Similar to situation in GITFileStore: we could create different errors for each of these.
	if (! (objData && type && size == [objData length])) {
		GITError(error, GITErrorObjectSizeMismatch, NSLocalizedString(@"Object size mismatch", @"GITErrorObjectSizeMismatch"));
		return NO;
	}
    
    *objectType = type;
    *objectData = objData;
	
	return YES;
}

#pragma mark -
#pragma mark Internal Methods
- (NSData*)objectAtOffset:(NSUInteger)offset
{
    uint8_t buf;    // a single byte buffer
    NSUInteger size, type, shift = 4;
    
    // NOTE: ++ should increment offset after the range has been created
    [self.data getBytes:&buf range:NSMakeRange(offset++, 1)];

    size = buf & 0xf;
    type = (buf >> 4) & 0x7;
    
    while ((buf & 0x80) != 0)
    {
        // NOTE: ++ should increment offset after the range has been created
        [self.data getBytes:&buf range:NSMakeRange(offset++, 1)];
        size |= ((buf & 0x7f) << shift);
        shift += 7;
    }
    
	//NSLog(@"offset: %d size: %d type: %d", offset, size, type);
	
	NSData *objectData = nil;
	switch (type) {
		case kGITPackFileTypeCommit:
		case kGITPackFileTypeTree:
		case kGITPackFileTypeTag:
		case kGITPackFileTypeBlob:
			objectData = [self.data subdataWithRange:NSMakeRange(offset, size)];
			break;
		case kGITPackFileTypeDeltaOfs:
		case kGITPackFileTypeDeltaRefs:
			NSAssert(NO, @"Cannot handle Delta Object types yet");
			break;
		default:
			NSLog(@"bad object type %d", type);
			break;
	}
	
    return objectData; 
}
- (NSRange)rangeOfPackedObjects
{
    return NSMakeRange(12, [self rangeOfChecksum].location - 12);
}
- (NSRange)rangeOfChecksum
{
    return NSMakeRange([self.data length] - 20, 20);
}
- (NSData*)checksum
{
    return [self.data subdataWithRange:[self rangeOfChecksum]];
}
- (NSString*)checksumString
{
    return unpackSHA1FromData([self checksum]);
}
- (BOOL)verifyChecksum
{
    NSData * checkData = [[self.data subdataWithRange:NSMakeRange(0, [self.data length] - 20)] sha1Digest];
    return [checkData isEqualToData:[self checksum]];
}
@end
