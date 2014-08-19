ImageLoader
===========

ImageLoader is an instrument for asynchronous image loading.

Features
----------

- Simple methods with UIImageView Category.
- A module for cache can be set by yourself.
- ~~An observer with NSNotification.~~
- Loading images is handled by ImageLoader, not UIImageView.



Installation
----------

There are two ways to use this in your project:

- Copy the ImageLoader class files into your project

- Install with CocoaPods to write Podfile
```ruby
platform :ios
pod 'ImageLoader', '~> 0.0.1'
```

Example with other modules
----------

**ImageLoader**

```objc
UIImageView *imageView = [UIImageView new];
[imageView il_setImageWithURL:URL placeholderImage:nil];
```

**AFNetworking**

```objc
UIImageView *imageView = [UIImageView new];
[imageView setImageWithURL:URL placeholderImage:nil];
```

**SDWebImage**

```objc
UIImageView *imageView = [UIImageView new];
[imageView sd_setImageWithURL:URL placeholderImage:nil completed:NULL];
```



## License

ImageLoader is available under the MIT license.

