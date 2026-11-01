FROM python:3.12-slim
RUN --mount=type=cache,target=/root/.cache/pip \
    for i in 1 2 3 4 5 6 7 8; do \
      pip install --timeout 120 --retries 10 cartography==0.139.0 && exit 0; \
      echo "pip attempt $i failed, retrying"; sleep 5; \
    done; exit 1
ENTRYPOINT ["cartography"]
