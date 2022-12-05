#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint customer_io.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'customer_io'
  s.version          = '0.0.1'
  s.summary          = 'A plugin for Customer.io'
  s.description      = <<-DESC
A plugin for Customer.io
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency "CustomerIOTracking", '~> 1.2.6'
  s.dependency "CustomerIOMessagingInApp", '~> 1.2.6'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
