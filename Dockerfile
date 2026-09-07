FROM mcr.microsoft.com/dotnet/sdk:8.0.421-bookworm-slim AS build

ARG TARGETARCH

ARG PROWLARR_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install --global yarn \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN case "$TARGETARCH" in \
        amd64) rid=linux-musl-x64 ;; \
        arm64) rid=linux-musl-arm64 ;; \
        *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac \
    && PROWLARRVERSION="$PROWLARR_VERSION" ./build.sh --backend --frontend --packages --framework net8.0 --runtime "$rid" \
    && mkdir /image \
    && cp -a "_artifacts/$rid/net8.0/Prowlarr/." /image/ \
    && rm -rf /image/Prowlarr.Update

FROM lscr.io/linuxserver/prowlarr:latest

ARG PACKAGE_VERSION
ARG PACKAGE_AUTHOR

COPY --from=build /image/ /app/prowlarr/bin/

RUN grep -q 'ld-musl' /app/prowlarr/bin/Prowlarr \
    || (echo 'Prowlarr was not built against musl; it cannot exec on Alpine' >&2 && exit 1)

RUN [ -z "$PACKAGE_VERSION" ] || sed -i \
        -e "s|^PackageVersion=.*|PackageVersion=$PACKAGE_VERSION|" \
        -e "s|^PackageAuthor=.*|PackageAuthor=$PACKAGE_AUTHOR|" \
        /app/prowlarr/package_info
