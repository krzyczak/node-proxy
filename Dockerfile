FROM node:7.2.1-alpine

EXPOSE 443 8080 80 43554

RUN npm install pm2 -g

# Add the user and run everything else as non root
# If default image is used instead of Alpine:
# RUN useradd -ms /bin/bash thebigsofa
#
# If Alpine image is used:
RUN adduser -D thebigsofa

VOLUME ["/home/thebigsofa/src/app"]
WORKDIR /home/thebigsofa/src/app

USER thebigsofa

CMD ["/bin/sh"]
