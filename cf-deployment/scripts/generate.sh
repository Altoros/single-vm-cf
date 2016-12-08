#!/bin/bash

set -ef -o pipefail

set -u

root_dir=$(cd "$(dirname "$0")/.." && pwd)

bosh interpolate -o $root_dir/opsfiles/scale-down.yml -o $root_dir/opsfiles/fix_-properties.yml -o $root_dir/opsfiles/add-mysql-broker.yml $root_dir/cf-deployment/cf-deployment.yml > reduced-manifest.yml
$root_dir/scripts/combine-jobs.py reduced-manifest.yml $root_dir/templates/single-vm-cf.yml  > single-vm-cf.yml

rm reduced-manifest.yml
