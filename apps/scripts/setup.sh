#!/usr/bin/env bash

# Interactive setup checklist for Flutter sample apps.
# Usage: ./apps/scripts/setup.sh <app_directory>
# Example: ./apps/scripts/setup.sh apps/flutter_sample_spm

set -eo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <app_directory>"
  echo "Example: $0 apps/flutter_sample_spm"
  exit 1
fi

if [[ ! -d "$1" ]]; then
  echo "Error: Directory '$1' does not exist."
  exit 1
fi

APP_DIR="$(cd "$1" && pwd)"
APP_NAME="$(basename "$APP_DIR")"

function main() {
	cat <<EOF
===============================================================================
$APP_NAME setup checklist

Follow the steps to setup your dev environment to build and run the
$APP_NAME app in the simulator or on a device.
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

	step "Setup environment files (.env and ios/Env.swift) by running:
	./apps/scripts/setup_env.sh $APP_DIR" run_setup_env

	step 'Optional - Update the credentials in the ".env" & "ios/Env.swift" files with real workspace values'

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
	flutter doctor' run_flutter_doc

	step 'Install flutter dependencies by running:
	flutter pub get' run_install_flutter_deps

	step 'Install iOS project dependencies using cocoapods by running:
	bundle exec pod install --project-directory=ios' run_install_pods

	step 'Optional - Run app on device or emulator by running:
	flutter run' run_start_project
}

# automated run functions

function run_install_android_studio() {
	if [[ ! "$(command -v brew)" ]]; then
		echo "automated setup uses homebrew which is missing. install using:"
		echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
		exit 1
	fi
	brew install --cask android-studio
}

function run_setup_env() {
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	"$SCRIPT_DIR/setup_env.sh" "$APP_DIR"
}

function run_install_bundler() {
	cd "$APP_DIR"
	gem install bundler
}

function run_install_gems() {
	cd "$APP_DIR"
	bundle install
}

function run_fastlane_setup() {
	cd "$APP_DIR"
	if [[ -z "${FASTLANE_GC_KEYS_FILE:-}" ]]; then
		read -p "Path to the gc_keys.json file: " keys_file
		export FASTLANE_GC_KEYS_FILE=$keys_file
	fi
	bundle exec fastlane ios dev_setup
}

function run_install_flutter_deps() {
	cd "$APP_DIR"
	flutter pub get
}

function run_install_pods() {
	cd "$APP_DIR"
	bundle exec pod install --project-directory=ios
}

function run_start_project() {
	cd "$APP_DIR"
	flutter run
}

function run_flutter_doc() {
	flutter doctor
}

# helper utilities

function step() {
	((step_idx++))
	cat <<EOF

Step $step_idx: $1

EOF
	handle_input $2
}

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
