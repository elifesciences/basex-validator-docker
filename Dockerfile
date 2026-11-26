FROM ghcr.io/basexdb/basex:13.1

USER root
RUN rm -rf /opt/basex/webapp/*
USER basex

COPY --chown=basex src/.basex /opt/basex/.basex
COPY --chown=basex src/repo /opt/basex/repo
COPY --chown=basex src/webapp /opt/basex/webapp
COPY --chown=basex eLife-JATS-schematron/src /opt/basex/webapp/schematron
COPY --chown=basex src/saxon9he.jar /opt/basex/lib/custom/saxon9he.jar


ENV BASEX_JVM="-Xmx2g \
  -Djdk.xml.entityExpansionLimit=64000 \
  -Djdk.xml.totalEntitySizeLimit=50000000 \
  -Djdk.xml.maxGeneralEntitySizeLimit=0 \
  -Djdk.xml.maxParameterEntitySizeLimit=1000000 \
  -Djdk.xml.elementAttributeLimit=10000 \
  -Djdk.xml.maxElementDepth=0"

EXPOSE 8984
HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -q -O /dev/null http://localhost:8984/ || exit 1
