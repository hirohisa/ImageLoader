ImageLoader [![Build Status](https://travis-ci.org/hirohisa/ImageLoader.png?branch=master)](https://travis-ci.org/hirohisa/ImageLoader)
===========

ImageLoader is an instrument for asynchronous image loading.

Features
----------

- Simple methods with UIImageView Category.
- A module for cache can be set by yourself.
- ~~An observer with NSNotification.~~
- Loading images is handled by ImageLoader, not UIImageView.
- Easy to modify implementation from other modules

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

