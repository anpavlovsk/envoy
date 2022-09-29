# Pull the Debian image
FROM  debian:stable-slim

# Install Nginx
RUN apt-get -y update && apt-get -y install nginx sudo

# Install Envoy
RUN sudo apt -y install debian-keyring debian-archive-keyring apt-transport-https curl lsb-release
RUN curl -sL 'https://deb.dl.getenvoy.io/public/gpg.8115BA8E629CC074.key' | sudo gpg --dearmor -o /usr/share/keyrings/getenvoy-keyring.gpg
RUN echo a077cb587a1b622e03aa4bf2f3689de14658a9497a9af2c427bba5f4cc3c4723 /usr/share/keyrings/getenvoy-keyring.gpg | sha256sum --check
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/getenvoy-keyring.gpg] https://deb.dl.getenvoy.io/public/deb/debian $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/getenvoy.list
RUN sudo apt update
RUN sudo apt install getenvoy-envoy

# Copy the Nginx config
COPY default /etc/nginx/sites-available/default

# Copy the Envoy config
COPY envoy.yaml /etc/envoy/envoy.yaml
COPY ./configs /etc/envoy
RUN chmod go+x /etc/envoy  \
    && chmod go+r /etc/envoy/envoy.yaml /etc/envoy/*

# Run the Nginx and Envoy server
ADD ./start_service.sh /usr/local/bin/start_service.sh
RUN chmod u+x /usr/local/bin/start_service.sh
ENTRYPOINT ["/usr/local/bin/start_service.sh"]
