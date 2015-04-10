//
//  UIImageView+ImageLoader.h
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageLoader.h"

@interface UIImageView (ImageLoader)

+ (ImageLoader *)il_sharedImageLoader;

- (void)il_setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage;
- (void)il_setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage completion:(void (^)(BOOL finished))completion;

@end

@interface UIImageView (ImageLoader_Compatible)

- (void)setImageWithURL:(NSURL *)URL;
- (void)setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage;
- (void)setImageWithURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage completion:(void (^)(BOOL finished))completion;

@end

@interface UIImageView (ImageLoaderSwift_Compatible)

- (void)load:(NSURL *)URL;
- (void)load:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage;
- (void)load:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage completion:(void (^)(BOOL finished))completion;

@end