FROM gitea.trastinfo.ru/sailor/pyhton:0.1
WORKDIR /home/ubadmin/mkdocks
COPY ./requirements.txt .
RUN apk add --update --no-cache --virtual .build-deps gcc musl-dev &&\
    apk add --no-cache git ca-certificates curl &&\
    pip install --no-cache-dir --requirement ./requirements.txt &&\
    apk del .build-deps &&\
    rm ./requirements.txt
WORKDIR /mkdocs
COPY mkdocs.yml /mkdocs/mkdocs.yml
COPY docs/* /mkdocs/docs/
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]








