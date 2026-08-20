FROM tarampampam/curl:8.6.0 AS curl-source
FROM alpine:latest AS compressor
RUN apk add --no-cache upx binutils
COPY --chmod=755 ./product /bin/product
RUN strip -s /bin/product || true
RUN upx --best --lzma /bin/product
FROM cgr.dev/chainguard/glibc-dynamic:latest
WORKDIR /app
ENV PATH="/usr/bin"
COPY --from=curl-source --chmod=755 /bin/curl /usr/bin/curl
COPY --from=curl-source /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=compressor --chmod=755 --chown=65532:65532 /bin/product /app/product
USER 65532
ENTRYPOINT ["/app/product"]