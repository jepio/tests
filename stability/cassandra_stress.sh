#!/bin/bash
#
# Copyright (c) 2023 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

set -o pipefail

# General env
SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../metrics/lib/common.bash"

IMAGE="docker.io/library/cassandra:latest"
CONTAINER_NAME="${CONTAINER_NAME:-cassandra_test}"
DOCKER_IMAGE="cassandra:latest"
PAYLOAD_ARGS="${PAYLOAD_ARGS:-tail -f /dev/null}"
CMD="cassandra -R"

function main() {
	local cmds=("docker")

	init_env
	check_cmds "${cmds[@]}"
	sudo -E docker pull "${DOCKER_IMAGE}"
	sudo -E docker save -o "${DOCKER_IMAGE}.tar" "${DOCKER_IMAGE}"
	sudo -E ctr i import "${DOCKER_IMAGE}.tar"

	sudo -E ctr run -d --runtime "${CTR_RUNTIME}" "${IMAGE}" "${CONTAINER_NAME}" sh -c "${PAYLOAD_ARGS}"
	sudo -E ctr t exec --exec-id 1 "${CONTAINER_NAME}" sh -c "${CMD}"
	info "Write one million rows"
	local WRITE_CMD="./opt/cassandra/tools/bin/cassandra-stress write n=1000000 -rate threads=50"
	sudo -E ctr t exec --exec-id 2 "${CONTAINER_NAME}" sh -c "${WRITE_CMD}"
	info "Load one row with default schema"
	local CQL_WRITE_CMD="./opt/cassandra/tools/bin/cassandra-stress write n=1 c1=one -mode native cql3 -log file-create_schema.log"
	sudo -E ctr t exec --exec-id 3 "${CONTAINER_NAME}" sh -c "${CQL_WRITE_CMD}"
	info "Run a write workload using CQL"
	local REAL_WRITE_CMD="./opt/cassandra/tools/bin/cassandra-stress write n=1000000 cl=one -mode native cql3 -schema keyspace='keyspace1' -log file=load_1M_rows.log"
	sudo -E ctr t exec --exec-id 4 "${CONTAINER_NAME}" sh -c "${REAL_WRITE_CMD}"

	clean_env_ctr
}

main "$@"
