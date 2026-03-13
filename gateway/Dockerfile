FROM dart:3.10

WORKDIR /app

COPY pubspec.yaml ./
RUN dart pub get --no-precompile

COPY . .
RUN dart pub get --offline --no-precompile

ENV RSS_GATEWAY_HOST=0.0.0.0
ENV PORT=8787

EXPOSE 8787

CMD ["sh", "-c", "dart run bin/rss_gateway.dart --host=${RSS_GATEWAY_HOST:-0.0.0.0} --port=${PORT:-8787}"]
