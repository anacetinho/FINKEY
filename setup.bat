@echo off
title FinKey Setup Wizard
cls
echo ================================================
echo        🗝️ FinKey Personal Finance Setup 🗝️
echo ================================================
echo.
echo Welcome to FinKey - Your Personal Finance Command Center!
echo This wizard will set up everything you need to get started.
echo.

REM Check Docker Desktop
echo [1/4] Checking Docker Desktop...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Desktop not found!
    echo.
    echo Please install Docker Desktop first:
    echo 📥 Download: https://www.docker.com/products/docker-desktop/
    echo.
    echo After installation, restart this setup script.
    echo.
    pause
    exit /b 1
)
echo ✅ Docker Desktop found!
echo.

REM Check if Docker is running
echo [2/4] Checking if Docker is running...
docker ps >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Desktop is not running!
    echo.
    echo Please start Docker Desktop and wait for it to fully load.
    echo Look for the Docker icon in your system tray.
    echo When it shows "Docker Desktop is running", restart this script.
    echo.
    pause
    exit /b 1
)
echo ✅ Docker is running!
echo.

REM Setup environment file
echo [3/4] Setting up configuration...
if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env" >nul
        echo ✅ Configuration file created (.env from .env.example)
    ) else (
        echo ⚠️  .env.example not found, creating basic .env
        echo SELF_HOSTED=true > .env
        echo PORT=3000 >> .env
    )
) else (
    echo ℹ️  Configuration file already exists
)
echo.

REM Start the application
echo [4/4] Starting FinKey...
echo.
echo ⏳ This may take 5-10 minutes on first run while Docker downloads and builds everything...
echo    You can safely minimize this window and check back later.
echo.
docker-compose up -d --build

if errorlevel 1 (
    echo.
    echo ❌ Failed to start FinKey containers.
    echo.
    echo Common solutions:
    echo - Make sure Docker Desktop is running
    echo - Check if ports 3000, 5432, or 6379 are already in use
    echo - Try: docker-compose down, then run this script again
    echo.
    pause
    exit /b 1
)

REM Wait a moment and check container status
echo.
echo Waiting for services to start...
timeout /t 15 /nobreak >nul

echo.
echo 📊 Container Status:
docker-compose ps

echo.
echo ================================================
echo        🎉 FinKey Setup Complete! 🎉
echo ================================================
echo.
echo 🌐 Access your FinKey instance at: http://localhost:3000
echo.
echo 💡 Important Notes:
echo    • First startup may take 1-2 minutes to initialize database
echo    • If you see connection errors, wait a bit longer and refresh
echo    • Default port is 3000 (change in .env file if needed)
echo.
echo 📋 Useful Commands:
echo    • Check status: docker-compose ps
echo    • View logs: docker-compose logs
echo    • Stop FinKey: docker-compose down
echo    • Restart: docker-compose restart
echo.
echo 🔧 Need help? Check the documentation in the docs/ folder
echo.
echo Opening http://localhost:3000 in your default browser...
timeout /t 3 /nobreak >nul

REM Try to open browser (works on most Windows systems)
start http://localhost:3000 2>nul

echo.
echo Press any key to exit...
pause >nul