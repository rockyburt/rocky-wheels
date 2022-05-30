ARG PYTHON_EXACT_VERSION
FROM public.ecr.aws/docker/library/python:${PYTHON_EXACT_VERSION}-slim-bullseye

COPY . /app/src
RUN python3 -m venv /app/.venv

CMD ["/app/.venv/bin/python3", "/app/src/app.py"]
