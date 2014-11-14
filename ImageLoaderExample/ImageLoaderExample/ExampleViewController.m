//
//  ExampleViewController.m
//  ImageLoaderExample
//
//  Created by Hirohisa Kawasaki on 2014/06/27.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import "ExampleViewController.h"
#import "BrickView.h"
#import "ImageLoader.h"
#import "UIImageView+ImageLoader.h"

@interface UIImage (Example)

+ (UIImage *)imageWithColor:(UIColor *)color;

@end

@implementation UIImage (Example)

+ (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end

@interface UIImageView (Example)

+ (ImageLoader *)il_sharedImageLoader;

@end

@interface ExampleBrickViewCell : BrickViewCell

@property (nonatomic, readonly) UIImageView *imageView;

@end

@implementation ExampleBrickViewCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        _imageView = [UIImageView new];
        [self addSubview:self.imageView];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.imageView.frame = self.bounds;
}

@end


@interface NSURL (Example)

@end

@implementation NSURL (Example)

+ (instancetype)imageURLWithIndex:(NSInteger)index
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://s3.amazonaws.com/fast-image-cache/demo-images/FICDDemoImage%03ld.jpg", (long)index]];
}

@end

@interface ExampleViewController () <BrickViewDataSource, BrickViewDelegate>

@end

@implementation ExampleViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    BrickView *brickView = [[BrickView alloc] initWithFrame:self.view.bounds];
    brickView.dataSource = self;
    brickView.delegate   = self;
    [self.view addSubview:brickView];
}

- (CGFloat)brickView:(BrickView *)brickView heightForCellAtIndex:(NSInteger)index
{
    return 80;
}

- (NSInteger)numberOfCellsInBrickView:(BrickView *)brickView
{
    return 100;
}

- (NSInteger)numberOfColumnsInBrickView:(BrickView *)brickView
{
    return 2;
}

- (BrickViewCell *)brickView:(BrickView *)brickView cellAtIndex:(NSInteger)index
{
    ExampleBrickViewCell *cell = [brickView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[ExampleBrickViewCell alloc] initWithReuseIdentifier:@"Cell"];
    }

    NSURL *URL = [NSURL imageURLWithIndex:index];

    if (!index%10) {
        URL = nil;
    }

    [cell.imageView il_setImageWithURL:URL placeholderImage:[UIImage imageWithColor:[UIColor grayColor]] completion:^(BOOL finished) {
        NSLog(@"%ld, finished %d", (long)index, finished);
    }];

    return cell;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    NSLog(@"%s", __func__);
    NSOperationQueue *queue = [[[UIImageView class] il_sharedImageLoader] performSelector:@selector(operationQueue)];
    for (NSOperation *op in queue.operations) {
        NSLog(@"%@, cancel %d finish %d", op, op.isCancelled, op.isFinished);
    }
}

@end
