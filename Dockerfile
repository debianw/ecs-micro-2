FROM node:7
MAINTAINER Waly debianw@gmail.com
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
ADD . /usr/src/app
RUN npm install
CMD ["npm", "start"]

