ARG DISTRIBUTION

FROM debian:${DISTRIBUTION}-slim

ENV CODE="code"
ENV SERVER="smart"
ENV HEALTHCHECK=""
ENV BEARER=""
ENV NETWORK="on"
ENV PROTOCOL="lightway_udp"
ENV CIPHER="chacha20"

ENV SOCKS="off"
ENV SOCKS_LOGS_LEVEL="warn"
ENV SOCKS_AUTH=""
ENV SOCKS_IP="0.0.0.0"
ENV SOCKS_PORT="1080"
ENV SOCKS_WORKERS="4"

ARG NUM
ARG PLATFORM
ARG TARGETPLATFORM

COPY files/ /expressvpn/

RUN apt update && apt install -y --no-install-recommends \
    expect curl ca-certificates iproute2 wget jq iptables iputils-ping net-tools build-essential git

RUN git clone --recursive https://github.com/heiher/hev-socks5-server && cd hev-socks5-server && make && \
    cp /hev-socks5-server/bin/hev-socks5-server /usr/local/bin/hev-socks5-server && \
    rm -rf /hev-socks5-server

RUN if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
    dpkg --add-architecture armhf \
    && apt update && apt install -y --no-install-recommends \
    libc6:armhf libstdc++6:armhf patchelf \
    && ln -sf /usr/lib/arm-linux-gnueabihf/ld-linux-armhf.so.3  /lib/ld-linux-armhf.so.3 \
    && ln -sf /usr/lib/arm-linux-gnueabihf /lib/arm-linux-gnueabihf; \
    fi

RUN wget -q https://www.expressvpn.works/clients/linux/expressvpn_${NUM}-1_${PLATFORM}.deb -O /expressvpn/expressvpn_${NUM}-1_${PLATFORM}.deb \
    && dpkg -i /expressvpn/expressvpn_${NUM}-1_${PLATFORM}.deb \
    && rm -rf /expressvpn/*.deb

RUN if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
    patchelf --set-interpreter /lib/ld-linux-armhf.so.3 /usr/bin/expressvpn \
    && patchelf --set-interpreter /lib/ld-linux-armhf.so.3 /usr/bin/expressvpn-browser-helper; \
    fi

RUN apt purge --autoremove -y wget build-essential git \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/log/*.log

HEALTHCHECK --start-period=30s --timeout=5s --interval=2m --retries=3 CMD bash /expressvpn/healthcheck.sh

ENTRYPOINT ["/bin/bash", "/expressvpn/start.sh"]
