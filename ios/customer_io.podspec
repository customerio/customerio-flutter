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
  s.platform = :ios, '13.0'

  # We need the local iOS SDK installing to come from this podspec file and not from example/ios/Podfile. 
  # Because we need the flutter SDK to use this local dependency, not just the local dependency inside of the example app. 

  # Currently testing by going into ios example app directory with Podfile and running `pod install`. Although, 
  # I don't think that verifies for me that the local flutter SDK is using the local IOS SDK but it just tests the example app is. 

  # Automatically install local version of the iOS SDK if the iOS SDK source code is installed alongside the flutter SDK. 
  local_ios_sdk_install_path = File.expand_path(File.join('..', '..', "customerio-ios"), Dir.pwd)
  if Dir.exist?(local_ios_sdk_install_path)
    puts "Installing local version of the iOS SDK for convenient development. Path of iOS SDK: #{local_ios_sdk_install_path}"

    s.dependency "CustomerIOTracking"
    # s.dependency "CustomerIOMessagingInApp"
    # s.dependency "CustomerIOMessagingPushFCM"

    s.subspec 'CustomerIOTracking' do |ss|
      ss.source_files  = "Sources/Tracking/**/*"

      # PROBLEM: we need to call ss.module_name but cocoapods will not let you. 
      # See : https://github.com/customerio/issues/issues/8972 
      # to be able to no longer need module_name in this subspec. 
    end
  else 
    puts "Note: If you install the Customer.io iOS SDK source code to path #{local_ios_sdk_install_path}, the iOS example app will use that local version of the SDK for convenient local development."

    s.dependency "CustomerIO/Tracking", '~> 2.0.0'
    s.dependency "CustomerIO/MessagingInApp", '~> 2.0.0'
    s.dependency "CustomerIO/MessagingPushFCM", '~> 2.0.0'
  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
