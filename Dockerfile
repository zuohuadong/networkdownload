# build image
ARG RUST_VERSION=1.86
FROM docker.io/library/rust:${RUST_VERSION}-slim-bookworm AS build
WORKDIR /app

RUN apt-get update && apt-get install -y \
    cmake git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/hatoo/oha.git

WORKDIR /app/oha

RUN cargo install --path .
RUN strip /usr/local/cargo/bin/oha

# Target image
FROM gcr.io/distroless/cc-debian12

# ARG APPLICATION="oha-docker"
# ARG DESCRIPTION="Lightweight, multi-arch, minimal docker image of Oha, a tiny program that sends some load to a web application and show realtime tui inspired by rakyll/hey"
ARG PACKAGE="zuohuadong/networkdownload"

LABEL name="${PACKAGE}" \
    author="ahmadalsajid@gmail.com" \
    documentation="https://github.com/${PACKAGE}/README.md" \
    description="${DESCRIPTION}" \
    licenses="MIT License" \
    source="https://github.com/${PACKAGE}"

COPY --from=build /usr/local/cargo/bin/oha /bin/oha

#ENTRYPOINT ["/bin/oha"]


ENV th=2
ENV url=http://img.cmvideo.cn/publish/noms/2022/10/14/1O3VIGPVP6HTS.jpg

ENTRYPOINT ["sh", "-c","/bin/oha -n 1000000000000000 -c ${th} ${url} "]
