#!/bin/bash
export DBT_OPTIMISED="/home/iceweb/run/events/optimised/events"
export DBALARM="/home/iceweb/run/dbalarm/alarm"
export DBSWARM="/home/iceweb/run/dbswarm/swarm"
if [ "$1" = "wrapper" ]; then
	echo "Will run dbdetectswarm_wrapper"
	dbdetectswarm_wrapper $DBT_OPTIMISED $DBALARM $DBSWARM /home/iceweb/run/pf/dbdetectswarm_fast.pf
fi
if [ "$1" = "computeEventRate" ]; then
	echo "Will run computeEventRate"
	computeEventRate -v -p dbdetectswarm_test.pf $DBT_OPTIMISED $DBSWARM GR
fi
if [ "$1" = "computeSwarmState" ]; then
	echo "Will run computeSwarmState"
	computeSwarmState -v -p dbdetectswarm_test.pf $DBALARM $DBSWARM GR
fi
