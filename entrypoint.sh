#!/bin/bash

THREADS=1
INTERFACE=
FILTER=
DISKFREE=10
INDEXBASE=
PACKETSBASE=

set -euo pipefail

usage() {
    echo "Usage: [--threads 1] [--filter <bpf>] [--diskfreee 10] --interface <dev> --indexbase <dir> --packetsbase <dir>" >&2
    exit 1
}

parse_opts() {
    local -r OPTS=$(getopt --options '' --longoptions threads:,interface:,filter:,diskfree:,indexbase:,packetsbase: -n 'entrypoint' -- "$@")

    if [ $? != 0 ]; then
        echo "Failed parsing options." >&2
        exit 1
    fi

    eval set --"$OPTS"

    while true; do
        case "$1" in
        --threads)
            THREADS="$2"
            shift
            shift
            ;;
        --interface)
            INTERFACE="$2"
            shift
            shift
            ;;
        --filter)
            FILTER="$2"
            shift
            shift
            ;;
        --diskfree)
            DISKFREE="$2"
            shift
            shift
            ;;
        --indexbase)
            INDEXBASE="$2"
            shift
            shift
            ;;
        --packetsbase)
            PACKETSBASE="$2"
            shift
            shift
            ;;
        -h | --help)
            usage
            shift
            ;;
        --)
            shift
            break
            ;;
        *) break ;;
        esac
    done
}

create_config() {
    local -r INTERFACE="$1"
    local -r THREADS="$2"
    local -r PACKETSBASE="$3"
    local -r INDEXBASE="$4"
    local -r DISKFREE="$5"
    local -r FILTER="$6"
    local COMPILED_FILTER=

    if [ -n "${FILTER}" ]; then
        COMPILED_FILTER="$(/opt/stenographer/bin/compile_bpf.sh "${INTERFACE}" "${FILTER}")"
        [ -n "${COMPILED_FILTER}" ]
    fi

    local -r JQFILE=$(mktemp)

    cat >"${JQFILE}" <<'EOF'
{
    Threads: [range($threads)] |
        map({PacketsDirectory: "\($packetsbase)/\(.)",
            IndexDirectory: "\($indexbase)/\(.)",
            DiskFreePercentage: $diskfree}),
    StenotypePath: "/opt/stenographer/bin/stenotype",
    Interface: $interface,
    Host: "127.0.0.1",
    Port: 1234,
    Flags: ([ "--seccomp=none", "--uid=root", "--gid=root" ] + $extraflags),
    CertPath: "/etc/stenographer/certs"
}
EOF

    EXTRAFLAGS="[]"

    if [ -n "${COMPILED_FILTER}" ]; then
        EXTRAFLAGS="[\"--filter=${COMPILED_FILTER}\"]"
    fi

    jq --null-input \
        --arg interface "${INTERFACE}" \
        --argjson threads "${THREADS}" \
        --arg packetsbase "${PACKETSBASE}" \
        --arg indexbase "${INDEXBASE}" \
        --arg filter "${FILTER}" \
        --argjson diskfree "${DISKFREE}" \
        --argjson extraflags "${EXTRAFLAGS}" \
        --from-file "${JQFILE}"
}

parse_opts "$@"

if [ -z "${INTERFACE}" ] || [ -z "${PACKETSBASE}" ] || [ -z "${INDEXBASE}" ] || [ "${THREADS}" -le 0 ] || [ "${DISKFREE}" -le 0 ]; then
    usage
fi

create_config "${INTERFACE}" "${THREADS}" "${PACKETSBASE}" "${INDEXBASE}" "${DISKFREE}" "${FILTER}" >/etc/stenographer/config
/opt/stenographer/bin/stenographer -syslog=false -config=/etc/stenographer/config
