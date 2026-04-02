FROM dart:stable AS deps
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

FROM dart:stable AS dev
WORKDIR /app
COPY --from=deps /root/.pub-cache /root/.pub-cache
COPY pubspec.* ./
RUN ls -la /app/
RUN dart pub get --offline
COPY . .

FROM dart:stable AS builder
WORKDIR /app
COPY --from=deps /root/.pub-cache /root/.pub-cache
COPY pubspec.* ./
RUN dart pub get --offline
COPY . .
RUN ls -la /app/
RUN dart compile exe bin/server.dart -o bin/server --verbosity=warning

FROM gcr.io/distroless/cc-debian12 AS production
COPY --from=builder /runtime/ /
COPY --from=builder /app/bin/server /app/bin/server
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/bin/server"]