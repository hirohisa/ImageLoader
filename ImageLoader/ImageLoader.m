//
//  ImageLoader.m
//  ImageLoader
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import "ImageLoader.h"


NSString *const ImageLoaderCacheNotConfirmToProtocolException = @"ImageLoaderDidCompletionNotification";

NSString *const ImageLoaderDidCompletionNotification = @"ImageLoaderDidCompletionNotification";
NSString *const ImageLoaderImageKey = @"ImageLoaderImageKey";
NSString *const ImageLoaderURLKey = @"ImageLoaderURLKey";


typedef NS_ENUM(NSInteger, ImageLoaderOperationState) {
    ImageLoaderOperationReadyState = 0,
    ImageLoaderOperationExecutingState = 1,
    ImageLoaderOperationFinishedState = 2,
};

@interface ImageLoaderCache : NSCache <ImageLoaderCacheProtocol>

@end

@implementation ImageLoaderCache

+ (instancetype)il_sharedCache
{
    static dispatch_once_t onceToken;
    __strong static ImageLoaderCache *_singleton = nil;
    dispatch_once(&onceToken, ^{
        _singleton = [[self alloc] init];
    });
    return _singleton;
}

@end

@interface ImageLoaderOperation () <NSURLConnectionDataDelegate>

@property (nonatomic, readonly) NSString *name;

@property (nonatomic) ImageLoaderOperationState state;
@property (nonatomic, readonly, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSData *responseData;

@property (nonatomic, strong) id<ImageLoaderCacheProtocol> cache;
@property (nonatomic, strong) NSRecursiveLock *lock;

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

- (id)initWithRequest:(NSURLRequest *)request name:(NSString *)name cache:(id<ImageLoaderCacheProtocol>)cache completion:(void (^)(UIImage *))completion
{
    self = [self init];
    if (self) {
        _name = name;
        _state = ImageLoaderOperationReadyState;
        _lock = [[NSRecursiveLock alloc] init];
        _request = request;
        _cache = cache;
        __weak typeof(self) wSelf = self;
        self.completionBlock = ^{
            UIImage *image = [UIImage imageWithData:wSelf.responseData];
            completion(image?:nil);
        };
    }
    return self;
}

#pragma mark - getter

- (NSOutputStream *)outputStream {
    if (!_outputStream) {
        _outputStream = [NSOutputStream outputStreamToMemory];
    }

    return _outputStream;
}

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

- (BOOL)hasWithURL:(NSURL *)URL andName:(NSString *)name
{
    if ([self.request.URL isEqual:URL] &&
        [self.name isEqual:name]) {
        return YES;
    }
    return NO;
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
    _request = nil;

    if (self.completionBlock) {
        self.completionBlock();
    }

    [self.lock unlock];
}

#pragma mark -

- (void)operation_run
{
    [self.lock lock];

    NSData *data = [self.cache objectForKey:[self.request.URL absoluteString]];
    if (data) {
        self.responseData = data;
        [self finish];
    } else {
        [self operation_request];
    }

    [self.lock unlock];
}

- (void)operation_request
{
    [self.lock lock];

    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
    [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.connection start];

    [self.lock unlock];
}

- (void)operation_cancel
{
    [self.lock lock];

    if (![self isFinished]) {
        if (self.connection) {
            [self.connection cancel];
        } else {
            [self finish];
        }
    }

    [self.lock unlock];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.outputStream open];
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
        [self.connection cancel];
        [self performSelector:@selector(connection:didFailWithError:) withObject:self.connection withObject:[self.outputStream streamError]];
        [self cancel];
        return;
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    if ([self isCancelled]) {
        return nil;
    }

    return cachedResponse;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.responseData = [self.outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    [self.outputStream close];

    if (self.responseData) {
        [self.cache setObject:self.responseData forKey:[self.request.URL absoluteString]];
        self.outputStream = nil;
    }

    [self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.outputStream close];
    if (self.responseData) {
        self.outputStream = nil;
    }

    self.connection = nil;
    [self finish];
}

- (void)dealloc
{
    if (_outputStream) {
        [_outputStream close];
        _outputStream = nil;
    }
}

@end

@interface ImageLoader ()

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation ImageLoader

+ (instancetype)il_sharedLoader
{
    static dispatch_once_t onceToken;
    __strong static ImageLoader *_singleton = nil;
    dispatch_once(&onceToken, ^{
        _singleton = [[self alloc] init];
    });
    return _singleton;
}

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
    _cache = [ImageLoaderCache il_sharedCache];
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

- (ImageLoaderOperation *)getImageWithURL:(NSURL *)URL
{
    void (^completion)(UIImage *) = ^(UIImage *image) {
        NSDictionary *userInfo = @{};

        if (URL && image) {
            userInfo  = @{
                          ImageLoaderImageKey: image,
                          ImageLoaderURLKey  : URL
                          };
        };

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:ImageLoaderDidCompletionNotification object:userInfo];
        });
    };

    return [self _getImageWithURL:URL completion:completion name:@"default"];
}

- (ImageLoaderOperation *)getImageWithURL:(NSURL *)URL completion:(void (^)(UIImage *image))completion
{
    return [self _getImageWithURL:URL completion:completion name:nil];
}

#pragma mark - private

- (ImageLoaderOperation *)_getImageWithURL:(NSURL *)URL completion:(void (^)(UIImage *image))completion name:(NSString *)name
{
    for (ImageLoaderOperation *operation in self.operationQueue.operations) {
        if ([operation hasWithURL:URL andName:name]) {
            return operation;
        }
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    ImageLoaderOperation *operation = [[ImageLoaderOperation alloc] initWithRequest:request
                                                                               name:name
                                                                              cache:self.cache
                                                                         completion:completion];
    [self enqueue:operation];

    return operation;
}

@end