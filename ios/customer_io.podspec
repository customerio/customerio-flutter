#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint customer_io.podspec` to validate before publishing.
#
require 'yaml'

podspec_config = YAML.load_file('../pubspec.yaml')

Pod::Spec.new do |s|
  s.name        = podspec_config['name']
  s.version     = podspec_config['version']
  s.summary     = podspec_config['description']
  s.homepage    = podspec_config['homepage']
  s.license     = { :file => '../LICENSE' }
  s.author      = { "CustomerIO Team" => "win@customer.io" }
  s.source      = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.dependency "CustomerIO/DataPipelines", '~> 3'
  s.dependency "CustomerIO/MessagingInApp", '~> 3'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
