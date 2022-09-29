# envoy
Envoy's xDS with Active Health Check discovery
## Description ##



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

### Listener Discovery Service (LDS):###
````

````

### Cluster Discovery Service (CDS):###
````
````

Health check configuration:
````
 health_checks:
      timeout: 2s
      interval: 1s
      unhealthy_threshold: 3
      healthy_threshold: 3
      no_traffic_interval: 60s
      event_log_path: /dev/stdout
      always_log_health_check_failures: false
      http_health_check:
        path: /  
````
All components are running locally in docker with the sharing docker bridge network:

````
````


