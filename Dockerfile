FROM ubuntu:18.04 AS build
COPY 99_golang_from_focal /etc/apt/preferences.d/
COPY focal.list /etc/apt/sources.list.d/
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
    ( ./install.sh || true ) && \
    sed -i -e 's/curl /curl -k /' /opt/stenographer/bin/stenocurl

FROM ubuntu:18.04
COPY --from=build /opt/stenographer/bin /opt/stenographer/bin
COPY --from=build /etc/stenographer /etc/stenographer
COPY --from=build /stenographer/src/github.com/google/stenographer/stenotype/compile_bpf.sh /opt/stenographer/bin/
COPY entrypoint.sh /opt/stenographer/bin/

RUN adduser --system --no-create-home stenographer && \
    addgroup --system stenographer && \
    mkdir -p /var/lib/stenographer && \
    chown -R stenographer:stenographer /var/lib/stenographer /etc/stenographer && \
    chmod -R a+rwx /var/lib/stenographer /etc/stenographer && \
    chmod a+x /opt/stenographer/bin/* && \
    apt update && \
    apt install -y --no-install-recommends libleveldb1v5 libsnappy1v5 libaio1 \
    jq tcpdump libcap2-bin curl netcat-openbsd sudo && \
    setcap 'cap_net_raw,cap_net_admin,cap_ipc_lock,cap_setuid,cap_setgid+ep' /opt/stenographer/bin/stenotype && \
    rm -rf /var/lib/apt/lists/*

USER stenographer

ENTRYPOINT [ "/opt/stenographer/bin/entrypoint.sh" ]
