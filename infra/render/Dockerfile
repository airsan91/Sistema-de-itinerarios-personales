# Imagen para el plan gratis de Render (ver infra/render/README.md).
#
# Un servicio web gratis de Render no puede recibir trafico por la red
# privada, asi que airport-service no podria exponer gRPC a
# itinerary-service si fueran servicios separados. Aqui los tres procesos
# corren en un mismo contenedor y se hablan por 127.0.0.1; solo el API
# Gateway queda publico. docker-compose.yml y k8s no usan esta imagen.
#
# Build context = raiz del repo. Un virtualenv por servicio, porque sus
# requirements se resuelven por separado en los Dockerfile originales.
FROM python:3.11-slim AS build

COPY libs/common /src/libs/common
COPY proto /src/proto

# --- airport-service ---
COPY services/airport-service/requirements.txt /src/airport.txt
RUN python -m venv /venv/airport \
    && /venv/airport/bin/pip install --no-cache-dir -r /src/airport.txt \
    && /venv/airport/bin/pip install --no-cache-dir /src/libs/common
COPY services/airport-service/app /srv/airport/app
RUN cd /srv/airport \
    && /venv/airport/bin/python -m grpc_tools.protoc -I/src/proto \
         --python_out=app/grpc_server --grpc_python_out=app/grpc_server \
         /src/proto/airport.proto \
    && sed -i 's/^import airport_pb2/from . import airport_pb2/' app/grpc_server/airport_pb2_grpc.py

# --- itinerary-service ---
COPY services/itinerary-service/requirements.txt /src/itinerary.txt
RUN python -m venv /venv/itinerary \
    && /venv/itinerary/bin/pip install --no-cache-dir -r /src/itinerary.txt \
    && /venv/itinerary/bin/pip install --no-cache-dir /src/libs/common
COPY services/itinerary-service/app /srv/itinerary/app
COPY services/itinerary-service/alembic /srv/itinerary/alembic
COPY services/itinerary-service/alembic.ini services/itinerary-service/docker-entrypoint.sh /srv/itinerary/
RUN cd /srv/itinerary \
    && /venv/itinerary/bin/python -m grpc_tools.protoc -I/src/proto \
         --python_out=app/infrastructure/grpc_client --grpc_python_out=app/infrastructure/grpc_client \
         /src/proto/airport.proto \
    && sed -i 's/^import airport_pb2/from . import airport_pb2/' app/infrastructure/grpc_client/airport_pb2_grpc.py

# --- api-gateway ---
COPY services/api-gateway/requirements.txt /src/gateway.txt
RUN python -m venv /venv/gateway \
    && /venv/gateway/bin/pip install --no-cache-dir -r /src/gateway.txt \
    && /venv/gateway/bin/pip install --no-cache-dir /src/libs/common
COPY services/api-gateway/app /srv/gateway/app

# ------------------------------------------------------------------------
FROM python:3.11-slim
COPY --from=build /venv /venv
COPY --from=build /srv /srv
COPY infra/render/start.sh infra/render/declare_queue.py /srv/
RUN sed -i 's/\r$//' /srv/start.sh /srv/itinerary/docker-entrypoint.sh \
    && chmod +x /srv/start.sh /srv/itinerary/docker-entrypoint.sh

ENV PYTHONUNBUFFERED=1 MALLOC_ARENA_MAX=2
EXPOSE 10000
CMD ["bash", "/srv/start.sh"]
