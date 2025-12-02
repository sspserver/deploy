FROM node:25 AS build

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
    npm run build --prod --output-path=/tmp/adview-dist/native

# Build packages/popunder project into /tmp/adview-dist/popunder
RUN cd /tmp/adview/src/popunder && \
    npm install && \
    npm run build --prod --output-path=/tmp/adview-dist/popunder

FROM joseluisq/static-web-server:latest

COPY --from=build /tmp/jssdk-dist /var/public

EXPOSE 80
