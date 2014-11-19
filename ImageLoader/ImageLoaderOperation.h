//
//  ImageLoaderOperation.h
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/11/18.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ImageLoaderOperation : NSOperation

@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly) NSArray *completionBlocks;

- (instancetype)initWithRequest:(NSURLRequest *)request keepRequest:(BOOL)keepRequest completion:(void (^)(NSURLRequest *, NSData *))completion;

- (void)addCompletionBlock:(void (^)(NSURLRequest *, NSData *))block;
- (void)removeCompletionBlockWithIndex:(NSUInteger)index;

@end
