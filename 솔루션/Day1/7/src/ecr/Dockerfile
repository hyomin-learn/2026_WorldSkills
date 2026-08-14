FROM alpine:3.20

WORKDIR /app
COPY --chown=appuser:appgroup --chmod=755 ./book /app/main

RUN apk add --no-cache \
    libc6-compat \
    libstdc++ \
    libgcc \
    ca-certificates \
    tzdata && \
    cp /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
    echo "Asia/Seoul" > /etc/timezone && \
    addgroup -S appgroup && \
    adduser -S appuser -G appgroup

ENV TZ=Asia/Seoul

USER appuser
EXPOSE 8080

CMD ["/app/main"]