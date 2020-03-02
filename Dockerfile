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
RUN adduser --system --no-create-home stenographer && \
    addgroup --system stenographer && \
    mkdir -p /var/lib/stenographer && \
    chown stenographer:stenographer /var/lib/stenographer && \
    apt update && \
    apt install -y --no-install-recommends libleveldb1v5 libsnappy1v5 libaio1
COPY --from=build /opt/stenographer/bin /opt/stenographer/bin
COPY --from=build /etc/stenographer /etc/stenographer

USER stenographer
ENTRYPOINT [ "/opt/stenographer/bin/stenographer", "-syslog=false" ]
