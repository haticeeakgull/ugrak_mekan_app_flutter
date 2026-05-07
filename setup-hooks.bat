@echo off
REM Setup script to install Git hooks (Windows)

echo Setting up Git hooks...

REM Create .git/hooks directory if it doesn't exist
if not exist ".git\hooks" mkdir ".git\hooks"

REM Copy hooks from .githooks to .git/hooks
copy /Y ".githooks\pre-commit" ".git\hooks\pre-commit"
copy /Y ".githooks\pre-push" ".git\hooks\pre-push"

echo.
echo Git hooks installed successfully!
echo.
echo Hooks installed:
echo   - pre-commit: Runs tests before each commit
echo   - pre-push: Runs tests and analysis before each push
echo.
echo To skip hooks, use:
echo   - git commit --no-verify
echo   - git push --no-verify
echo.
pause
