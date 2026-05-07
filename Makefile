# Makefile for Flutter project

.PHONY: help setup test test-coverage analyze build-android build-ios clean install-hooks

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Install dependencies and setup hooks
	@echo "📦 Installing dependencies..."
	flutter pub get
	@echo "🔧 Setting up Git hooks..."
	@bash setup-hooks.sh || setup-hooks.bat
	@echo "✅ Setup complete!"

test: ## Run all tests
	@echo "🧪 Running tests..."
	flutter test --no-pub

test-coverage: ## Run tests with coverage
	@echo "🧪 Running tests with coverage..."
	flutter test --coverage --no-pub
	@echo "📊 Coverage report generated at coverage/lcov.info"

test-watch: ## Run tests in watch mode
	@echo "👀 Running tests in watch mode..."
	flutter test --no-pub --watch

analyze: ## Run Flutter analyze
	@echo "📊 Running Flutter analyze..."
	flutter analyze

format: ## Format code
	@echo "✨ Formatting code..."
	dart format lib/ test/

format-check: ## Check code formatting
	@echo "🔍 Checking code formatting..."
	dart format --set-exit-if-changed lib/ test/

build-android: test ## Build Android APK
	@echo "🤖 Building Android APK..."
	flutter build apk --release

build-android-debug: ## Build Android APK (debug)
	@echo "🤖 Building Android APK (debug)..."
	flutter build apk --debug

build-ios: test ## Build iOS app
	@echo "🍎 Building iOS app..."
	flutter build ios --release --no-codesign

clean: ## Clean build files
	@echo "🧹 Cleaning build files..."
	flutter clean
	rm -rf coverage/

install-hooks: ## Install Git hooks
	@echo "🔧 Installing Git hooks..."
	@bash setup-hooks.sh || setup-hooks.bat

doctor: ## Run Flutter doctor
	@echo "🏥 Running Flutter doctor..."
	flutter doctor -v

pub-get: ## Get dependencies
	@echo "📦 Getting dependencies..."
	flutter pub get

pub-upgrade: ## Upgrade dependencies
	@echo "⬆️  Upgrading dependencies..."
	flutter pub upgrade

run: ## Run the app
	@echo "🚀 Running app..."
	flutter run

run-release: ## Run the app in release mode
	@echo "🚀 Running app (release mode)..."
	flutter run --release

ci: analyze test ## Run CI checks (analyze + test)
	@echo "✅ CI checks passed!"
