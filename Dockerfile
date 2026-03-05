FROM dart:stable AS deps
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

FROM dart:stable AS builder
WORKDIR /app
COPY --from=deps /root/.pub-cache /root/.pub-cache
COPY pubspec.* ./
RUN dart pub get --offline
COPY . .
RUN dart run build_runner build --delete-conflicting-outputs
RUN dart compile exe bin/server.dart -o bin/server --verbosity=warning

FROM scratch AS production
COPY --from=builder /runtime/ /
COPY --from=builder /app/bin/server /app/bin/server
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/bin/server"]