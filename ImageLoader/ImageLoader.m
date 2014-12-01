//
//  ImageLoader.m
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import "ImageLoader.h"
#import "Diskcached.h"

NSString *const ImageLoaderCacheNotConfirmToProtocolException = @"ImageLoaderDidCompletionNotification";

@interface UIScreen (ImageLoader)

+ (CGFloat)il_scale;

@end

@implementation UIScreen (ImageLoader)

+ (CGFloat)il_scale
{
    static dispatch_once_t onceToken;
    static CGFloat _scale = 1.f;
    dispatch_once(&onceToken, ^{
        _scale = [[self mainScreen] scale];
    });
    return _scale;
}

@end


UIImage * ILOptimizedImageWithData(NSData *data)
{
    if (!data || ![data length]) {
        return nil;
    }

    UIImage *image = [UIImage imageWithData:data];
    if (CGImageGetWidth([image CGImage]) * CGImageGetHeight([image CGImage]) > 1024 * 1024 ||
        CGImageGetBitsPerComponent([image CGImage]) > 8) {
        return image;
    }

    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo([image CGImage]);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpace);

    switch (colorSpaceModel) {
        case kCGColorSpaceModelRGB: {
            uint32_t alpha = bitmapInfo & kCGBitmapAlphaInfoMask;
            CGImageAlphaInfo alphaInfo;

            switch (alpha) {
                case kCGImageAlphaNone:
                    alphaInfo = kCGImageAlphaNoneSkipFirst;
                    break;
                default:
                    alphaInfo = kCGImageAlphaPremultipliedFirst;
                    break;
            }

            bitmapInfo &= ~kCGBitmapAlphaInfoMask;
            bitmapInfo |= alphaInfo;
        }
            break;

        default:
            break;
    }

    CGContextRef context = CGBitmapContextCreate(
                                                 NULL,
                                                 CGImageGetWidth([image CGImage]),
                                                 CGImageGetHeight([image CGImage]),
                                                 CGImageGetBitsPerComponent([image CGImage]),
                                                 0,
                                                 colorSpace,
                                                 bitmapInfo
                                                 );
    CGColorSpaceRelease(colorSpace);

    CGContextDrawImage(context, CGRectMake(.0f, .0f, CGImageGetWidth([image CGImage]), CGImageGetHeight([image CGImage])), [image CGImage]);
    CGImageRef optimizedImageRef = CGBitmapContextCreateImage(context);

    CGContextRelease(context);

    UIImage *optimizedImage = [[UIImage alloc] initWithCGImage:optimizedImageRef scale:[UIScreen il_scale] orientation:image.imageOrientation];
    image = nil;

    CGImageRelease(optimizedImageRef);

    return optimizedImage;
}


//
// ImageLoaderCache
//
//
@interface ImageLoaderCache : Diskcached <ImageLoaderCacheProtocol>

@end

@implementation ImageLoaderCache

- (id)init
{
    self = [super initAtPath:@"ImageLoader" inUserDomainDirectory:NSCachesDirectory];
    if (self) {
        self.useArchiver = NO;
        self.keepData = NO;
    }
    return self;
}

@end


@interface ImageLoader ()

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation ImageLoader

+ (instancetype)loader
{
    return [[self alloc] init];
}

- (id)init
{
    self = [super init];
    if (self) {
        [self il_configure];
    }
    return self;
}

- (void)il_configure
{
    self.keepRequest = NO;
    // cache
    _cache = [[ImageLoaderCache alloc] init];
    // operation queue
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
}

- (void)enqueue:(NSOperation *)operation
{
    [self.operationQueue addOperation:operation];
}

#pragma mark - setter

- (void)setCache:(id<ImageLoaderCacheProtocol>)cache
{
    if (![cache respondsToSelector:@selector(objectForKey:)] ||
        ![cache respondsToSelector:@selector(setObject:forKey:)]) {
        [NSException raise:ImageLoaderCacheNotConfirmToProtocolException
                    format:@"%s: Cache needs to confirm to ImageLoaderCacheProtocol", __func__];
    }
    _cache = cache;
}


#pragma mark - public

- (ImageLoaderOperation *)getImageWithURL:(NSURL *)URL completion:(void (^)(NSURLRequest *, UIImage *))completion
{
    return [self _getImageWithURL:URL completion:completion];
}

- (ImageLoaderOperation *)getOperationWithURL:(NSURL *)URL
{
    for (ImageLoaderOperation *operation in self.operationQueue.operations) {
        if (!operation.isFinished &&
            !operation.isCancelled &&
            [operation.request.URL isEqual:URL]) {
            return operation;
        }
    }
    return nil;
}

#pragma mark - private

- (ImageLoaderOperation *)_getImageWithURL:(NSURL *)URL completion:(void (^)(NSURLRequest *, UIImage *))completion
{
    if (!URL) {
        if (completion) {
            completion(nil, nil);
        }
        return nil;
    }

    __weak typeof(self) wSelf = self;
    void (^completionBlock)(NSURLRequest *, NSData *) = ^(NSURLRequest *request, NSData *data) {
        UIImage *image = ILOptimizedImageWithData(data);

        if (image) {
            if (image && request.URL) {
                [wSelf.cache setObject:data forKey:[request.URL absoluteString]];
            }
        }

        if (completion) {
            completion(request, image);
        }
    };

    // operation exists
    ImageLoaderOperation *operation = [self getOperationWithURL:URL];
    if (operation) {
        [operation addCompletionBlock:completionBlock];
        return operation;
    }

    NSData *data = [self.cache objectForKey:[URL absoluteString]];
    UIImage *image = ILOptimizedImageWithData(data);
    if (image) {
        if (completion) {
            completion(nil, image);
        }
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    operation = [[ImageLoaderOperation alloc] initWithRequest:request keepRequest:self.keepRequest completion:completionBlock];

    [self enqueue:operation];

    return operation;
}

@end