# Despliegue en Render (plan gratis)

| Componente | En Render | Plan |
|---|---|---|
| frontend Angular | `itinerarios-web` (static site) | gratis |
| api-gateway + airport-service + itinerary-service | `itinerarios-api` (un contenedor Docker) | gratis |
| PostgreSQL | `itinerarios-db` | gratis, expira a los 30 días |
| Redis | `itinerarios-redis` (Key Value) | gratis, solo memoria |
| RabbitMQ | CloudAMQP (externo, plan gratis) | gratis |
| notification-bridge, LocalStack, Vault, Jaeger, Prometheus, Grafana, Toxiproxy | no se despliegan | siguen en docker-compose |

Los tres servicios comparten contenedor porque los servicios web gratis de
Render no reciben tráfico por la red privada, y el gRPC entre
itinerary-service y airport-service lo necesita. Siguen siendo tres procesos
independientes y gRPC funciona por `127.0.0.1`.

## Pasos

1. **RabbitMQ.** En cloudamqp.com crea una instancia gratis de RabbitMQ y
   copia su **AMQP URL** (`amqps://...`).
2. **Código.** Sube estos cambios a la rama `develope`.
3. **Render.** New > Blueprint, conecta el repositorio y elige la rama
   `develope`. Render detecta `render.yaml`.
4. **Variables.** Render pide `DEMO_PASSWORD` (la contraseña de login) y
   `RABBITMQ_URL` (la del paso 1). Las demás se llenan solas.
5. Pulsa **Apply** y espera a que todo quede en verde.

## Verificación

- `https://<url-de-itinerarios-api>/health` responde `{"status":"ok",...}`.
- En la web: el mapa carga, el login con `viajero` funciona y se puede crear
  un itinerario.
- En CloudAMQP, la cola `itinerary.notifications` suma un mensaje por cada
  itinerario creado.

## Problemas comunes

| Síntoma | Causa y solución |
|---|---|
| La primera petición tarda 1 minuto o más | El API se duerme tras 15 min sin tráfico. Abre `/health` antes de una demo. |
| Falla el build de la web en el primer despliegue | `API_BASE_URL` vacía: ponla a mano en Environment con la URL de `itinerarios-api` y vuelve a desplegar. |
| La web llama a `:8000` | Se compiló sin `API_BASE_URL`: mismo arreglo. |
| `Database not reachable` en los logs | La base gratis expiró: crea otra y actualiza las variables `ITINERARY_DB_*`. Las migraciones corren solas. |
| `no se pudo declarar la cola` | `RABBITMQ_URL` incorrecta. |
