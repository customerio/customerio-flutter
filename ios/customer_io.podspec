#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint customer_io.podspec` to validate before publishing.
#
require 'yaml'

podspec_config = YAML.load_file('../pubspec.yaml')
# The native_sdk_version is the version of iOS native SDK that the Flutter plugin is compatible with.
native_sdk_version = podspec_config['flutter']['plugin']['platforms']['ios']['native_sdk_version']
firebase_wrapper_version = podspec_config['flutter']['plugin']['platforms']['ios']['firebase_wrapper_version']

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

  # Native SDK dependencies that are required for the Flutter plugin to work.
  s.dependency "CustomerIO/DataPipelines", native_sdk_version
  s.dependency "CustomerIO/MessagingInApp", native_sdk_version

  # If we do not specify a default_subspec, then *all* dependencies inside of *all* the subspecs will be downloaded by cocoapods.
  # We want customers to opt into push dependencies especially because the FCM subpsec downloads Firebase dependencies.
  # APN customers should not install Firebase dependencies at all.
  s.default_subspec = "nopush"

  s.subspec 'nopush' do |ss|
    # This is the default subspec designed to not install any push dependencies. Customer should choose APN or FCM.
    # The SDK at runtime currently requires the MessagingPush module so we do include it here.
    ss.dependency "CustomerIO/MessagingPush", native_sdk_version
  end

  # Note: Subspecs inherit all dependencies specified the parent spec (this file).
  s.subspec 'fcm' do |ss|
    ss.dependency "CustomerIO/MessagingPushFCM", native_sdk_version
    ss.dependency "CioFirebaseWrapper", firebase_wrapper_version
  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
