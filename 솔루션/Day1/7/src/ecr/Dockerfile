FROM alpine:3.20

WORKDIR /app
COPY --chown=appuser:appgroup --chmod=755 ./book /app/main
RUN apk add --no-cache libc6-compat libstdc++ libgcc ca-certificates tzdata && \
    addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
EXPOSE 8080

CMD ["/app/main"]