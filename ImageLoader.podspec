Pod::Spec.new do |s|

  s.name         =  "ImageLoader"
  s.version      =  "0.1.5"
  s.summary      =  "Library for asynchronous image loading."
  s.description  =  "ImageLoader is an instrument for asynchronous image loading."

  s.homepage     =  "https://github.com/hirohisa/ImageLoader"
  s.license      =  { :type => "MIT", :file => "LICENSE" }
  s.author       =  { "Hirohisa Kawasaki" => "hirohisa.kawasaki@gmail.com" }
  s.platform     =  :ios, 5.0
  s.source       =  {
                      :git => "https://github.com/hirohisa/ImageLoader.git",
                      :tag => s.version
                    }

  s.source_files = "ImageLoader"
  s.requires_arc = true
  s.dependency     'Diskcached', '~> 0.1.1'

end
