#!/bin/bash

# Gibbon, Flexible & Open School System
# Copyright (C) 2010, Ross Parker
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

#
# Description
# -----------
# This script is for running tests locally with
# mariadb setup, provided by docker and docker-compose.
#
# Dependencies
# ------------
# Depends on the following command line tools:
# - docker
# - docker-compose
# - php
# - composer
#

# use dirname and basename to simulate
# function of the realpath util, if it
# does not exist in the current system.
if [ "" == "$(which realpath)" ]; then
    function realpath {
        path=`eval echo "$1"`
        folder=$(dirname "$path")
        echo $(cd "$folder"; pwd)/$(basename "$path"); 
    }
fi

# make sure that the current user has the
# permission to the folder path passed in
# as parameter.
function imustown {
    if [ "$(stat -c '%U' $1)" != "$(whoami)" ]; then
        sudo chown "$(whoami)"."$(groups | cut -d' ' -f 1)" $1
    fi
}

# variables to use
VAR=$(realpath "$(dirname $(dirname $0))/var")
DOCKER_COMPOSE=$(which docker-compose)
COMPOSER=$(which composer || which composer.phar)

# composer environment variables
export COMPOSER_HOME="$VAR/.composer"
export PATH="$COMPOSER_HOME/vendor/bin:$PATH"

# environment variables for codeception tests
export TEST_ENV="codeception"
export CI_PLATFORM="docker_compose"

# environment variables for docker compose
# Note: must be consistant with variables defined in
#       `tests/config/envs/docker_compose.yml`
export MYSQL_ROOT_PASSWORD="example"
export MYSQL_DATABASE="gibbonedu"
export MYSQL_USER="gibbonedu"
export MYSQL_PASSWORD="gibbonexample"

# environment variables for the tests
export ABSOLUTE_URL="http://127.0.0.1:8888"
export DB_HOST="127.0.0.1:3306"
export DB_NAME="$MYSQL_DATABASE"
export DB_USERNAME="$MYSQL_USER"
export DB_PASSWORD="$MYSQL_PASSWORD"

# check the testing environment
if [ "" == "$COMPOSER" ]; then
    echo "Unable to find composer or composer.phar in the system PATH."
    exit 1
fi
if [ "" == "$DOCKER_COMPOSE" ]; then
    echo "Unable to find docker-compose in the system PATH."
    exit 1
fi
if [ ! -d "$VAR" ]; then
    mkdir -p "$VAR"
else
    imustown "$VAR"
fi
if [ ! -d "$COMPOSER_HOME" ]; then
    mkdir -p "$COMPOSER_HOME"
    echo -e "{}\n" > "$COMPOSER_HOME/composer.json"
fi

echo
echo "Check docker-compose use with current user"
echo "------------------------------------------"
if ! $DOCKER_COMPOSE ps ; then
    # prepend sudo to docker compose command
    echo "Cannot use with current user directly."
    echo "Will use with sudo command."
    DOCKER_COMPOSE="sudo $DOCKER_COMPOSE"
else
    echo "success"
fi

# setup required service with docker-compose
# then fix the var folder permission.
echo
echo "Start mariadb/mysql container and bind to localhost:3306"
echo "--------------------------------------------------------"
$DOCKER_COMPOSE up -d
imustown $VAR

# setup testing php server
if ! lsof -PiTCP -sTCP:LISTEN | grep 'localhost:8888' > /dev/null; then
    echo
    echo "localhost:8888 is not listening. start php test server"
    echo "------------------------------------------------------"
    php -S 127.0.0.1:8888 -t . >/dev/null 2>&1 &
fi

# install codeception
echo
echo "Install testing tools (codecept and phpunit)"
echo "--------------------------------------------"
$COMPOSER --ansi global require "codeception/codeception" "2.5.*@dev" --no-progress

# finally run the tests
echo
echo "Tests"
echo "-----"
$COMPOSER test:codecept || exit 1
