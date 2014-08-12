//
//  ImageLoader.h
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

@import Foundation;
@import UIKit;

extern UIImage * ILOptimizedImageWithData(NSData *data);

extern NSString *const ImageLoaderCacheNotConfirmToProtocolException;

extern NSString *const ImageLoaderDidCompletionNotification;
extern NSString *const ImageLoaderImageKey;
extern NSString *const ImageLoaderURLKey;

@protocol ImageLoaderCacheProtocol <NSObject>

- (id)objectForKey:(id)key;
- (void)setObject:(id)obj forKey:(id)key;

@end

@interface ImageLoaderOperation : NSOperation

@end

@interface ImageLoader : NSObject

@property (nonatomic, strong) id<ImageLoaderCacheProtocol> cache;

+ (instancetype)loader;

- (ImageLoaderOperation *)getImageWithURL:(NSURL *)URL completion:(void (^)(UIImage *image))completion;

@end
