FROM rust:bullseye AS builder

ARG version=0.12.0

RUN apt-get update && apt-get install -y libfontconfig1-dev libgraphite2-dev libharfbuzz-dev libicu-dev zlib1g-dev
RUN cargo install tectonic ${version:+--vers "$version"}

WORKDIR /app
RUN wget 'https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/2.16/binaries/Linux/biber-linux_x86_64.tar.gz'
RUN tar -xvzf biber-linux_x86_64.tar.gz
RUN chmod +x biber
RUN cp biber /usr/bin/biber

COPY builder/*.tex ./
COPY builder/*.bib ./
# first run - keep files for biber
RUN tectonic --keep-intermediates --reruns 0 main.tex
# do the biber
RUN biber main
# one last tectonic run over all files
RUN for f in *.tex; do tectonic $f; done

# use a lightweight debian - no need for whole rust environment
FROM mcr.microsoft.com/vscode/devcontainers/base:bullseye
RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 libgraphite2-3 libharfbuzz0b libicu67 zlib1g libharfbuzz-icu0 libssl1.1 ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/* 

# copy tectonic binary to new image
COPY --from=builder /usr/local/cargo/bin/tectonic /usr/bin/
# reuse tectonic cache from compiling tex files
COPY --from=builder /root/.cache/Tectonic/ /root/.cache/Tectonic/
# copy biber binary to new image
COPY --from=builder /usr/bin/biber /usr/bin/ 

WORKDIR /app