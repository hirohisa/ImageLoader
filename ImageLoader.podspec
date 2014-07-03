Pod::Spec.new do |s|
  s.name         =  "ImageLoader"
  s.version      =  "0.0.1"
  s.summary      =  "Library for async image loading"
  s.description  =  <<-DESC
                      Library for async image loading on iOS
                    DESC

  s.homepage     =  "https://github.com/hirohisa/ImageLoader"
  s.license      =  {  :type => "MIT", :file => "LICENSE" }
  s.author       =  { "Hirohisa Kawasaki" => "hirohisa.kawasaki@gmail.com" }
  s.platform     =  :ios, 5.0
  s.source       =  {
                      :git => "https://github.com/hirohisa/ImageLoader.git",
                      :tag => '0.0.1'
                    }

  s.source_files = "ImageLoader"
  s.requires_arc = true

end
