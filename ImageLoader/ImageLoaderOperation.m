//
//  ImageLoaderOperation.m
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/11/18.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import "ImageLoaderOperation.h"

@interface ImageLoaderOperationCompletionBlock : NSObject

@property (nonatomic, copy) void (^completionBlock)(NSURLRequest *, NSData *);

@end

@implementation ImageLoaderOperationCompletionBlock

@end

@interface ImageLoaderOperation () <NSURLConnectionDataDelegate>

@property (nonatomic) ImageLoaderOperationState state;
@property (nonatomic, readonly) BOOL keepRequest;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSData *responseData;

@property (nonatomic, strong) NSRecursiveLock *lock;

@end

@interface ImageLoaderOperation (Private)

- (NSString *)il_keyPathWithOperationState:(ImageLoaderOperationState)state;
- (BOOL)il_canShiftFromState:(ImageLoaderOperationState)from ToState:(ImageLoaderOperationState)to;

@end

@implementation ImageLoaderOperation (Private)

- (NSString *)il_keyPathWithOperationState:(ImageLoaderOperationState)state
{
    switch (state) {
        case ImageLoaderOperationReadyState:;
            return @"isReady";
        case ImageLoaderOperationExecutingState:;
            return @"isExecuting";
        case ImageLoaderOperationFinishedState:;
            return @"isFinished";
    }
}

- (BOOL)il_canShiftFromState:(ImageLoaderOperationState)from ToState:(ImageLoaderOperationState)to
{
    if (from == to) {
        return NO;
    }

    switch (from) {
        case ImageLoaderOperationReadyState:;
            return YES;
            break;

        case ImageLoaderOperationExecutingState:;
            return from < to;
            break;

        case ImageLoaderOperationFinishedState:;
            return NO;
            break;
    }
}

@end

@implementation ImageLoaderOperation

+ (NSThread *)networkThread {

    static NSThread *_thread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(thread_initialize) object:nil];
        [_thread start];
    });

    return _thread;
}

+ (void)thread_initialize
{
    @autoreleasepool {
        [[NSThread currentThread] setName:@"ImageLoader"];
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    }
}

- (id)initWithRequest:(NSURLRequest *)request keepRequest:(BOOL)keepRequest completion:(void (^)(NSURLRequest *, NSData *))completion
{
    self = [self init];
    if (self) {
        _state = ImageLoaderOperationReadyState;
        _lock = [[NSRecursiveLock alloc] init];
        _request = request;
        _keepRequest = keepRequest;
        _completionBlocks = @[];
        if (completion) {
            [self addCompletionBlock:completion];
        }

        __weak typeof(self) wSelf = self;
        self.completionBlock = ^{
            for (ImageLoaderOperationCompletionBlock *block in wSelf.completionBlocks) {
                if (block.completionBlock) {
                    block.completionBlock(wSelf.request, wSelf.responseData);
                }
            }
        };
    }
    return self;
}

- (void)addCompletionBlock:(void (^)(NSURLRequest *, NSData *))block
{
    if (block) {
        ImageLoaderOperationCompletionBlock *object = [[ImageLoaderOperationCompletionBlock alloc] init];
        object.completionBlock = [block copy];
        _completionBlocks = [self.completionBlocks arrayByAddingObject:object];
    }
}

- (void)removeCompletionBlockWithIndex:(NSUInteger)index
{
    [self _removeCompletionBlockWithIndex:index];

    BOOL hasCompletionBlock = NO;
    for (ImageLoaderOperationCompletionBlock *block in self.completionBlocks) {
        if (block.completionBlock) {
            hasCompletionBlock = YES;
            break;
        }
    }
    if (!hasCompletionBlock &&
        !self.keepRequest) {
        [self cancel];
    }
}

- (void)_removeCompletionBlockWithIndex:(NSUInteger)index
{
    if (index < self.completionBlocks.count) {
        ImageLoaderOperationCompletionBlock *block = self.completionBlocks[index];
        block.completionBlock = nil;
    }
}

#pragma mark - getter

- (BOOL)isReady
{
    return self.state == ImageLoaderOperationReadyState && [super isReady];
}

- (BOOL)isExecuting
{
    return self.state == ImageLoaderOperationExecutingState;
}

- (BOOL)isFinished
{
    return self.state == ImageLoaderOperationFinishedState;
}

- (BOOL)isConcurrent
{
    return YES;
}

#pragma mark - setter

- (void)setState:(ImageLoaderOperationState)state
{
    if (![self il_canShiftFromState:self.state ToState:state]) {
        return;
    }

    [self.lock lock];

    NSString *fromKey = [self il_keyPathWithOperationState:self.state];
    NSString *toKey = [self il_keyPathWithOperationState:state];

    [self willChangeValueForKey:toKey];
    [self willChangeValueForKey:fromKey];
    _state = state;
    [self didChangeValueForKey:fromKey];
    [self didChangeValueForKey:toKey];

    [self.lock unlock];
}

#pragma mark - NSOperation methods

- (void)start
{
    [self.lock lock];

    if ([self isCancelled]) {

        [self performSelector:@selector(operation_cancel)
                     onThread:[[self class] networkThread]
                   withObject:nil
                waitUntilDone:NO
                        modes:@[NSDefaultRunLoopMode]];

    } else if ([self isReady]) {

        self.state = ImageLoaderOperationExecutingState;

        [self performSelector:@selector(operation_run)
                     onThread:[[self class] networkThread]
                   withObject:nil
                waitUntilDone:NO
                        modes:@[NSDefaultRunLoopMode]];
    }

    [self.lock unlock];
}

- (void)cancel
{
    [self.lock lock];

    if (![self isFinished] && ![self isCancelled]) {
        [super cancel];
        if ([self isExecuting]) {
            [self performSelector:@selector(operation_cancel)
                         onThread:[[self class] networkThread]
                       withObject:nil
                    waitUntilDone:NO
                            modes:@[NSDefaultRunLoopMode]];
        }
    }

    self.connection = nil;

    if (self.completionBlock) {
        self.completionBlock();
    }
    _request = nil;

    [self.lock unlock];
}

- (void)finish
{
    [self.lock lock];

    self.state = ImageLoaderOperationFinishedState;
    self.connection = nil;

    if (self.completionBlock) {
        self.completionBlock();
    }
    _request = nil;

    [self.lock unlock];
}

#pragma mark -

- (void)operation_run
{
    [self.lock lock];

    [self operation_request];

    [self.lock unlock];
}

- (void)operation_request
{
    [self.lock lock];

    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
    [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.connection start];

    [self.lock unlock];
}

- (void)operation_cancel
{
    [self.lock lock];

    if (![self isFinished]) {
        if (self.connection) {
            [self.connection cancel];

            NSError *error = nil;
            if ([self.request URL]) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[self.request URL] forKey:NSURLErrorFailingURLErrorKey];
                error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];
            }

            [self performSelector:@selector(connection:didFailWithError:) withObject:self.connection withObject:error];

        } else {
            [self finish];
        }
    }

    [self.lock unlock];
}

#pragma mark - output stream

- (void)outputStream_open
{
    self.outputStream = [NSOutputStream outputStreamToMemory];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    [self.outputStream open];
}

- (void)outputStream_close
{
    if (!self.outputStream) {
        return;
    }

    [self.outputStream close];
    self.outputStream = nil;
}


#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self outputStream_open];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSInteger totalNumberOfBytesWritten = 0;

    NSUInteger length = [data length];
    if ([self.outputStream hasSpaceAvailable]) {
        const uint8_t *dataBuffer = (uint8_t *)[data bytes];

        NSInteger numberOfBytesWritten = 0;
        while (totalNumberOfBytesWritten < (NSInteger)length) {
            numberOfBytesWritten = [self.outputStream write:&dataBuffer[(NSUInteger)totalNumberOfBytesWritten] maxLength:(length - (NSUInteger)totalNumberOfBytesWritten)];
            if (numberOfBytesWritten == -1) {
                break;
            }

            totalNumberOfBytesWritten += numberOfBytesWritten;
        }
    }

    if ([self.outputStream streamError]) {
        [self performSelector:@selector(connection:didFailWithError:) withObject:self.connection withObject:[self.outputStream streamError]];
        return;
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    // connection doesnt cache, operation use ImageLoader"s cache
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.responseData = [self.outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    [self outputStream_close];

    [self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self outputStream_close];

    [self.connection cancel];
    [self finish];
}

- (void)dealloc
{
    [self outputStream_close];
}

@end