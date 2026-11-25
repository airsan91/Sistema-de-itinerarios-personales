#!/bin/bash
# Arranca los tres servicios en un solo contenedor. El gateway (unico puerto
# publico, $PORT) arranca al final, cuando los otros dos ya responden: asi
# Render no enruta trafico a medio arrancar. Si un proceso muere, el
# contenedor termina y Render lo reinicia.
set -euo pipefail

export AIRPORT_HTTP_PORT=8001 AIRPORT_GRPC_PORT=50051 ITINERARY_HTTP_PORT=8002
export AIRPORT_SERVICE_GRPC_URL=127.0.0.1:50051
export AIRPORT_SERVICE_HTTP_URL=http://127.0.0.1:8001
export AIRPORT_SERVICE_URL=http://127.0.0.1:8001
export ITINERARY_SERVICE_URL=http://127.0.0.1:8002
export GATEWAY_HTTP_PORT="${PORT:-10000}"

trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
trap 'exit 143' TERM INT

(cd /srv/airport && PATH="/venv/airport/bin:$PATH" exec python -m app.main) &
airport_pid=$!
(cd /srv/itinerary && PATH="/venv/itinerary/bin:$PATH" exec ./docker-entrypoint.sh) &
itinerary_pid=$!

# Crea la cola en RabbitMQ antes de que se publique el primer evento. Si
# falla no detiene el arranque: los eventos quedan pendientes en el outbox.
if [ -n "${RABBITMQ_URL:-}" ]; then
  /venv/itinerary/bin/python /srv/declare_queue.py \
    || echo "[start] aviso: no se pudo declarar la cola en RabbitMQ"
fi

wait_for() {
  local name=$1 pid=$2 url=$3
  for _ in $(seq 1 150); do
    if python -c "import urllib.request as u; u.urlopen('$url', timeout=3)" 2>/dev/null; then
      echo "[start] $name listo"
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "[start] $name murio durante el arranque"
      exit 1
    fi
    sleep 2
  done
  echo "[start] $name no respondio a tiempo"
  exit 1
}
wait_for airport-service "$airport_pid" http://127.0.0.1:8001/health
wait_for itinerary-service "$itinerary_pid" http://127.0.0.1:8002/health

(cd /srv/gateway && PATH="/venv/gateway/bin:$PATH" exec python -m app.main) &

wait -n || true
echo "[start] un proceso termino; se detiene el contenedor"
exit 1
