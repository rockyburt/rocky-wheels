ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_TAG}

CMD ${VENV}/bin/python3 /app/src/app.py
