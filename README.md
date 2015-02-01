ImageLoader [![Build-Status](https://img.shields.io/travis/hirohisa/ImageLoader.svg)](https://travis-ci.org/hirohisa/ImageLoader.png?branch=master) [![GitHub-version](https://img.shields.io/cocoapods/v/ImageLoader.svg)](https://github.com/hirohisa/ImageLoader/tags) [![platform](https://img.shields.io/cocoapods/p/ImageLoader.svg)](https://github.com/hirohisa/ImageLoader) [![license](https://img.shields.io/cocoapods/l/ImageLoader.svg)](https://github.com/hirohisa/ImageLoader/blob/master/LICENSE)
===========

ImageLoader is an instrument for asynchronous image loading.

Features
----------

- [x] Simple methods with UIImageView Category.
- [x] A module for cache can be set by yourself. [hirohisa/Diskcached](https://github.com/hirohisa/Diskcached)
- [x] Loading images is handled by ImageLoader, not UIImageView.
- [x] Easy to modify implementation from other modules

Installation
----------

There are two ways to use this in your project:

- Copy the ImageLoader class files into your project

- Install with CocoaPods to write Podfile
```ruby
platform :ios
pod 'ImageLoader', '~> 0.1.1'
```

Modify implementation from other modules
----------

impliment same methods
```objc
[imageView setImageWithURL:URL];
[imageView setImageWithURL:URL placeholderImage:nil];
```

#### AFNetworking

from:
```objc
#import <SDWebImage/UIImageView+WebCache.h>
```

to:
```objc
#import <ImageLoader/UIImageView+ImageLoader.h>
```

#### SDWebImage

from:
```objc
#import <AFNetworking/UIImageView+AFNetworking.h>
```

to:
```objc
#import <ImageLoader/UIImageView+ImageLoader.h>
```


## License

ImageLoader is available under the MIT license.
