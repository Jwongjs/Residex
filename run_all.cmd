@echo off
REM Double-click launcher for the full Documind stack (backend + emulator + app).
REM Delegates to run_all.ps1 with execution policy bypass so it "just works".
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_all.ps1"
echo.
echo === run_all finished. Press any key to close this window. ===
pause >nul