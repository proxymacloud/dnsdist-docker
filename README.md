# dnsdist-docker

Docker dnsdist image with DNS over HTTPS and DNS over TLS support.

Platforms: AMD64,ARM64

## docker compose 

```
version: '3'
services:
  dnsdist:
    hostname: dnsdist
    image: darkstreet00/dnsdist-docker:latest
    restart: unless-stopped
    tty: true
    stdin_open: true
    command: ["--disable-syslog", "--uid", "dnsdist", "--gid", "dnsdist", "--verbose"]
    volumes:
      - ./dnsdist.conf:/etc/dnsdist/dnsdist.conf:ro
    ports:
      - 8053:8053 # DNS over HTTP(S)
      - 853:853 # DNS over TLS
      - 53:53 # unencrypted DNS TCP
      - 53:53/udp # unencrypted DNS UDP
```
