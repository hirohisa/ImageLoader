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

@interface ImageLoader ()

+ (instancetype)il_sharedLoader;

@end

@interface UIImageView (PrivateImageLoader)

@property (nonatomic, strong) id imageLoaderObserver;
@property (nonatomic, strong) NSURL *imageLoaderReuqestURL;
@property (nonatomic, copy)  void (^completion)(BOOL);

@end

@implementation UIImageView (ImageLoader)

#pragma mark - swizzling

+ (void)load
{
    ILSwizzleInstanceMethod(self, @selector(setImage:), @selector(il_setImage:));
}

- (void)il_setImage:(UIImage *)image
{
    self.imageLoaderReuqestURL = nil;
    [self il_setImage:image];
}

#pragma mark - ImageLoader

static const char *ImageLoaderObserverKey = "ImageLoaderObserverKey";
static const char *ImageLoaderRequestURLKey = "ImageLoaderRequestURLKey";
static const char *ImageLoaderCompletionKey = "ImageLoaderCompletionKey";

#pragma mark - getter/setter

- (id)imageLoaderObserver
{
    return objc_getAssociatedObject(self, ImageLoaderObserverKey);
}

- (void)setImageLoaderObserver:(id)imageLoaderObserver
{
    objc_setAssociatedObject(self, ImageLoaderObserverKey, imageLoaderObserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL *)imageLoaderReuqestURL
{
    return objc_getAssociatedObject(self, ImageLoaderRequestURLKey);
}

- (void)setImageLoaderReuqestURL:(NSURL *)imageLoaderReuqestURL
{
    objc_setAssociatedObject(self, ImageLoaderRequestURLKey, imageLoaderReuqestURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(BOOL))completion
{
    return objc_getAssociatedObject(self, ImageLoaderCompletionKey);
}

- (void)setCompletion:(void (^)(BOOL))completion
{
    objc_setAssociatedObject(self, ImageLoaderCompletionKey, completion, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

#pragma mark - set Image with URL

- (void)setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage
{
    [self setImageWithURL:URL placeholderImage:placeholderImage completion:nil];
}

- (void)setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage completion:(void (^)(BOOL))completion
{
    // prepare
    if (self.completion) {
        self.completion(NO);
        self.completion = nil;
    }


    // cache exists
    NSData *data = [[ImageLoader il_sharedLoader].cache objectForKey:[URL absoluteString]];
    if (data) {
        self.image = [UIImage imageWithData:data];
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
    self.imageLoaderReuqestURL = URL;

    // completion
    if (completion) {
        self.completion = completion;
    }

    if (!self.imageLoaderObserver) {
        self.imageLoaderObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:ImageLoaderDidCompletionNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note)
        {
            if (note.object) {
                [self il_setImage:note.object[ImageLoaderImageKey] withURL:note.object[ImageLoaderURLKey]];
            }
        }];
    }

    [[ImageLoader il_sharedLoader] getImageWithURL:URL];
}

- (void)il_setImage:(UIImage *)image withURL:(NSURL *)URL
{
    if ([URL isEqual:self.imageLoaderReuqestURL]) {
        self.image = image;
        if (self.completion) {
            self.completion(YES);
            self.completion = nil;
        }
    }
}

@end
