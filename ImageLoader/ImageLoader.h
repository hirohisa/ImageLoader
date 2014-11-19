//
//  ImageLoader.h
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

@import Foundation;
@import UIKit;

#import "ImageLoaderOperation.h"

extern UIImage * ILOptimizedImageWithData(NSData *data);

extern NSString *const ImageLoaderCacheNotConfirmToProtocolException;

@protocol ImageLoaderCacheProtocol <NSObject>

- (id)objectForKey:(id)key;
- (void)setObject:(id)obj forKey:(id)key;

@end

@interface ImageLoader : NSObject

@property (nonatomic, strong) id<ImageLoaderCacheProtocol> cache;
@property (nonatomic) BOOL keepRequest; // default is NO. If you dont kill a reqest, cache image with it.

+ (instancetype)loader;

- (ImageLoaderOperation *)getImageWithURL:(NSURL *)URL completion:(void (^)(NSURLRequest *request, UIImage *image))completion;
- (ImageLoaderOperation *)getOperationWithURL:(NSURL *)URL;

@end
