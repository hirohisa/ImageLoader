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

typedef NS_ENUM(NSUInteger, ImageLoaderOperationState) {
    ImageLoaderOperationReadyState = 0,
    ImageLoaderOperationExecutingState = 1,
    ImageLoaderOperationFinishedState = 2,
};


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

    CGContextRef context = CGBitmapContextCreate(
                                                 NULL,
                                                 CGImageGetWidth([image CGImage]),
                                                 CGImageGetHeight([image CGImage]),
                                                 CGImageGetBitsPerComponent([image CGImage]),
                                                 0,
                                                 CGColorSpaceCreateDeviceRGB(),
                                                 CGImageGetBitmapInfo([image CGImage])
                                                 );


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

@interface ImageLoaderOperation () <NSURLConnectionDataDelegate>

@property (nonatomic) ImageLoaderOperationState state;
@property (nonatomic, readonly, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSData *responseData;

@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, readonly) NSArray *completionBlocks;

- (void)addCompletionBlock:(void (^)(NSURLRequest *, NSData *))block;

@end

@interface ImageLoaderOperation (Private)

- (NSString *)il_keyPathWithOperationState:(ImageLoaderOperationState)state;
- (BOOL)il_canShiftToState:(ImageLoaderOperationState)toState;

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

- (BOOL)il_canShiftToState:(ImageLoaderOperationState)toState
{
    if (self.state == toState) {
        return NO;
    }

    switch (self.state) {
        case ImageLoaderOperationReadyState:;
            return YES;
            break;

        case ImageLoaderOperationExecutingState:;
            return self.state < toState;
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

- (id)initWithRequest:(NSURLRequest *)request completion:(void (^)(NSURLRequest *, NSData *))completion
{
    self = [self init];
    if (self) {
        _state = ImageLoaderOperationReadyState;
        _lock = [[NSRecursiveLock alloc] init];
        _request = request;
        if (completion) {
            _completionBlocks = @[completion];
        } else {
            _completionBlocks = @[];
        }

        __weak typeof(self) wSelf = self;
        self.completionBlock = ^{
            for (void(^completion)(NSURLRequest *, NSData *) in wSelf.completionBlocks) {
                completion(wSelf.request, wSelf.responseData);
            }
        };
    }
    return self;
}

- (void)addCompletionBlock:(void (^)(NSURLRequest *, NSData *))block
{
    if (block) {
        _completionBlocks = [self.completionBlocks arrayByAddingObject:block];
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
    if (![self il_canShiftToState:state]) {
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
    [self finish];

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
        UIImage *image;

        if (data) {
            image = ILOptimizedImageWithData(data);
            if (image &&
                request.URL) {
                [wSelf.cache setObject:data forKey:[request.URL absoluteString]];
            }
        }

        if (completion) {
            completion(request, image);
        }
    };

    // operation exists
    for (ImageLoaderOperation *operation in self.operationQueue.operations) {
        if (!operation.isFinished &&
            [operation.request.URL isEqual:URL]) {
            [operation addCompletionBlock:completionBlock];
            return operation;
        }
    }

    NSData *data = [self.cache objectForKey:[URL absoluteString]];
    if (data) {
        UIImage *image = ILOptimizedImageWithData(data);
        if (completion) {
            completion(nil, image);
            return nil;
        }
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    ImageLoaderOperation *operation =
    [[ImageLoaderOperation alloc] initWithRequest:request completion:completionBlock];

    [self enqueue:operation];

    return operation;
}

@end