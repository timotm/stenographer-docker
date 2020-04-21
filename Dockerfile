FROM ubuntu:18.04 AS build
RUN apt update && \
    apt install -y --no-install-recommends libaio-dev libleveldb-dev libsnappy-dev \
    g++ libcap2-bin libseccomp-dev golang git ca-certificates make sudo
RUN apt install -y --no-install-recommends jq openssl
ENV GOPATH=/stenographer
RUN go get github.com/google/stenographer
ENV BINDIR=/opt/stenographer/bin
RUN mkdir -p ${BINDIR} && \
    cd /stenographer/src/github.com/google/stenographer && \
    sed -i -e 's|/path/to|/var/lib/stenographer|' \
    -e 's|/usr/bin/|/opt/stenographer/bin/|' configs/steno.conf && \
    ( ./install.sh || true )

FROM ubuntu:18.04
COPY --from=build /opt/stenographer/bin /opt/stenographer/bin
COPY --from=build /etc/stenographer /etc/stenographer
COPY --from=build /stenographer/src/github.com/google/stenographer/stenotype/compile_bpf.sh /opt/stenographer/bin/
COPY entrypoint.sh /opt/stenographer/bin/

RUN adduser --system --no-create-home stenographer && \
    addgroup --system stenographer && \
    mkdir -p /var/lib/stenographer && \
    chown stenographer:stenographer /var/lib/stenographer && \
    apt update && \
    apt install -y --no-install-recommends libleveldb1v5 libsnappy1v5 libaio1 \
    jq tcpdump libcap2-bin curl netcat-openbsd sudo && \
    setcap 'CAP_NET_RAW+ep CAP_NET_ADMIN+ep CAP_IPC_LOCK+ep' /opt/stenographer/bin/stenotype && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "/opt/stenographer/bin/entrypoint.sh" ]
