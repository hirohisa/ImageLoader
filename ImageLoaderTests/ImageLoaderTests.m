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

// private property
@interface ImageLoader ()

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@interface ImageLoaderOperation ()

@property (nonatomic, strong) id<ImageLoaderCacheProtocol> cache;

@end

// mock object
@interface ImageLoaderTestCache : NSCache <ImageLoaderCacheProtocol>

@end

@implementation ImageLoaderTestCache

@end

@interface ImageLoaderNoCache : NSObject

@end

@implementation ImageLoaderNoCache

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
    ImageLoaderOperation *operation1 = [loader getImageWithURL:URL];

    XCTAssertTrue([loader.operationQueue.operations count] == 1,
                  @"operationQueue.operations count is %d", [loader.operationQueue.operations count]);

    URL = [NSURL URLWithString:@"http://test/path2"];
    ImageLoaderOperation *operation2 = [loader getImageWithURL:URL];

    id valid = @[operation1, operation2];
    XCTAssertTrue([loader.operationQueue.operations isEqualToArray:valid],
                  @"operationQueue doesnt have operations");
}

- (void)testConnectWithSameURL
{
    ImageLoader *loader = [ImageLoader loader];

    NSURL *URL;

    URL = [NSURL URLWithString:@"http://test/path"];

    ImageLoaderOperation *operation1 = [loader getImageWithURL:URL];

    ImageLoaderOperation *operation2 = [loader getImageWithURL:URL];

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

@end
