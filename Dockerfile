# Changed: added a build container
FROM alpine:3.18 as build

ENV VERNEMQ_VERSION="1.13.0"
ENV VERNEMQ_PULL_REQUEST="2221"
# Release 1.13.0
ENV VERNEMQ_DOCKER_VERSION="1055f9d3a465242a9969cd8401050aa52ac68121"

RUN \
  apk add \
    git \
    alpine-sdk \
    erlang-dev \
    snappy-dev \
    bsd-compat-headers \
    openssl-dev \
    tzdata

RUN git clone --depth 1 --branch ${VERNEMQ_VERSION} \
      https://github.com/vernemq/vernemq.git \
      /usr/src/vernemq

RUN cd /usr/src/vernemq && \
    git fetch origin pull/${VERNEMQ_PULL_REQUEST}/head:pull/${VERNEMQ_PULL_REQUEST} && \
    git switch pull/${VERNEMQ_PULL_REQUEST}

RUN cd /usr/src/vernemq && \
    make rel && \
    mv _build/default/rel/vernemq /vernemq

# Changed: The following line have been moved here (saves 1 layer in the image)
RUN wget -O /vernemq/etc/vm.args https://github.com/vernemq/docker-vernemq/raw/${VERNEMQ_DOCKER_VERSION}/files/vm.args && \
    wget -O /vernemq/bin/vernemq.sh https://github.com/vernemq/docker-vernemq/raw/${VERNEMQ_DOCKER_VERSION}/bin/vernemq.sh && \
    wget -O /vernemq/bin/rand_cluster_node.escript https://github.com/vernemq/docker-vernemq/raw/${VERNEMQ_DOCKER_VERSION}/bin/rand_cluster_node.escript

RUN chown -R 10000:10000 /vernemq
RUN chmod 0755 /vernemq/bin/vernemq.sh

FROM alpine:3.18

# Changed: added tzdate
RUN apk --no-cache --update --available upgrade && \
    apk add --no-cache ncurses-libs openssl libstdc++ jq curl bash snappy-dev nano tzdata && \
    addgroup --gid 10000 vernemq && \
    adduser --uid 10000 -H -D -G vernemq -h /vernemq vernemq && \
    install -d -o vernemq -g vernemq /vernemq

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:$PATH" \
    VERNEMQ_VERSION="1.13.0-pr-${VERNEMQ_PULL_REQUEST}"
WORKDIR /vernemq

# Changed: removed COPY commands, replaced by CURL downloads above

# Changed: The following line was added to the original Dockerfile.alpine
COPY --chown=10000:10000 --from=build /vernemq /vernemq

# Changed: The following lines have been modified (download removed, some ln -s added)
RUN ln -s /vernemq/etc /etc/vernemq && \
    ln -s /vernemq/data /var/lib/vernemq && \
    ln -s /vernemq/log /var/log/vernemq

# Ports
# 1883  MQTT
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Health, API, Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 1883 8883 8080 44053 4369 8888 \
       9100 9101 9102 9103 9104 9105 9106 9107 9108 9109


VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

USER vernemq

# Changed: use the path to the script here rather than a symlink
CMD ["/vernemq/bin/vernemq.sh"]
