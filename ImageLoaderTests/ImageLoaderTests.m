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
#import "UIImageView+ImageLoader.h"

// private property
@interface ImageLoader ()

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@interface ImageLoaderOperation ()

@property (nonatomic, strong) id<ImageLoaderCacheProtocol> cache;

- (void)removeCompletionBlockWithHash:(NSUInteger)Hash;

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
        return [OHHTTPStubsResponse responseWithData:nil
                                          statusCode:200
                                        responseTime:1. headers:nil];
    }];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testConnectWithURL
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

- (void)testConnectWithSameURL
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    ImageLoaderOperation *operation1 = [loader getImageWithURL:URL completion:nil];

    ImageLoaderOperation *operation2 = [loader getImageWithURL:URL completion:nil];

    XCTAssertEqual(operation1,
                   operation2,
                   @"operations call same URL");
}

- (void)testCacheDoesntConfirmProtocol
{
    ImageLoader *loader = [ImageLoader loader];

    NSObject *notCache = [[NSObject alloc] init];
    XCTAssertThrows(loader.cache = (id<ImageLoaderCacheProtocol>)notCache,
                    @"notCache confirms protocol");
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

- (void)testRemoveCompletionBlockWithIndex
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    void(^completion)(NSURLRequest *, UIImage *) = ^(NSURLRequest *request, UIImage *image) {};

    ImageLoaderOperation *operation = [loader getImageWithURL:URL completion:completion];
    XCTAssertTrue([operation.completionBlocks count] == 1,
                  @"operation block count is %lu", (unsigned long)[operation.completionBlocks count]);

    [operation removeCompletionBlockWithIndex:0];

    XCTAssertTrue([operation.completionBlocks count] == 0,
                  @"operation block count is %lu", (unsigned long)[operation.completionBlocks count]);
}

- (void)testRemoveCompletionBlockWithHash
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    void(^completion1)(NSURLRequest *, UIImage *) = ^(NSURLRequest *request, UIImage *image) {};
    void(^completion2)(NSURLRequest *, UIImage *) = ^(NSURLRequest *request, UIImage *image) {};

    NSInteger competion1Hash, competion2Hash;

    ImageLoaderOperation *operation;

    operation = [loader getImageWithURL:URL completion:completion1];
    competion1Hash = [[operation.completionBlocks lastObject] hash];

    operation = [loader getImageWithURL:URL completion:completion2];
    competion2Hash = [[operation.completionBlocks lastObject] hash];

    XCTAssertTrue([operation.completionBlocks count] == 2,
                  @"operation block count is %lu", (unsigned long)[operation.completionBlocks count]);

    [operation removeCompletionBlockWithHash:competion2Hash];

    XCTAssertTrue([operation.completionBlocks count] == 1,
                  @"operation block count is %lu", (unsigned long)[operation.completionBlocks count]);
    XCTAssertTrue([[operation.completionBlocks lastObject] hash] == competion1Hash,
                  @"operation remove block is fail");

}

@end
