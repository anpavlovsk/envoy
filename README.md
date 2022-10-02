# envoy
Envoy's xDS with Active Health Check discovery
## Description ##

![alt text](https://github.com/anpavlovsk/envoy/blob/main/screenshots/envoy.jpg?raw=true) 


### Docker-compose ###
Start containers
````
docker compose up --build -d
````

List containers with their IP's
````
docker inspect -f '{{.Name}}: {{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq) | sort
````
Output
````
/envoy-container_a-1: 172.24.0.2
/envoy-container_b-1: 172.24.0.3
/envoy-container_c-1: 172.24.0.5
/envoy-container_d-1: 172.24.0.4
/envoy-proxy-1: 172.24.0.6
````



Nginx configuration:
````
   upstream backend {
      server 127.0.0.1:10000;
   }

   # This server accepts all traffic to port 80 and passes it to the upstream.
   # Notice that the upstream name and the proxy_pass need to match.

   server {
      listen 80;

      location / {
	resolver 127.0.0.1;
        proxy_pass http://backend;
	proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      }
   }
````

During this task we will test envoy active health check on cluster with two http endpoins.

### Envoy configuration: ###
````
node:
  id: id_1
  cluster: test

dynamic_resources:
  lds_config:
    path: /etc/envoy/lds.yaml
  cds_config:
    path: /etc/envoy/cds.yaml

admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901
````

### Listener Discovery Service (LDS): ###
````
resources:
- "@type": type.googleapis.com/envoy.config.listener.v3.Listener
  name: listener_0
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 10000
  filter_chains:
  - filters:
      name: envoy.filters.network.http_connection_manager
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
        stat_prefix: ingress_http
        http_filters:
        - name: envoy.filters.http.router
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
        route_config:
          name: local_route
          virtual_hosts:
          - name: local_service
            domains:
            - "*"
            routes:
            - match:
                prefix: "/"
              route:
                cluster: example_proxy_cluster

````

### Cluster Discovery Service (CDS) with Health check configuration:: ###
````
resources:
- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: example_proxy_cluster
  type: STATIC
  connect_timeout: 5s
  load_assignment:
    cluster_name: example_proxy_cluster
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            socket_address:
              address: 172.24.0.2
              port_value: 8080
      - endpoint:
          address:
            socket_address:
              address: 172.24.0.3
              port_value: 8080
  health_checks:
  - timeout: 2s
    interval: 1s
    interval_jitter: 1s
    unhealthy_threshold: 3
    healthy_threshold: 3
    tcp_health_check: {}
````

All requests (curl -s http://localhost:80 | grep served) are balancing between endpoints with round robin strategy.

Output
````
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_a
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_b
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_a
````

We have a new claster configuration in file cdsnew.yaml:

````
resources:
- "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
  name: example_proxy_cluster
  type: STATIC
  connect_timeout: 5s
  load_assignment:
    cluster_name: example_proxy_cluster
    endpoints:
    - lb_endpoints:
      - endpoint:
          address:
            socket_address:
              address: 172.24.0.4
              port_value: 8080
      - endpoint:
          address:
            socket_address:
              address: 172.24.0.5
              port_value: 8080
  health_checks:
  - timeout: 2s
    interval: 1s
    interval_jitter: 1s
    unhealthy_threshold: 3
    healthy_threshold: 3
    tcp_health_check: {}
````
Copy new envoy confuguration to proxy container:
````
docker cp /home/admin/envoy/proxy/configs/cdsnew.yaml 56a81e58bcb7:/etc/envoy/cdsnew.yaml
````
Replaces cds.yaml with cdsnew.yaml within the container:
````
docker compose exec proxy mv /etc/envoy/cdsnew.yaml /etc/envoy/cds.yaml
````
NOW All requests (curl -s http://localhost:80 | grep served) are balancing between new endpoints.
````
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_d
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_c
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_d
````


<details>
<summary>Envoy /clusters output:</summary>
<pre>
````
example_proxy_cluster::observability_name::example_proxy_cluster
example_proxy_cluster::default_priority::max_connections::1024
example_proxy_cluster::default_priority::max_pending_requests::1024
example_proxy_cluster::default_priority::max_requests::1024
example_proxy_cluster::default_priority::max_retries::3
example_proxy_cluster::high_priority::max_connections::1024
example_proxy_cluster::high_priority::max_pending_requests::1024
example_proxy_cluster::high_priority::max_requests::1024
example_proxy_cluster::high_priority::max_retries::3
example_proxy_cluster::added_via_api::true
example_proxy_cluster::172.24.0.4:8080::cx_active::1
example_proxy_cluster::172.24.0.4:8080::cx_connect_fail::0
example_proxy_cluster::172.24.0.4:8080::cx_total::1
example_proxy_cluster::172.24.0.4:8080::rq_active::0
example_proxy_cluster::172.24.0.4:8080::rq_error::0
example_proxy_cluster::172.24.0.4:8080::rq_success::2
example_proxy_cluster::172.24.0.4:8080::rq_timeout::0
example_proxy_cluster::172.24.0.4:8080::rq_total::2
example_proxy_cluster::172.24.0.4:8080::hostname::
example_proxy_cluster::172.24.0.4:8080::health_flags::healthy
example_proxy_cluster::172.24.0.4:8080::weight::1
example_proxy_cluster::172.24.0.4:8080::region::
example_proxy_cluster::172.24.0.4:8080::zone::
example_proxy_cluster::172.24.0.4:8080::sub_zone::
example_proxy_cluster::172.24.0.4:8080::canary::false
example_proxy_cluster::172.24.0.4:8080::priority::0
example_proxy_cluster::172.24.0.4:8080::success_rate::-1.0
example_proxy_cluster::172.24.0.4:8080::local_origin_success_rate::-1.0
example_proxy_cluster::172.24.0.5:8080::cx_active::1
example_proxy_cluster::172.24.0.5:8080::cx_connect_fail::0
example_proxy_cluster::172.24.0.5:8080::cx_total::1
example_proxy_cluster::172.24.0.5:8080::rq_active::0
example_proxy_cluster::172.24.0.5:8080::rq_error::0
example_proxy_cluster::172.24.0.5:8080::rq_success::1
example_proxy_cluster::172.24.0.5:8080::rq_timeout::0
example_proxy_cluster::172.24.0.5:8080::rq_total::1
example_proxy_cluster::172.24.0.5:8080::hostname::
example_proxy_cluster::172.24.0.5:8080::health_flags::healthy
example_proxy_cluster::172.24.0.5:8080::weight::1
example_proxy_cluster::172.24.0.5:8080::region::
example_proxy_cluster::172.24.0.5:8080::zone::
example_proxy_cluster::172.24.0.5:8080::sub_zone::
example_proxy_cluster::172.24.0.5:8080::canary::false
example_proxy_cluster::172.24.0.5:8080::priority::0
example_proxy_cluster::172.24.0.5:8080::success_rate::-1.0
example_proxy_cluster::172.24.0.5:8080::local_origin_success_rate::-1.0
````

Notice: we have 2 endpoints (172.24.0.4,172.24.0.5) in cluster example_proxy_cluster and they are healthy (health_flags::healthy)
</pre>
</details>

After we turn off the first endpoint, the envoy starts the procedure of endpoint removal from the cluster after the first unsuccessful HC-request.

This can be seen on the :health_flags::/failed_active_hc/active_hc_timeout for the first endpoint at 172.24.0.4

<details>
<summary>Envoy /clusters output:</summary>
<pre>
````
example_proxy_cluster::observability_name::example_proxy_cluster
example_proxy_cluster::default_priority::max_connections::1024
example_proxy_cluster::default_priority::max_pending_requests::1024
example_proxy_cluster::default_priority::max_requests::1024
example_proxy_cluster::default_priority::max_retries::3
example_proxy_cluster::high_priority::max_connections::1024
example_proxy_cluster::high_priority::max_pending_requests::1024
example_proxy_cluster::high_priority::max_requests::1024
example_proxy_cluster::high_priority::max_retries::3
example_proxy_cluster::added_via_api::true
example_proxy_cluster::172.24.0.4:8080::cx_active::0
example_proxy_cluster::172.24.0.4:8080::cx_connect_fail::1
example_proxy_cluster::172.24.0.4:8080::cx_total::2
example_proxy_cluster::172.24.0.4:8080::rq_active::0
example_proxy_cluster::172.24.0.4:8080::rq_error::1
example_proxy_cluster::172.24.0.4:8080::rq_success::2
example_proxy_cluster::172.24.0.4:8080::rq_timeout::0
example_proxy_cluster::172.24.0.4:8080::rq_total::2
example_proxy_cluster::172.24.0.4:8080::hostname::
example_proxy_cluster::172.24.0.4:8080::health_flags::/failed_active_hc/active_hc_timeout
example_proxy_cluster::172.24.0.4:8080::weight::1
example_proxy_cluster::172.24.0.4:8080::region::
example_proxy_cluster::172.24.0.4:8080::zone::
example_proxy_cluster::172.24.0.4:8080::sub_zone::
example_proxy_cluster::172.24.0.4:8080::canary::false
example_proxy_cluster::172.24.0.4:8080::priority::0
example_proxy_cluster::172.24.0.4:8080::success_rate::-1.0
example_proxy_cluster::172.24.0.4:8080::local_origin_success_rate::-1.0
example_proxy_cluster::172.24.0.5:8080::cx_active::1
example_proxy_cluster::172.24.0.5:8080::cx_connect_fail::0
example_proxy_cluster::172.24.0.5:8080::cx_total::1
example_proxy_cluster::172.24.0.5:8080::rq_active::0
example_proxy_cluster::172.24.0.5:8080::rq_error::0
example_proxy_cluster::172.24.0.5:8080::rq_success::5
example_proxy_cluster::172.24.0.5:8080::rq_timeout::0
example_proxy_cluster::172.24.0.5:8080::rq_total::5
example_proxy_cluster::172.24.0.5:8080::hostname::
example_proxy_cluster::172.24.0.5:8080::health_flags::healthy
example_proxy_cluster::172.24.0.5:8080::weight::1
example_proxy_cluster::172.24.0.5:8080::region::
example_proxy_cluster::172.24.0.5:8080::zone::
example_proxy_cluster::172.24.0.5:8080::sub_zone::
example_proxy_cluster::172.24.0.5:8080::canary::false
example_proxy_cluster::172.24.0.5:8080::priority::0
example_proxy_cluster::172.24.0.5:8080::success_rate::-1.0
example_proxy_cluster::172.24.0.5:8080::local_origin_success_rate::-1.0
````
Notice that only one endpoint 172.24.0.5 is heathy.
</pre>
</details>

All requests (curl -s http://localhost:80 | grep served) are routing to healthy endpoint 172.24.0.5
````
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_c
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_c
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_c

When disabled endpoint starts again envoy adds it to cluster after 3rd successful HC-request.
All requests (curl -s http://localhost:80 | grep served) are routing to healthy endpoints 172.24.0.4 and 172.24.0.5
````
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_c
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_d
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_c
````
<details>
<summary>Envoy /clusters output:</summary>
<pre>
````
example_proxy_cluster::observability_name::example_proxy_cluster
example_proxy_cluster::default_priority::max_connections::1024
example_proxy_cluster::default_priority::max_pending_requests::1024
example_proxy_cluster::default_priority::max_requests::1024
example_proxy_cluster::default_priority::max_retries::3
example_proxy_cluster::high_priority::max_connections::1024
example_proxy_cluster::high_priority::max_pending_requests::1024
example_proxy_cluster::high_priority::max_requests::1024
example_proxy_cluster::high_priority::max_retries::3
example_proxy_cluster::added_via_api::true
example_proxy_cluster::172.24.0.4:8080::cx_active::1
example_proxy_cluster::172.24.0.4:8080::cx_connect_fail::1
example_proxy_cluster::172.24.0.4:8080::cx_total::3
example_proxy_cluster::172.24.0.4:8080::rq_active::0
example_proxy_cluster::172.24.0.4:8080::rq_error::1
example_proxy_cluster::172.24.0.4:8080::rq_success::3
example_proxy_cluster::172.24.0.4:8080::rq_timeout::0
example_proxy_cluster::172.24.0.4:8080::rq_total::3
example_proxy_cluster::172.24.0.4:8080::hostname::
example_proxy_cluster::172.24.0.4:8080::health_flags::healthy
example_proxy_cluster::172.24.0.4:8080::weight::1
example_proxy_cluster::172.24.0.4:8080::region::
example_proxy_cluster::172.24.0.4:8080::zone::
example_proxy_cluster::172.24.0.4:8080::sub_zone::
example_proxy_cluster::172.24.0.4:8080::canary::false
example_proxy_cluster::172.24.0.4:8080::priority::0
example_proxy_cluster::172.24.0.4:8080::success_rate::-1.0
example_proxy_cluster::172.24.0.4:8080::local_origin_success_rate::-1.0
example_proxy_cluster::172.24.0.5:8080::cx_active::1
example_proxy_cluster::172.24.0.5:8080::cx_connect_fail::0
example_proxy_cluster::172.24.0.5:8080::cx_total::1
example_proxy_cluster::172.24.0.5:8080::rq_active::0
example_proxy_cluster::172.24.0.5:8080::rq_error::0
example_proxy_cluster::172.24.0.5:8080::rq_success::12
example_proxy_cluster::172.24.0.5:8080::rq_timeout::0
example_proxy_cluster::172.24.0.5:8080::rq_total::12
example_proxy_cluster::172.24.0.5:8080::hostname::
example_proxy_cluster::172.24.0.5:8080::health_flags::healthy
example_proxy_cluster::172.24.0.5:8080::weight::1
example_proxy_cluster::172.24.0.5:8080::region::
example_proxy_cluster::172.24.0.5:8080::zone::
example_proxy_cluster::172.24.0.5:8080::sub_zone::
example_proxy_cluster::172.24.0.5:8080::canary::false
example_proxy_cluster::172.24.0.5:8080::priority::0
example_proxy_cluster::172.24.0.5:8080::success_rate::-1.0
example_proxy_cluster::172.24.0.5:8080::local_origin_success_rate::-1.0
````
Notice: there are two endpoints in cluster again, 172.24.0.4 and 172.24.0.5. All endpoints have health_flags::healthy
</pre>
</details>


