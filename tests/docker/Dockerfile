ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        adduser \
        ca-certificates \
        git \
        sudo \
    && rm -rf /var/lib/apt/lists/* \
    && adduser --disabled-password --gecos "" jhondoe \
    && adduser jhondoe sudo \
    && printf 'jhondoe ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/jhondoe \
    && chmod 0440 /etc/sudoers.d/jhondoe

COPY --chown=jhondoe:jhondoe . /home/jhondoe/dotfiles

USER jhondoe
ENV HOME=/home/jhondoe
ENV TERM=xterm-256color
WORKDIR /home/jhondoe/dotfiles

CMD ["bash", "tests/docker/run-setup-test.sh"]
