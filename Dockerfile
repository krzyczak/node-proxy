FROM node:7.2.0

EXPOSE 443 8080 80 43554

RUN npm install pm2 -g

# Add the user and run everything else as non root
RUN useradd -ms /bin/bash thebigsofa
RUN mkdir -p /home/thebigsofa/src/app
WORKDIR /home/thebigsofa/src/app
COPY package.json .
RUN npm install
USER thebigsofa
VOLUME ["/home/thebigsofa/src/app", "/home/thebigsofa/src/app/node_modules"]

# TODO: how to run it with verious --env ???
CMD ["pm2-docker", "start", "--env", "production", "os-proxy.yml"]
# CMD ["pm2-docker", "start", "--env", "development", "os-proxy.yml"]
