FROM python:3.8
COPY build.sh /build.sh
RUN apt-get update && apt-get install -y jq
RUN chmod +x /build.sh
WORKDIR /
ENTRYPOINT ["/build.sh"]
