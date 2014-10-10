//
//  UIImageView+ImageLoader.m
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import <objc/runtime.h>

#import "UIImageView+ImageLoader.h"

@implementation ImageLoaderOperation (ImageLoader_Property)

- (void)removeCompletionBlockWithHash:(NSUInteger)hash
{
    for (int i=0; i < [self.completionBlocks count]; i++) {
        NSObject *block = self.completionBlocks[i];
        if (hash == block.hash) {
            [self removeCompletionBlockWithIndex:i];
            break;
        }
    }
}

@end


@interface UIImageView (ImageLoader_Property)

@property (nonatomic, strong) NSURL *imageLoaderRequestURL;
@property (nonatomic) NSUInteger imageLoaderCompletionKey;

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

- (NSUInteger)imageLoaderCompletionKey
{
    NSNumber *imageLoaderCompletionKey = objc_getAssociatedObject(self, ImageLoaderCompletionKey);
    if (imageLoaderCompletionKey) {
        return [imageLoaderCompletionKey integerValue];
    }
    return 0;
}

- (void)setImageLoaderCompletionKey:(NSUInteger)imageLoaderCompletionKey
{
    objc_setAssociatedObject(self, ImageLoaderCompletionKey, @(imageLoaderCompletionKey), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIImageView (ImageLoader)

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

+ (dispatch_queue_t)_ilQueue
{
    static dispatch_queue_t _ilQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ilQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    });

    return _ilQueue;
}

#pragma mark - set Image with URL

- (void)il_setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage
{
    [self il_setImageWithURL:URL placeholderImage:placeholderImage completion:nil];
}

- (void)il_setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage completion:(void (^)(BOOL))completion
{
    __weak typeof(self) weakSelf = self;

    void(^setImageWithCompletionBlock)(NSURL *, UIImage *) = ^(NSURL *URL, UIImage *image) {

        if (!weakSelf) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([weakSelf.imageLoaderRequestURL isEqual:URL]) {
                weakSelf.image = image;
            }

            if (completion) {
                completion(YES);
            }
        });
    };

    [self il_cancelCompletion];
    self.imageLoaderRequestURL = URL;

    // place holder
    if (placeholderImage) {
        self.image = placeholderImage;
    }

    dispatch_async([UIImageView _ilQueue], ^{

        if (!weakSelf) {
            return;
        }

        NSData *data = [[[weakSelf class] il_sharedImageLoader].cache objectForKey:[URL absoluteString]];
        if (data) {
            setImageWithCompletionBlock(URL, ILOptimizedImageWithData(data));
            return;
        }

        ImageLoaderOperation *operation =
        [[[weakSelf class] il_sharedImageLoader] getImageWithURL:URL completion:^(NSURLRequest *request, UIImage *image) {
            setImageWithCompletionBlock(request.URL, image);
        }];

        weakSelf.imageLoaderCompletionKey = [[operation.completionBlocks lastObject] hash];

    });
}

- (void)il_cancelCompletion
{
    if (!self.imageLoaderCompletionKey || !self.imageLoaderRequestURL) {
        return;
    }

    ImageLoaderOperation *operation = [[[self class] il_sharedImageLoader] getOperationWithURL:self.imageLoaderRequestURL];
    if (!operation || [operation isFinished]) {
        return;
    }

    [operation removeCompletionBlockWithHash:self.imageLoaderCompletionKey];
}

@end

@implementation UIImageView (ImageLoader_Compatible)

- (void)setImageWithURL:(NSURL *)URL
{
    [self il_setImageWithURL:URL placeholderImage:nil];
}

- (void)setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage
{
    [self il_setImageWithURL:URL placeholderImage:placeholderImage];
}

- (void)setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage completion:(void (^)(BOOL finished))completion
{
    [self il_setImageWithURL:URL placeholderImage:placeholderImage completion:completion];
}

@end