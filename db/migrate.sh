#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
docker run --rm \
  -v "${SCRIPT_DIR}/migration":/flyway/sql \
  flyway/flyway \
  -url="jdbc:mysql://${1}:3306/dev?executeInTransaction=false" \
  -user="${2}" \
  -password="${FLYWAY_PASSWORD}" \
  ${3:-migrate}
