@echo off
cd C:\Users\gummy\.local\share\chezmoi
git --no-pager status
echo.
echo === DIFFS ===
git --no-pager diff
echo.
echo === CACHED DIFFS ===
git --no-pager diff --cached
echo.
echo === LOG ===
git --no-pager log --oneline -5
