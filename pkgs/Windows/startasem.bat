@echo off

rem DESCRIPTION:
rem Run ASEM-51 assembler from the IDE silently, i.e. without showing any additional windows.

SETLOCAL ENABLEEXTENSIONS
cd %1
SHIFT

:Loop
IF "%1"=="" GOTO Continue
SET args=%args% %1
SHIFT
GOTO Loop
:Continue

asem %args%
