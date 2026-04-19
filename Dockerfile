# syntax=docker/dockerfile:1.7

# ---------- Build stage ----------
FROM alpine:3.21 AS builder

# Pinned versions. Override with --build-arg when needed.
# Latest builds: https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/
ARG FXSERVER_VER=25770-8ddccd4e4dfd6a760ce18651656463f961cc4761
# cfx-server-data is archived; tarball of master is stable & still linked by official docs.
ARG DATA_REF=master

RUN apk add --no-cache ca-certificates curl tar xz

WORKDIR /output

# Fetch FXServer artifact (same binary for FiveM and RedM)
RUN curl -fsSL "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${FXSERVER_VER}/fx.tar.xz" \
    | tar -xJ --strip-components=1 \
      --exclude='alpine/dev' --exclude='alpine/proc' \
      --exclude='alpine/run' --exclude='alpine/sys'

# Fetch default server resources (still the canonical source per Cfx.re docs)
RUN mkdir -p /output/opt/cfx-server-data \
 && curl -fsSL "https://codeload.github.com/citizenfx/cfx-server-data/tar.gz/${DATA_REF}" \
    | tar -xz --strip-components=1 -C /output/opt/cfx-server-data

# ---------- Runtime stage ----------
FROM alpine:3.21

ARG FXSERVER_VER
ARG DATA_REF

LABEL org.opencontainers.image.title="fxserver" \
      org.opencontainers.image.description="Cfx.re FXServer for FiveM/RedM (switchable via GAME env)" \
      org.opencontainers.image.source="https://github.com/citizenfx/fivem" \
      org.opencontainers.image.url="https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/" \
      io.cfx.fxserver.version="${FXSERVER_VER}" \
      io.cfx.server_data.ref="${DATA_REF}"

# tini is required: FXServer expects a proper init + TTY (see spritsail/fivem issue #3)
RUN apk add --no-cache tini ca-certificates bash

COPY --from=builder /output/ /
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Config/resources live here (user-mounted volume)
WORKDIR /config
VOLUME ["/config"]

# 30120 = game port (TCP+UDP). 40120 = txAdmin (optional, only exposed if user enables txAdmin).
EXPOSE 30120/tcp 30120/udp 40120/tcp

# stdin_open + tty required by FXServer; keep ENTRYPOINT through tini to reap zombies.
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD []
