FROM basex/basexhttp:9.2.3
COPY --chown=basex src/repo /srv/basex/repo
COPY --chown=basex src/webapp /srv/basex/webapp
COPY --chown=basex eLife-JATS-schematron/src /srv/basex/webapp/schematron
COPY src/saxon9he.jar /usr/src/basex/basex-api/lib/saxon9he.jar
COPY --chown=basex src/.basex /srv/basex