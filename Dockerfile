# Build Stage
FROM alpine:3.16 AS builder

ARG DNSDIST_VERSION

RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk add --no-cache ca-certificates curl jq gnupg build-base \
      boost-dev openssl-dev libsodium-dev lua-dev net-snmp-dev protobuf-dev \
      libedit-dev re2-dev nghttp2-dev h2o-dev h2o abseil-cpp-dev

# Fetch the latest DNSDIST_VERSION if not provided
RUN if [ -z "$DNSDIST_VERSION" ]; then \
      DNSDIST_VERSION=$(curl -sSL 'https://api.github.com/repos/PowerDNS/pdns/tags?per_page=100&page=1' | jq -r '[.[] | select(.name | test("^dnsdist-"))][0].name' | cut -d- -f2); \
    fi && \
    echo "Using DNSDIST_VERSION: $DNSDIST_VERSION"

# Set up GPG keys and fetch DNSDist source code with retry logic
RUN mkdir -v -m 0700 -p /root/.gnupg && \
    for i in {1..5}; do curl -RL -O 'https://dnsdist.org/_static/dnsdist-keyblock.asc' && break || sleep 15; done && \
    gpg --import dnsdist-keyblock.asc && \
    for i in {1..5}; do curl -RL -O "https://downloads.powerdns.com/releases/dnsdist-${DNSDIST_VERSION}.tar.bz2" && break || sleep 15; done && \
    for i in {1..5}; do curl -RL -O "https://downloads.powerdns.com/releases/dnsdist-${DNSDIST_VERSION}.tar.bz2.sig" && break || sleep 15; done && \
    gpg --verify "dnsdist-${DNSDIST_VERSION}.tar.bz2.sig" "dnsdist-${DNSDIST_VERSION}.tar.bz2"

# Extract and build DNSDist
RUN tar -xpf "dnsdist-${DNSDIST_VERSION}.tar.bz2" && \
    cd "dnsdist-${DNSDIST_VERSION}" && \
    ./configure --sysconfdir=/etc/dnsdist --mandir=/usr/share/man \
        --enable-dnscrypt --enable-dns-over-tls --enable-dns-over-https --with-libsodium --with-re2 --with-net-snmp && \
    make -j$(nproc) && \
    make install-strip

# Final Stage
FROM alpine:3.16

RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk add --no-cache ca-certificates curl less \
        openssl libsodium lua5.1 lua5.1-libs net-snmp protobuf \
        libedit re2 h2o mandoc man-pages mandoc-apropos less-doc abseil-cpp && \
    rm -rf /var/cache/apk/*

ENV PAGER less

RUN addgroup -S dnsdist && \
    adduser -S -D -G dnsdist dnsdist

COPY --from=builder /usr/local/bin /usr/local/bin/
COPY --from=builder /usr/local/lib /usr/local/lib/
COPY --from=builder /usr/share/man/man1 /usr/share/man/man1/

RUN /usr/local/bin/dnsdist --version

ENTRYPOINT ["/usr/local/bin/dnsdist"]
CMD ["--help"]
