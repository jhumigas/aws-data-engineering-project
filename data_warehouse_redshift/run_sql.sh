#!/usr/bin/env bash
# Run SQL against Redshift through the Data API and wait for each statement to finish.
# Fails fast with the Redshift error message, so setup problems are not silently ignored.
#
# Usage: run_sql.sh <cluster-id> <database> <db-user> <region> (--sql "<statement>" | <file.sql>...)
set -euo pipefail

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 <cluster-id> <database> <db-user> <region> (--sql \"<statement>\" | <file.sql>...)" >&2
  exit 2
fi

cluster="$1" database="$2" db_user="$3" region="$4"
shift 4

run_statement() {
  local label="$1" sql="$2" id status
  id=$(aws redshift-data execute-statement \
    --cluster-identifier "$cluster" --database "$database" --db-user "$db_user" \
    --region "$region" --sql "$sql" --query Id --output text)

  while true; do
    status=$(aws redshift-data describe-statement --id "$id" --region "$region" --query Status --output text)
    case "$status" in
      FINISHED)
        echo "OK      $label"
        return 0
        ;;
      FAILED | ABORTED)
        echo "$status  $label" >&2
        aws redshift-data describe-statement --id "$id" --region "$region" --query Error --output text >&2
        return 1
        ;;
      *) sleep 2 ;;
    esac
  done
}

if [ "$1" = "--sql" ]; then
  run_statement "$2" "$2"
else
  for file in "$@"; do
    run_statement "$file" "$(cat "$file")"
  done
fi
