# envoy
Envoy's xDS with Active Health Check discovery
## Description ##


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


All components are running locally in docker with the sharing docker bridge network:



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
````
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_d
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_c
admin@ip-172-31-5-70:~/envoy$ curl -s http://localhost:80 | grep served
Request served by container_d
````
