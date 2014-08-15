#!/bin/sh
cd "`dirname "$0"`"		# the copious quoting is for handling paths with spaces
java -server -Djava.library.path=./lib -Djava.ext.dirs= -XX:MaxPermSize=128m -Xmx1024m -Duser.language=en -Duser.country=US -jar matpowerconnect/matpowerconnect.jar ResilienceMetricDemoModel.nlogo "$@"
