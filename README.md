# BaseX Validator Docker

A docker contatiner that can be used to validate XML against eLife's 'pre' and 'final' schematron files built upon
BaseX.

## Getting Started

You can now build the container locally using the following command, which will build a new container using the latest
version of the schematron files from https://github.com/elifesciences/eLife-JATS-schematron

```
docker build . -t basex-validator:local
docker run --rm --memory="512m" -p 1984:1984 -p 8984:8984 basex-validator:local
```

You can then interact with the service on port 8984 for example using cURL, for example...

```
curl -F xml=@test/xml/elife45905.xml http://localhost:8984/schematron/pre
curl -F xml=@test/xml/elife45905.xml http://localhost:8984/schematron/final
```
