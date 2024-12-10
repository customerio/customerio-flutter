#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint customer_io_richpush.podspec` to validate before publishing.
#
require 'yaml'

podspec_config = YAML.load_file('../pubspec.yaml')
# The native_sdk_version is the version of iOS native SDK that the Flutter plugin is compatible with.
native_sdk_version = podspec_config['flutter']['plugin']['platforms']['ios']['native_sdk_version']

# Used by customers to install native iOS dependencies inside their Notification Service Extension (NSE) target to setup rich push.
# Note: We need a unique podspec for rich push because the other podspecs in this project install too many dependencies that should not be installed inside of a NSE target.
# We need this podspec which installs minimal dependencies that are only included in the NSE target.
Pod::Spec.new do |s|
  s.name        = "customer_io_richpush"
  s.version     = podspec_config['version']
  s.summary     = podspec_config['description']
  s.homepage    = podspec_config['homepage']
  s.license     = { :file => '../LICENSE' }
  s.author      = { "CustomerIO Team" => "win@customer.io" }
  s.source      = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Careful when declaring dependencies here. All dependencies will be included in the App Extension target in Xcode, not the host iOS app.
  # s.dependency "X", "X"

  # Subspecs allow customers to choose between multiple options of what type of version of this rich push package they would like to install.
  s.subspec 'fcm' do |ss|
    ss.dependency "CustomerIO/MessagingPushFCM", native_sdk_version
  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
