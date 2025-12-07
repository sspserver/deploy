FROM node:25 AS build

ARG ADVIEW_STYLES_PATH
ENV ADVIEW_STYLES_PATH=${ADVIEW_STYLES_PATH}

ARG ADSERVER_AD_JSONP_REQUEST_URL
ENV ADSERVER_AD_JSONP_REQUEST_URL=${ADSERVER_AD_JSONP_REQUEST_URL}

# Download the AdView packages zip file prepared in the CI workflow
# archive contains only the `packages/native` and `packages/popunder` directories
# from the AdView source code repository
ADD https://github.com/sspserver/deploy/raw/refs/heads/build/adview-packages.zip /tmp/adview/adview-packages.zip

RUN mkdir -p /tmp/adview/src && \
    unzip /tmp/adview/adview-packages.zip -d /tmp/adview/src

RUN echo "Contents of /tmp/adview/src:"
RUN ls -la /tmp/adview/src/

# Build packages/native project into /tmp/adview-dist/native
RUN cd /tmp/adview/src/native && \
    npm install && \
    npm run build --omit=dev --prod

# Build packages/popunder project into /tmp/adview-dist/popunder
RUN cd /tmp/adview/src/popunder && \
    npm install && \
    npm install @swc/core -D && \
    npm run build --omit=dev --prod

# Prepare the final distribution directory
RUN mkdir -p /tmp/adview-dist
RUN cp -r /tmp/adview/src/native/dist/* /tmp/adview-dist/
RUN cp -r /tmp/adview/src/popunder/dist/* /tmp/adview-dist/
RUN echo "404 Not Found" > /tmp/adview-dist/404.html
RUN echo "" > /tmp/adview-dist/index.html
RUN ls -la /tmp/adview-dist

FROM joseluisq/static-web-server:latest

COPY --from=build /tmp/adview-dist /var/www/html

EXPOSE 80
