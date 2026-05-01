FROM racket/racket:9.1

RUN groupadd -g 1000 appuser && \
    useradd -m -u 1000 -g appuser -s /bin/bash appuser

RUN mkdir /app && chown 1000:1000 /app

WORKDIR /app

USER 1000

RUN raco pkg install --auto markdown web-server

COPY wiki.rkt /app/wiki.rkt

EXPOSE 8889

CMD ["racket", "wiki.rkt"]
