ARG PYTHON_EXACT_VERSION
FROM public.ecr.aws/docker/library/python:${PYTHON_EXACT_VERSION}-slim-bullseye

ARG VENV

COPY . /app/src
RUN python3 -m venv ${VENV}

ENV VENV ${VENV}

CMD ${VENV}/bin/python3 /app/src/app.py
