@echo off
:: Wazuh Active Response Windows CMD Wrapper
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0remove-threat.ps1"
