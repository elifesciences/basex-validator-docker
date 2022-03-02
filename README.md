# BaseX Validator Docker

A docker contatiner that can be used to validate xml against dtd and schematron.

An example schematron file is provided in [src/webapp/schematron](https://github.com/elifesciences/basex-validator-docker/tree/vanilla/src/webapp/schematron).

An [example xml](https://github.com/elifesciences/basex-validator-docker/blob/vanilla/somexmlfile.xml) file is provided to validate. 

## Getting Started

Build the container locally using the following commands:
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

## UI
Upload xml at http://localhost:8984/, and validate against the dtd and schematron. 
The resulting UI uses [CodeMirror](https://codemirror.net/) to display the xml.

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
      "line":"19",
      "column":"12",
      "message":"Element type 'bark' must be declared."
    },
    {
      "line":"20",
      "column":"11",
      "message":"The content of element type 'article' must match '(front,body?,back?,floats-group?,(sub-article*|response*))'."
    }
  ]
}
```

`type` is optional param specifying which dtd flavor to validate. By default (if no `type` is specified) it is `archiving`.

jats dtds are included in `webapp/dtds`.
To add (or replace) dtds, add the files in the correct folder depending on its version and flavour, and update `webapp/dtds/catalogue.xml` with the version/filename (ensuring to include `.dtd`).

dtd version is derived from the `article/@dtd-version` attribute value in the xml file supplied. If there is no such attribute, then `1.3` is the default version.

## schematron
Invalid
```json
{
  "status":"invalid",
  "results":{
    "errors":[
      {
        "path":"\/article[1]\/body[1]\/p[1]",
        "type":"error",
        "message":"Every p element must contain an italic element. This one does not. https:\/\/www.schematron.com\/"
      }
    ],
    "warnings":[
      {
        "path":"\/article[1]\/body[1]\/p[3]",
        "type":"warning",
        "message":"p element should not contain a bold element. https:\/\/www.schematron.com\/"
      }
    ]
  }
}
```

Valid with warnings
```json
{
  "status":"valid",
  "results":{
    "errors":[
    ],
    "warnings":[
      {
        "path":"\/article[1]\/body[1]\/p[2]",
        "type":"warning",
        "message":"p element should not contain a bold element. https:\/\/www.schematron.com\/"
      }
    ]
  }
}
```
