FROM python:3.14-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY ./worker.py /app/main.py

RUN apk add --no-cache curl && pip install --no-cache-dir boto3 && rm -rf /root/.cache/

RUN adduser -D --disabled-password --gecos '' app-user
USER app-user

CMD ["python", "/app/main.py"]