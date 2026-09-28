@echo off
echo Starting JjikBap (찍밥) Backend Server...
echo.

cd /d %~dp0

echo Installing dependencies...
pip install -r requirements.txt

echo.
echo Starting server on http://0.0.0.0:8000
echo API Documentation: http://localhost:8000/docs
echo.

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
