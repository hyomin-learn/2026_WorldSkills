FROM tarampampam/curl:8.6.0 AS curl-source

FROM alpine:latest AS compressor
RUN apk add --no-cache upx binutils

COPY --chmod=755 ./book /bin/book
RUN strip -s /bin/book || true
RUN upx --best --lzma /bin/book

FROM cgr.dev/chainguard/static:latest
WORKDIR /app

ENV PATH="/usr/bin"

COPY --from=curl-source --chmod=755 /bin/curl /usr/bin/curl
COPY --from=curl-source /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=compressor --chmod=755 --chown=65532:65532 /bin/book /app/book

USER 65532

ENTRYPOINT ["/app/book"]