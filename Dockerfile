# Build BaseX docker image 
ARG JDK_IMAGE=eclipse-temurin:17-jre
ARG BASEX_VER=https://files.basex.org/releases/12.0/BaseX120.zip
ARG SAXON_VER=https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/12.8/Saxon-HE-12.8.jar
FROM $JDK_IMAGE  AS builder
ARG BASEX_VER
ARG SAXON_VER
RUN echo 'using Basex: ' "$BASEX_VER"
RUN apt-get update && apt-get install -y  unzip wget && \
    cd /srv && wget "$BASEX_VER" && unzip *.zip && rm *.zip
RUN cd /srv && wget "$SAXON_VER"


# Main image
FROM $JDK_IMAGE AS deploy
ARG JDK_IMAGE
ARG BASEX_VER

COPY --from=builder  /srv/ /srv

COPY basex/.basex /srv/basex/
COPY basex/custom/* /srv/basex/lib/custom/
COPY --from=builder /srv/Saxon-HE-12.8.jar /srv/basex/lib/custom/Saxon-HE-12.8.jar
COPY data/users.xml /srv/basex/data/users.xml
COPY repo/it /srv/basex/repo/it
COPY restxq/event.xq /srv/basex/webapp/event.xq

RUN chown -R 1000:1000 /srv/basex
RUN ls -R /srv/basex/data

# Switch to 'basex' user
USER 1000

ENV PATH=$PATH:/srv/basex/bin
# JVM options e.g "-Xmx2048m "
ENV BASEX_JVM=" -Xmx6g"

# 1984/tcp: API
# 8080/tcp: HTTP
# 8081/tcp: HTTP stop
EXPOSE 1984 8080 8081

# no VOLUMEs defined
WORKDIR /srv

# Run BaseX HTTP server by default
CMD ["/srv/basex/bin/basexhttp"]

