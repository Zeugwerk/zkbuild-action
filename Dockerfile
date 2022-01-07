FROM python:3.8
COPY build.sh /build.sh
RUN chmod +x /build.sh
WORKDIR /
ENTRYPOINT ["/build.sh"]
