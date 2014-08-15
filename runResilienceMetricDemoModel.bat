@echo off
REM set PATH=%PATH%;C:\Octave\Octave3.4.3_gcc4.5.2\Octave3.4.3_gcc4.5.2\bin
java -Djava.library.path=lib -Djava.ext.dirs= -XX:MaxPermSize=128m -Xmx1024m -Duser.language=en -Duser.country=US -jar matpowerconnect/matpowerconnect.jar ResilienceMetricDemoModel.nlogo


