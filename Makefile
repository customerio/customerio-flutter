# How to call: make setupios_localsdk path="/Users/levi/code/customerio-ios"
setupios_localsdk:
	cd example/ios/ && INSTALL_IOS_SDK_LOCAL=$(path) pod install && cd ../../

# How to call: make setupios_branchsdk branch_name="levi/gist-event-listeners"
setupios_branchsdk:
	cd example/ios/ && INSTALL_IOS_SDK_BRANCH=$(branch_name) pod install && cd ../../