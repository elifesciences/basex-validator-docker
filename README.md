# BaseX Validator Docker

A docker container that validates XML against the JATS DTDs and eLife's schematron files, built on BaseX.

## Getting Started

The image is built on the official BaseX image ([`ghcr.io/basexdb/basex`](https://github.com/BaseXdb/basex/pkgs/container/basex), currently BaseX 13.1 on Java 25)
and serves the validator over HTTP on port **8984**.

The schematron files come from the [eLife-JATS-schematron](https://github.com/elifesciences/eLife-JATS-schematron) git submodule.

### Running the service

There are two ways to run it. Use one or the other: both publish port 8984, so stop one before starting the other.

**Option 1: docker compose** (recommended; this is what CI uses)

```
docker compose up --build --wait   # build, start, and wait for the healthcheck to pass
docker compose down                # stop
```

**Option 2: docker**

```
docker build . -t basex-validator:local
docker run --rm --memory="2g" -p 8984:8984 basex-validator:local
```

Stop it with `Ctrl+C`. The `docker build` step is required: `docker run` uses the `basex-validator:local` tag, which docker compose does not create.

### Using the service

Open http://localhost:8984/ in a browser to upload a file and view results, or use the API, for example with cURL:

```
curl -F xml=@test/xml/elife45905.xml http://localhost:8984/schematron/pre
curl -F xml=@test/xml/elife45905.xml http://localhost:8984/schematron/final
curl -F xml=@test/xml/elife45905.xml http://localhost:8984/dtd
curl -F xml=@test/xml/elife45905.xml -F "type=publishing" http://localhost:8984/dtd
```

## dtd
Post xml and receive dtd validation in json format.

Valid
```json
{
  "status":"valid"
}
```

Invalid
```json
{
  "status":"invalid",
  "errors":[
    {
      "line":"15",
      "column":"20",
      "message":"Element type 'sarticle-meta' must be declared."
    },
    {
      "line":"369",
      "column":"11",
      "message":"The content of element type 'front' must match '(journal-meta?,article-meta,(def-list|list|ack|bio|fn-group|glossary|notes)*)'."
    }
  ]
}
```

`type` is optional param specifying which DTD flavor to validate. By default (if no `type` is specified) it is `archiving`.

JATS DTDs are included in `src/webapp/dtds`.
To add (or replace) DTDs, add the files in the correct folder for the version and flavour, and update `src/webapp/dtds/catalogue.xml` with the version/filename (including the `.dtd` extension).

The DTD version is taken from the `article/@dtd-version` attribute in the XML supplied. If there is no such attribute, version `1.4` is used.

## Schematron
Invalid
```json
{
  "results":{
    "errors":[
      {
        "path":"\/article[1]\/front[1]\/article-meta[1]\/abstract[1]\/p[1]\/italic[1]",
        "type":"error",
        "message":"[pre-in-vivo-italic-test] italic element contains 'in vivo' - this should not be in italics (eLife house style)."
      }
    ],
    "warnings":[
      {
        "path":"\/article[1]",
        "type":"info",
        "message":"[dtd-info] DTD version is 1.1"
      },
      {
        "path":"\/article[1]\/sub-article[2]\/body[1]\/fig[2]\/caption[1]\/title[1]",
        "type":"warning",
        "message":"[fig-title-test-1] 'Author response image 2.' appears to have a title which is the beginning of a caption. Is this correct? https:\/\/elifesciences.gitbook.io\/productionhowto\/-M1eY9ikxECYR-0OcnGt\/article-details\/content\/allowed-assets\/figures#fig-title-test-1"
      }
    ]
  }
}
```

Valid with warnings
```json
{
  "results":{
    "errors":[
    ],
    "warnings":[
      {
        "path":"\/article[1]",
        "type":"info",
        "message":"[dtd-info] DTD version is 1.1"
      },
      {
        "path":"\/article[1]\/sub-article[2]\/body[1]\/fig[2]\/caption[1]\/title[1]",
        "type":"warning",
        "message":"[fig-title-test-1] 'Author response image 2.' appears to have a title which is the beginning of a caption. Is this correct? https:\/\/elifesciences.gitbook.io\/productionhowto\/-M1eY9ikxECYR-0OcnGt\/article-details\/content\/allowed-assets\/figures#fig-title-test-1"
      }
    ]
  }
}
```

Valid with no warnings will never occur.

## UI
Upload xml at `/`, and validate against the chosen Schematron. 
The resulting UI uses [CodeMirror](https://codemirror.net/) to display the XML.