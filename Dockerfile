FROM phusion/baseimage:latest as builder-image

ENV ENKETO_SRC_DIR=/srv/src/enketo_express

################
# apt installs #
################

# Add NodeJS 8 repository
ADD https://deb.nodesource.com/gpgkey/nodesource.gpg.key /tmp/
RUN echo 'deb https://deb.nodesource.com/node_8.x xenial main' > /etc/apt/sources.list.d/nodesource.list && \
    apt-key add /tmp/nodesource.gpg.key

COPY ./setup/docker/apt_requirements.txt ${ENKETO_SRC_DIR}/setup/docker/
WORKDIR ${ENKETO_SRC_DIR}/
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y nodejs $(cat setup/docker/apt_requirements.txt) && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Non-interactive equivalent of `dpkg-reconfigure -plow unattended-upgrades` (see https://blog.sleeplessbeastie.eu/2015/01/02/how-to-perform-unattended-upgrades/).
RUN cp /usr/share/unattended-upgrades/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades

###############################
# Enketo Express Installation #
###############################

RUN npm install -g grunt-cli pm2
COPY ./package.json ${ENKETO_SRC_DIR}/
RUN npm install --production

COPY . ${ENKETO_SRC_DIR}

# create the config (migrated from 01_setup_enketo.bash)
RUN python setup/docker/create_config.py

# directly execute the grunt build (migrated from 01_setup_enketo.bash)
RUN grunt

# Now we can copy over the built project to our running image (results in smaller docker image size)
FROM node:8-stretch-slim as runner-image

ENV ENKETO_SRC_DIR=/srv/src/enketo_express

COPY --from=builder-image ${ENKETO_SRC_DIR} ${ENKETO_SRC_DIR}

WORKDIR ${ENKETO_SRC_DIR}/

ENV PATH $PATH:${KPI_SRC_DIR}/node_modules/.bin

# Persist the `secrets` directory so the encryption key remains consistent.
RUN mkdir -p ${ENKETO_SRC_DIR}/setup/docker/secrets
VOLUME ${ENKETO_SRC_DIR}/setup/docker/secrets

EXPOSE 8005
CMD [ "npm", "start" ]
