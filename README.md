# BaseX Validator Docker

A docker contatiner that can be used to validate XML against jats dtds and eLife's 'pre' and 'final' schematron files built upon
BaseX.

## Getting Started

You can now build the container locally using the following command, which will build a new container using the latest
version of the schematron files from https://github.com/elifesciences/eLife-JATS-schematron

```
docker build . -t basex-validator:local
docker run --rm --memory="512m" -p 8984:8984 basex-validator:local
```

You can then interact with the service on port 8984 for example using cURL, for example...

```
curl -F xml=@test/xml/elife45905.xml http://localhost:8984/schematron/pre
curl -F xml=@test/xml/elife45905.xml http://localhost:8984/schematron/final
curl -F xml=@test/xml/elife45905.xml http://localhost:8984/dtd
curl -F xml=@xml/elife45905.xml -F "type=publishing" http://localhost:8984/dtd
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

jats dtds are included in `webapp/dtds`.
To add (or replace) dtds, add the files in the correct folder depending on its version and flavour, and update `webapp/dtds/catalogue.xml` with the version/filename (ensuring to include `.dtd`).

dtd version is derived from the `article/@dtd-version` attribute value in the xml file supplied. If there is no such attribute, then `1.2` is the default version.

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