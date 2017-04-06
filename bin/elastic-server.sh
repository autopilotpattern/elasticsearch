#!/bin/sh -xe
manage.sh onStart #|| exit $?
if [[ $? != 0 ]]; then
    exit $?
fi
exec /usr/share/elasticsearch/bin/es-docker $*
