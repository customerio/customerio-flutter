#!/usr/bin/env bash

set -eo pipefail

function main() {
	cat <<EOF
===============================================================================
amiapp-flutter setup checklist

Follow the steps in to setup dev environment to be able to build and run the
amiapp-flutter app in the simulator or on a phone.
You can follow along and manually run all the steps, but some do offer you the
option to run the commands for you as well.
===============================================================================
EOF

	step 'Install Xcode from the App Store or the Self Service app'

	step 'Set xcode command line tools
- Open Xcode
- In the menu bar select Xcode -> Settings
- Go to the Locations tab
- Ensure Command Line Tools are set under the dropdown
	- If it mentions "No Xcode Selected" just pick the latest version from the dropdown
https://stackoverflow.com/questions/50404109/unable-to-locate-xcode-please-make-sure-to-have-xcode-installed-on-your-machine/51246596#51246596'

	step 'Install Android Studio from their website or using homebrew by running:
	brew install --cask android-studio' run_install_android_studio

	step 'Set environment variables for java and android tools by running:
	export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
	export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
	export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
	export PATH="$ANDROID_SDK_ROOT/tools:$PATH"
You may want to save these in your ~/.zshrc file so that you do not need to set it again.'

	step 'Optional - Create virtual device
- With Android Studio open 
- In the menu bar select Tools -> Device Manager
- In the Device Manager panel click on Create Device button
- Select phone hardware ex. Pixel 6
- Download a system image by clicking the download icon next to the release name ex. Tiramisu
- Follow prompts to get virtual device setup'

	step 'Install Google Chrome browser from the App Store or using homebrew by running:
	brew install --cask google-chrome' run_install_chrome

	step 'Clone the "amiapp-flutter" repository by running:
	git clone git@github.com:customerio/amiapp-flutter.git' run_clone_repo

	step 'Download google credentials file and save it for android project
- Open 1Password
- Search for "Ami App Flutter - google-services.json"
- Download the file and save in the "amiapp-flutter/android/app" directory'

	step 'Download google credentials file and save it for ios project
- Open 1Password
- Search for "Ami App Flutter - GoogleService-Info.plist"
- Download the file and save in the "amiapp-flutter/ios/Runner" directory'

	step 'Download google credentials and save it.
- Open 1Password
- Search for "gc_keys.json"
- Download the file and save to easily referenced location (eg. ~/code/dev-creds/gc_keys.json)'

	step 'Set environment variable to the saved credential file by running:
	export FASTLANE_GC_KEYS_FILE=[path to file from previous step] ex.
	export FASTLANE_GC_KEYS_FILE=~/code/dev-creds/gc_keys.json
You can also save this in your ~/.zshrc file so that you do not need to set it again.'

	step 'Navigate into the "amiapp-flutter" repository'

	step 'Copy sample env file by running:
	cp .env.example .env' run_copy_env_file

	step 'Copy ios sample env file by running:
	cp ios/Env.swift.example ios/Env.swift' run_copy_ios_env_file

	step 'Update the credentials in the ".env" & "ios/Env.swift" files'

	step 'Install/Switch to ruby version specified in the .ruby-version file.
Syntax depends on the version manager tool you are using.
Some tools: rbenv, rvm, chruby, asdf, rtx, frum'

	step 'Install bundler tool to manage ruby gems for project by running:
	gem install bundler' run_install_bundler

	step 'Use bundler to install tools for the project by running:
	bundle install' run_install_gems

	step 'Install certificates & profiles for development by running:
	bundle exec fastlane ios dev_setup' run_fastlane_setup

	step 'Install/Switch to flutter version specified in the .flutter-version file.
Syntax depends on the version manager tool you are using.
Some tools: fvm, asdf, rtx'

	step 'Ensure environment is properly setup by running:
	flutter doctor
Note: command may display some errors that need to be fixed and this script will show optional steps next for common issues and fixes' run_flutter_doc

	step 'Optional Fix - If you get the error

[!] Android Studio (version 2022.1)
    ✗ Unable to find bundled Java version.

run the following cmd:
	ln -s "/Applications/Android Studio.app/Contents/jbr" "/Applications/Android Studio.app/Contents/jre"' run_link_jre

	step 'Optional Fix - If you get the error

[!] Android toolchain - develop for Android devices
    ✗ cmdline-tools component is missing

- Open Android Studio
- In the menu bar select Android Studio -> Settings
- On left nav go to Appearance & Behaviour -> System Settigns -> Android SDK
- On right pane select the "SDK Tools" tab
- Check "Android SDK Command-line Tools (latest)" and click "OK" to download and install'

	step 'Optional Fix - If you get the error

[!] Android toolchain - develop for Android devices
    ! Some Android licenses not accepted.

run the following cmd:
	flutter doctor --android-licenses' run_accept_licenses

	step 'Install tools for the project by running:
	flutter pub get' run_install_flutter_deps

	step 'Install iOS project dependencies using cocoapods by running:
	bundle exec pod install --project-directory=ios' run_install_pods

	step 'Optional - Check emulators avaialbe by running:
	flutter emulators' run_list_emulators

	step 'Optional - Start emulator by running:
	flutter emulators --launch "Emulator Name"'

	step 'Optional - Check devices avaialbe by running:
	flutter devices' run_list_devices

	step 'Optional - Run app on device or emulator by running:
	flutter run
Note: if you have multiple targets avaialbe you can choose which one to run on' run_start_project

}

# automated run functions to run the specified step

function run_clone_repo() {
	read -p "Directory where the repository should be cloned to: " dir
	if [[ ! -d "$dir" ]]; then
		echo "The directory $dir does not exist."
		exit 1
	fi

	repo_dir="$dir/amiapp-flutter"
	if [[ ! -d "$repo_dir" ]] ; then
	  git clone git@github.com:customerio/amiapp-flutter.git $repo_dir
	fi
}

function run_install_android_studio() {
	if [[ ! "$(command -v brew)" ]]; then
		echo "automated setup uses homebrew which is missing. install using:"
		echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
		exit 1
	fi 

	brew install --cask android-studio
}

function run_install_chrome() {
	if [[ ! "$(command -v brew)" ]]; then
		echo "automated setup uses homebrew which is missing. install using:"
		echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
		exit 1
	fi 

	brew install --cask google-chrome
}

function run_install_bundler() {
	check_ruby_version
	gem install bundler
}

function run_install_gems() {
	check_ruby_version

	if [[ ! -f "$repo_dir/Gemfile" ]]; then
		echo "Missing Gemfile recheck path to repository."
		exit 1
	fi

	bundle install
}

function run_fastlane_setup() {
	check_ruby_version

	if [[ -z "$FASTLANE_GC_KEYS_FILE" ]]; then
		read -p "Path to the gc_keys.json file: " keys_file
		export FASTLANE_GC_KEYS_FILE=$keys_file
	fi

	bundle exec fastlane ios dev_setup
}

function run_copy_env_file() {
	set_repo_dir
	cd $repo_dir

	if [[ ! -f ".env" ]] ; then
	  cp .env.example .env
	fi
}

function run_copy_ios_env_file() {
	set_repo_dir
	cd $repo_dir

	if [[ ! -f "ios/Env.swift" ]] ; then
	  cp ios/Env.swift.example ios/Env.swift
	fi
}

function run_install_flutter_deps() {
	check_flutter_version
	flutter pub get
}

function run_accept_licenses() {
	check_flutter_version
	flutter doctor --android-licenses	
}

function run_install_pods() {
	check_ruby_version
	bundle exec pod install --project-directory=ios
}

function run_start_project() {
	check_flutter_version
	flutter run
}

function run_list_emulators() {
	check_flutter_version
	flutter emulators
}

function run_list_devices() {
	check_flutter_version
	flutter devices
}

function run_flutter_doc() {
	check_flutter_version
	flutter doctor
}

function run_link_jre() {
	ln -s "/Applications/Android Studio.app/Contents/jbr" "/Applications/Android Studio.app/Contents/jre"
}

# helper functions

# helper utility to check node version matches from .node-version file.
# 
function check_flutter_version() {
	set_repo_dir

	cd $repo_dir

	if ! flutter --version | grep -q $(cat .flutter-version); then
		echo "Detected different flutter version
	got: $(flutter --version)
	expected: $(cat .flutter-version)
May need to switch to the flutter version in the shell and rerun this script."
		exit 1
	fi
}

# helper utility to check ruby version matches from .ruby-version file.
# 
function check_ruby_version() {
	set_repo_dir

	cd $repo_dir

	if ! ruby -v | grep -q $(cat .ruby-version); then
		echo "Detected different ruby version
	got: $(ruby -v)
	expected: $(cat .ruby-version)
May need to switch to the ruby version in the shell and rerun this script."
		exit 1
	fi
}


# helper utility to check if repo_dir variable exists or prompt for it.
# 
function set_repo_dir() {
	if [[ ! -d "$repo_dir" ]]; then
		read -p "Path to the repository: " repo_dir
	fi

	if [[ ! -d "$repo_dir" ]] ; then
		echo "Repository not found."
		exit 1
	fi
}

# helper utility to print the step and handle the user input.
# params:
# 	$1 - description of the step
# 	$2 - function to call if step can be run within the script if user opts for it
# 
function step() {
	((step_idx++))
	cat <<EOF

Step $step_idx: $1

EOF

	handle_input $2
}

# helper utility to ask for user input.
# params:
# 	$1 - if provided enables run option and calls function if selected
# 
function handle_input() {
	local prompt=''
	if [[ -n $1 ]]; then
		while true; do
			read -p "Choose [c]ontinue, [q]uit or [r]un: " answer
			case $answer in
				[Qq]* ) exit 0 ;;
				[Cc]* ) break ;;
				[Rr]* ) $1 && break ;;
			esac
		done
	else
		while true; do
			read -p "Choose [c]ontinue or [q]uit: " answer
			case $answer in
				[Qq]* ) exit 0 ;;
				[Cc]* ) break ;;
			esac
		done
	fi
}

main "$@"
