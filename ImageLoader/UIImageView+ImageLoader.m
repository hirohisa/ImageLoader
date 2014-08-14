//
//  UIImageView+ImageLoader.m
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import <objc/runtime.h>

#import "UIImageView+ImageLoader.h"
#import "ImageLoader.h"

void ILSwizzleInstanceMethod(Class c, SEL original, SEL alternative)
{
    Method orgMethod = class_getInstanceMethod(c, original);
    Method altMethod = class_getInstanceMethod(c, alternative);
    if(class_addMethod(c, original, method_getImplementation(altMethod), method_getTypeEncoding(altMethod))) {
        class_replaceMethod(c, alternative, method_getImplementation(orgMethod), method_getTypeEncoding(orgMethod));
    } else {
        method_exchangeImplementations(orgMethod, altMethod);
    }
}

@interface UIImageView (ImageLoader_Property)

@property (nonatomic, strong) NSURL *imageLoaderRequestURL;
@property (nonatomic, copy)  void (^completion)(BOOL);

@end

@implementation UIImageView (ImageLoader_Property)

static const char *ImageLoaderRequestURLKey = "ImageLoaderRequestURLKey";
static const char *ImageLoaderCompletionKey = "ImageLoaderCompletionKey";

- (NSURL *)imageLoaderRequestURL
{
    return objc_getAssociatedObject(self, ImageLoaderRequestURLKey);
}

- (void)setImageLoaderRequestURL:(NSURL *)imageLoaderRequestURL
{
    objc_setAssociatedObject(self, ImageLoaderRequestURLKey, imageLoaderRequestURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(BOOL))completion
{
    return objc_getAssociatedObject(self, ImageLoaderCompletionKey);
}

- (void)setCompletion:(void (^)(BOOL))completion
{
    objc_setAssociatedObject(self, ImageLoaderCompletionKey, completion, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation UIImageView (ImageLoader)

#pragma mark - swizzling

+ (void)load
{
    ILSwizzleInstanceMethod(self, @selector(setImage:), @selector(il_setImage:));
}

- (void)il_setImage:(UIImage *)image
{
    self.imageLoaderRequestURL = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self il_setImage:image];
    });
}

#pragma mark - ImageLoader

+ (ImageLoader *)il_sharedImageLoader
{
    static ImageLoader *_il_sharedImageLoader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _il_sharedImageLoader = [[ImageLoader alloc] init];
    });

    return _il_sharedImageLoader;
}

#pragma mark - set Image with URL

- (void)il_setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage
{
    [self il_setImageWithURL:URL placeholderImage:placeholderImage completion:nil];
}

- (void)il_setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage completion:(void (^)(BOOL))completion
{
    if (self.completion) {
        self.completion(NO);
        self.completion = nil;
    }

    // cache exists
    NSData *data = [[[self class] il_sharedImageLoader].cache objectForKey:[URL absoluteString]];
    if (data) {
        self.image = ILOptimizedImageWithData(data);
        if (completion) {
            completion(YES);
            return;
        }
    }

    // place holder
    if (placeholderImage) {
        self.image = placeholderImage;
    }
    // URL
    self.imageLoaderRequestURL = URL;

    // completion
    if (completion) {
        self.completion = completion;
    }

    __weak typeof(self) wSelf = self;
    [[[self class] il_sharedImageLoader] getImageWithURL:URL completion:^(NSURLRequest *request, UIImage *image) {
        [wSelf il_setImage:image withURL:request.URL];
    }];
}

- (void)il_setImage:(UIImage *)image withURL:(NSURL *)URL
{
    BOOL equaled = [URL isEqual:self.imageLoaderRequestURL];
    if (equaled) {
        self.image = image;
    }
    if (self.completion) {
        self.completion(equaled);
        self.completion = nil;
    }
}

@end
