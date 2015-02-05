//
//  ImageLoaderOperation.h
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/11/18.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ImageLoaderOperationState) {
    ImageLoaderOperationReadyState = 0,
    ImageLoaderOperationExecutingState = 1,
    ImageLoaderOperationFinishedState = 2,
};

@interface ImageLoaderOperation : NSOperation

@property (nonatomic, readonly) ImageLoaderOperationState state;
@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly) NSArray *completionBlocks;

- (instancetype)initWithRequest:(NSURLRequest *)request keepRequest:(BOOL)keepRequest completion:(void (^)(NSURLRequest *, NSData *))completion;

- (void)addCompletionBlock:(void (^)(NSURLRequest *, NSData *))block;
- (void)removeCompletionBlockWithIndex:(NSUInteger)index;

@end
