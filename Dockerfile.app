ARG PYTHON_EXACT_VERSION
FROM public.ecr.aws/docker/library/python:${PYTHON_EXACT_VERSION}-slim-bullseye
CMD ["/app/bin/python", "/app/src/app.py"]
