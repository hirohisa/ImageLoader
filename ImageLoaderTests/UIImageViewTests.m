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
#import <Diskcached/Diskcached.h>

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

@property (nonatomic, strong) UIImage *blackImage;
@property (nonatomic, strong) UIImage *whiteImage;

@end

@implementation UIImageViewTests

- (void)setUp
{
    [super setUp];

    NSString *path;
    NSData *blackImageData, *whiteImageData;

    path = [[NSBundle bundleForClass:[self class]] pathForResource:@"black" ofType:@"png"];
    blackImageData = UIImageJPEGRepresentation([UIImage imageWithContentsOfFile:path], 1.f);
    self.blackImage = ILOptimizedImageWithData(blackImageData);

    path = [[NSBundle bundleForClass:[self class]] pathForResource:@"white" ofType:@"png"];
    whiteImageData = UIImageJPEGRepresentation([UIImage imageWithContentsOfFile:path], 1.f);
    self.whiteImage = ILOptimizedImageWithData(whiteImageData);

    [OHHTTPStubs shouldStubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {

        NSURL *URL = request.URL;

        if ([URL.path hasSuffix:@"white"]) {
            return [OHHTTPStubsResponse responseWithData:whiteImageData
                                              statusCode:200
                                            responseTime:.1 headers:nil];
        }

        return [OHHTTPStubsResponse responseWithData:blackImageData
                                          statusCode:200
                                        responseTime:.1 headers:nil];
    }];

    Diskcached *diskcached = (Diskcached *)[UIImageView il_sharedImageLoader].cache;
    [diskcached removeAllObjects];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testLoadSameDataWithOHHTTPStubs
{
    NSURL *URL;
    URL = [NSURL URLWithString:@"http://test/path"];

    UIImageView *imageView = [UIImageView new];

    __weak typeof(imageView) weakImageView = imageView;
    [imageView setImageWithURL:URL placeholderImage:nil completion:^(BOOL finished) {
        XCTAssertTrue([weakImageView.image isEqualToImage:self.blackImage],
                      @"They are not same data");
    }];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.]];
}

- (void)testSetImageToImageViewSoonAfterLoad
{
    NSURL *URL;
    UIImage *image;
    URL = [NSURL URLWithString:@"http://test/path2"];

    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"white" ofType:@"png"];
    NSData *data = UIImageJPEGRepresentation([UIImage imageWithContentsOfFile:path], 1.f);
    image = ILOptimizedImageWithData(data);

    UIImageView *imageView = [UIImageView new];

    __weak typeof(imageView) weakImageView = imageView;
    [imageView setImageWithURL:URL placeholderImage:nil completion:^(BOOL finished) {
        XCTAssertTrue([weakImageView.image isEqualToImage:image],
                      @"They are not same data");
    }];

    imageView.image = image;
    XCTAssertTrue([imageView.image isEqualToImage:image],
                  @"They are not same data");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.]];
}

- (void)testLoadImageWithTwiceCalling
{
    NSURL *URL;
    UIImage *image;

    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"white" ofType:@"png"];
    NSData *data = UIImageJPEGRepresentation([UIImage imageWithContentsOfFile:path], 1.f);
    image = ILOptimizedImageWithData(data);

    UIImageView *imageView = [UIImageView new];

    URL = [NSURL URLWithString:@"http://test/first"];
    [imageView setImageWithURL:URL];

    URL = [NSURL URLWithString:@"http://test/second"];
    [imageView setImageWithURL:URL];

    XCTAssertEqual(URL, imageView.imageLoaderRequestURL,
                   @"requesting URLs are not same, %@ and %@", URL, imageView.imageLoaderRequestURL);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.]];
}

- (void)testLoadImageWithTwiceCallingWithCompletion
{
    NSURL *URL;
    UIImage *image;

    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"white" ofType:@"png"];
    NSData *data = UIImageJPEGRepresentation([UIImage imageWithContentsOfFile:path], 1.f);
    image = ILOptimizedImageWithData(data);

    UIImageView *imageView = [UIImageView new];

    __weak typeof(imageView) weakImageView = imageView;

    URL = [NSURL URLWithString:@"http://test/white"];

    [imageView setImageWithURL:URL placeholderImage:nil completion:^(BOOL finished) {
        XCTAssertFalse(true,
                       @"need to not call block");
    }];

    URL = [NSURL URLWithString:@"http://test/black"];
    [imageView setImageWithURL:URL placeholderImage:nil completion:^(BOOL finished) {
        XCTAssertTrue([weakImageView.image isEqualToImage:self.blackImage],
                      @"They are not same data");
    }];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.]];
}

- (void)testLoadImageWithTwiceCallingInBlock
{
    NSURL *whiteImageURL, *blackImageURL;
    whiteImageURL = [NSURL URLWithString:@"http://test/twice/white"];
    blackImageURL = [NSURL URLWithString:@"http://test/twice/black"];

    UIImageView *imageView = [UIImageView new];

    __weak typeof(imageView) weakImageView = imageView;
    [imageView setImageWithURL:whiteImageURL placeholderImage:nil completion:^(BOOL finished) {

        [weakImageView setImageWithURL:blackImageURL placeholderImage:nil completion:^(BOOL finished) {
            XCTAssertFalse(true,
                           @"need to not call block");
        }];

        [weakImageView setImageWithURL:whiteImageURL placeholderImage:nil completion:^(BOOL finished) {
            XCTAssertTrue([weakImageView.image isEqualToImage:self.whiteImage],
                          @"They are not same data");
        }];
    }];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.]];
}
@end
