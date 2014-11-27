//
//  UIImageViewTests.m
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/11/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import "UIImageView+ImageLoader.h"

#pragma mark - private methods

@interface UIImage (equal)

-(BOOL)isEqualToImage:(UIImage*)image;

@end

@implementation UIImage (equal)

-(BOOL)isEqualToImage:(UIImage*)image
{
    BOOL result = NO;
    if (image && CGSizeEqualToSize(self.size, image.size)) {

        CGDataProviderRef dataProvider1 = CGImageGetDataProvider(self.CGImage);
        NSData *data1 = (NSData*)CFBridgingRelease(CGDataProviderCopyData(dataProvider1));

        CGDataProviderRef dataProvider2 = CGImageGetDataProvider(image.CGImage);
        NSData *data2 = (NSData*)CFBridgingRelease(CGDataProviderCopyData(dataProvider2));

        result = [data1 isEqual:data2];
    }
    return result;
}

@end

@interface UIImageView (UIImageViewTests)

@property (nonatomic, readonly) NSURL *imageLoaderRequestURL;

@end

@interface UIImageViewTests : XCTestCase

@property (nonatomic, strong) UIImage *image;

@end

@implementation UIImageViewTests

- (void)setUp
{
    [super setUp];

    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"black" ofType:@"png"];

    NSData *data = UIImageJPEGRepresentation([UIImage imageWithContentsOfFile:path], 1.f);
    self.image = ILOptimizedImageWithData(data);

    [OHHTTPStubs shouldStubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:data
                                          statusCode:200
                                        responseTime:.1 headers:nil];
    }];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testHasSameURLOnLoadingCompletion
{
    NSURL *URL;
    URL = [NSURL URLWithString:@"http://test/path"];

    UIImageView *imageView = [UIImageView new];

    __weak typeof(imageView) weakImageView = imageView;
    [imageView setImageWithURL:URL placeholderImage:nil completion:^(BOOL finished) {

        XCTAssertEqual(URL,
                       weakImageView.imageLoaderRequestURL,
                       @"URL is not same");

    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
}

// requirements for testing `testThenUIImageViewCompletionAfterLoad`
- (void)testLoadSameDataWithOHHTTPStubs
{
    NSURL *URL;
    URL = [NSURL URLWithString:@"http://test/path"];

    UIImageView *imageView = [UIImageView new];

    __weak typeof(imageView) weakImageView = imageView;
    [imageView setImageWithURL:URL placeholderImage:nil completion:^(BOOL finished) {

        XCTAssertTrue([weakImageView.image isEqualToImage:self.image],
                       @"They are not same data");

    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
}

- (void)testSetImageToImageViewSoonAfterLoad
{
    NSURL *URL;
    UIImage *image;
    URL = [NSURL URLWithString:@"http://test/path"];
    image = [UIImage imageWithData:[NSData data]];

    UIImageView *imageView = [UIImageView new];

    __weak typeof(imageView) weakImageView = imageView;
    [imageView setImageWithURL:URL placeholderImage:nil completion:^(BOOL finished) {


        XCTAssertFalse([weakImageView.image isEqualToImage:self.image],
                      @"They are same data");

    }];

    imageView.image = image;

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
}

@end
