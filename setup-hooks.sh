#!/bin/bash
# Setup script to install Git hooks

echo "🔧 Setting up Git hooks..."

# Create .git/hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy hooks from .githooks to .git/hooks
cp .githooks/pre-commit .git/hooks/pre-commit
cp .githooks/pre-push .git/hooks/pre-push

# Make hooks executable
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push

echo "✅ Git hooks installed successfully!"
echo ""
echo "📝 Hooks installed:"
echo "  - pre-commit: Runs tests before each commit"
echo "  - pre-push: Runs tests and analysis before each push"
echo ""
echo "💡 To skip hooks, use:"
echo "  - git commit --no-verify"
echo "  - git push --no-verify"
