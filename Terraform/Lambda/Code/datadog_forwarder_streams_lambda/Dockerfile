FROM public.ecr.aws/lambda/python:3.12

ENV PYTHONPATH="${LAMBDA_TASK_ROOT}"

ENV PYTHONUNBUFFERED=1

COPY requirements.txt ${LAMBDA_TASK_ROOT}/

RUN pip install --no-cache-dir -r requirements.txt

COPY datadog_forwarder_streams.py ${LAMBDA_TASK_ROOT}/

CMD ["datadog_forwarder_streams.lambda_handler"]