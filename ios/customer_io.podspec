#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint customer_io.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name        = 'customer_io'
  s.version     = '1.0.0-alpha.8'
  s.summary     = 'Customer.io plugin for Flutter'
  s.homepage    = 'https://customer.io/'
  s.license     = { :file => '../LICENSE' }
  s.author      = { "CustomerIO Team" => "win@customer.io" }
  s.source      = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.dependency "CustomerIOTracking", '~> 2.1.0-beta.2'
  s.dependency "CustomerIOMessagingInApp", '~> 2.1.0-beta.2'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
