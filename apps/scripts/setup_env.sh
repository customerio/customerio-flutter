#!/usr/bin/env bash

# Sets up environment files needed to build and run a sample app locally.
# Creates .env and ios/Env.swift from their example templates if they don't exist.
# Safe to run multiple times — won't overwrite existing files.
#
# Usage: ./apps/scripts/setup_env.sh <app_directory>
# Example: ./apps/scripts/setup_env.sh apps/flutter_sample_spm

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <app_directory>"
  echo "Example: $0 apps/flutter_sample_spm"
  exit 1
fi

APP_DIR="$1"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Error: Directory '$APP_DIR' does not exist."
  exit 1
fi

cd "$APP_DIR"

if [[ ! -f ".env" ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
else
  echo ".env already exists, skipping"
fi

if [[ ! -f "ios/Env.swift" ]]; then
  cp ios/Env.swift.example ios/Env.swift
  echo "Created ios/Env.swift from Env.swift.example"
else
  echo "ios/Env.swift already exists, skipping"
fi

echo "Environment setup complete. Update .env and ios/Env.swift with real credentials if needed."
