//
//  ImageLoaderTests.m
//  ImageLoaderTests
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import "ImageLoader.h"
#import <Diskcached/Diskcached.h>

// private class
@interface ImageLoaderCache : Diskcached <ImageLoaderCacheProtocol>

@end

// private property
@interface ImageLoader ()

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@interface ImageLoaderOperation ()

@property (nonatomic, strong) id<ImageLoaderCacheProtocol> cache;

- (BOOL)il_canShiftFromState:(ImageLoaderOperationState)from ToState:(ImageLoaderOperationState)to;

@end

@interface ImageLoaderOperationCompletionBlock : NSObject

@property (nonatomic, copy) void (^completionBlock)(NSURLRequest *, NSData *);

@end

@interface ImageLoaderTests : XCTestCase

@end

@implementation ImageLoaderTests

- (void)setUp
{
    [super setUp];
    [OHHTTPStubs shouldStubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        if ([request.URL.path isEqualToString:@"timeout"]) {
            return [OHHTTPStubsResponse responseWithData:nil
                                              statusCode:[request.URL.path intValue]
                                            responseTime:31. headers:nil];
        }
        if (400 < [request.URL.path intValue] && [request.URL.path intValue] < 500) {
            return [OHHTTPStubsResponse responseWithData:nil
                                              statusCode:[request.URL.path intValue]
                                            responseTime:1. headers:nil];
        }
        return [OHHTTPStubsResponse responseWithData:nil
                                          statusCode:200
                                        responseTime:1. headers:nil];
    }];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testLoaderRunWithURL
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];
    ImageLoaderOperation *operation1 = [loader getImageWithURL:URL completion:nil];

    XCTAssertTrue([loader.operationQueue.operations count] == 1,
                  @"operationQueue.operations count is %lu", (unsigned long)[loader.operationQueue.operations count]);

    URL = [NSURL URLWithString:@"http://test/path2"];
    ImageLoaderOperation *operation2 = [loader getImageWithURL:URL completion:nil];

    id valid = @[operation1, operation2];
    XCTAssertTrue([loader.operationQueue.operations isEqualToArray:valid],
                  @"operationQueue doesnt have operations");
}

- (void)testLoaderRunWith404
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/404"];
    [loader getImageWithURL:URL completion:^(NSURLRequest *request, UIImage *image) {
        XCTAssertTrue(!image,
                      @"image exist!");
    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.]];
}

- (void)testLoaderRunWithTimeout
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/timeout"];
    [loader getImageWithURL:URL completion:^(NSURLRequest *request, UIImage *image) {
        XCTAssertTrue(!image,
                      @"image exist!");
    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:32.]];
}

- (void)testLoaderRunWithEmptyURL
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = nil;
    [loader getImageWithURL:URL completion:nil];

    XCTAssertTrue([loader.operationQueue.operations count] == 0,
                  @"operationQueue.operations count is %lu", (unsigned long)[loader.operationQueue.operations count]);
}

- (void)testLoaderRunWithSameURL
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    ImageLoaderOperation *operation1 = [loader getImageWithURL:URL completion:nil];

    ImageLoaderOperation *operation2 = [loader getImageWithURL:URL completion:nil];

    XCTAssertEqual(operation1,
                   operation2,
                   @"operations dont call same URL");
}

- (void)testCacheDoesntConfirmProtocol
{
    ImageLoader *loader = [ImageLoader loader];

    NSObject *notCache = [[NSObject alloc] init];
    XCTAssertThrows(loader.cache = (id<ImageLoaderCacheProtocol>)notCache,
                    @"notCache confirms protocol");
}

- (void)testCacheConfirmsProtocol
{
    ImageLoader *loader = [ImageLoader loader];

    ImageLoaderCache *cache = [[ImageLoaderCache alloc] init];
    XCTAssertTrue(loader.cache = cache,
                  @"Diskcached dosent confirm protocol");
}

- (void)testOperationCancel
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    void(^completion)(NSURLRequest *, UIImage *) = ^(NSURLRequest *request, UIImage *image) {};

    ImageLoaderOperation *operation = [loader getImageWithURL:URL completion:completion];
    [operation cancel];
    XCTAssertTrue([operation isCancelled],
                  @"cant control to cancel to operation");
}

- (void)testKeepRequestNO
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    void(^completion)(NSURLRequest *, UIImage *) = ^(NSURLRequest *request, UIImage *image) {};

    ImageLoaderOperation *operation = [loader getImageWithURL:URL completion:completion];
    XCTAssertTrue([operation.completionBlocks count] == 1,
                  @"operation block count is %lu", (unsigned long)[operation.completionBlocks count]);

    [operation removeCompletionBlockWithIndex:0];

    XCTAssertTrue([operation isCancelled],
                  @"cant control to cancel to operation");
}

- (void)testKeepRequestYES
{
    ImageLoader *loader = [ImageLoader loader];
    loader.keepRequest = YES;

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    void(^completion)(NSURLRequest *, UIImage *) = ^(NSURLRequest *request, UIImage *image) {};

    ImageLoaderOperation *operation = [loader getImageWithURL:URL completion:completion];
    XCTAssertTrue([operation.completionBlocks count] == 1,
                  @"operation block count is %lu", (unsigned long)[operation.completionBlocks count]);

    [operation removeCompletionBlockWithIndex:0];

    XCTAssertTrue(![operation isCancelled],
                  @"cant control to cancel to operation");
    XCTAssertTrue(!operation.isFinished,
                  @"operation is finished");
}

- (void)testLoaderRemoveCompletionBlockWithIndex
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    void(^completion1)(NSURLRequest *, UIImage *) = ^(NSURLRequest *request, UIImage *image) {};
    void(^completion2)(NSURLRequest *, UIImage *) = ^(NSURLRequest *request, UIImage *image) {};

    ImageLoaderOperation *operation;

    operation = [loader getImageWithURL:URL completion:completion1];
    operation = [loader getImageWithURL:URL completion:completion2];

    XCTAssertTrue([operation.completionBlocks count] == 2,
                  @"operation block count is %lu", (unsigned long)[operation.completionBlocks count]);

    [operation removeCompletionBlockWithIndex:1];

    XCTAssertTrue([operation.completionBlocks count] == 2,
                  @"operation block count is %lu", (unsigned long)[operation.completionBlocks count]);

    ImageLoaderOperationCompletionBlock *block = operation.completionBlocks[1];
    XCTAssertNil(block.completionBlock,
                 @"block has completion block");

}

- (void)testCanShiftFromStateToState
{
    ImageLoaderOperation *operation = [[ImageLoaderOperation alloc] init];
    BOOL result;
    BOOL valid;
    ImageLoaderOperationState from;
    ImageLoaderOperationState to;

    from = ImageLoaderOperationReadyState;
    to = ImageLoaderOperationReadyState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = NO;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);

    from = ImageLoaderOperationReadyState;
    to = ImageLoaderOperationExecutingState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = YES;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);

    from = ImageLoaderOperationReadyState;
    to = ImageLoaderOperationFinishedState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = YES;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);

    from = ImageLoaderOperationExecutingState;
    to = ImageLoaderOperationReadyState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = NO;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);

    from = ImageLoaderOperationExecutingState;
    to = ImageLoaderOperationExecutingState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = NO;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);

    from = ImageLoaderOperationExecutingState;
    to = ImageLoaderOperationFinishedState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = YES;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);

    from = ImageLoaderOperationFinishedState;
    to = ImageLoaderOperationReadyState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = NO;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);

    from = ImageLoaderOperationFinishedState;
    to = ImageLoaderOperationExecutingState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = NO;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);

    from = ImageLoaderOperationFinishedState;
    to = ImageLoaderOperationFinishedState;
    result = [operation il_canShiftFromState:from ToState:to];
    valid = NO;
    XCTAssertTrue(result == valid,
                  @"fail to shift from %lu to %lu", from, to);
}

@end
