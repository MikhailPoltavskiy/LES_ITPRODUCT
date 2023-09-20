FROM dart:3.0.5-sdk

WORKDIR /app

ADD . /app/
RUN dart pub get
RUN dart pub global activate conduit 4.4.0
# RUN dart pub run conduit db generate
# RUN dart pub run conduit db validate
# RUN dart pub run conduit db upgrade
EXPOSE 6200

ENTRYPOINT [ "dart", "pub", "run", "conduit:conduit", "serve", "--port", "6200" ]