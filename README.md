# BaseX Validator Docker

A docker contatiner that can be used to validate XML against DTD and Schematron.

## Getting Started

You can now build the container locally using the following command:
```
docker build . --tag basex-validator
docker run --rm --memory="1g" -p 1984:1984 -p 8984:8984 basex-validator
```

You can then interact with the service on port 8984 for example using cURL, for example...

```
curl -F xml=@somexmlfile.xml http://localhost:8984/schematron
curl -F xml=@somexmlfile.xml http://localhost:8984/dtd
curl -F xml=@somexmlfile.xml -F "type=publishing" http://localhost:8984/dtd
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

dtd version is derived from the `article/@dtd-version` attribute value in the xml file supplied. If there is no such attribute, then `1.3` is the default version.

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

## UI
Upload xml at `http://localhost:8984/`, and validate against the chosen Schematron. 
The resulting UI uses [CodeMirror](https://codemirror.net/) to display the XML.