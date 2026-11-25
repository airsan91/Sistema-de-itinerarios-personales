"""Declara la misma topologia que notification-bridge (que no se despliega en
el plan gratis). Sin una cola enlazada, el OutboxRelay publica con
`mandatory=True`, recibe "unroutable" y reintenta cada ciclo sin fin, lo que
agotaria la cuota mensual de mensajes de CloudAMQP."""
import os

import pika

params = pika.URLParameters(os.environ["RABBITMQ_URL"])
params.socket_timeout = 10
connection = pika.BlockingConnection(params)
ch = connection.channel()

exchange = os.getenv("RABBITMQ_EXCHANGE", "itinerary.events")
queue = os.getenv("NOTIFICATION_QUEUE", "itinerary.notifications")
dlx = "itinerary.notifications.dlx"
dead_queue = "itinerary.notifications.dead"

ch.exchange_declare(exchange=dlx, exchange_type="fanout", durable=True)
ch.queue_declare(queue=dead_queue, durable=True)
ch.queue_bind(queue=dead_queue, exchange=dlx)
ch.exchange_declare(exchange=exchange, exchange_type="topic", durable=True)
ch.queue_declare(queue=queue, durable=True, arguments={"x-dead-letter-exchange": dlx})
ch.queue_bind(queue=queue, exchange=exchange, routing_key="itinerary.created.v1")
connection.close()
print("[start] cola declarada en RabbitMQ", flush=True)
