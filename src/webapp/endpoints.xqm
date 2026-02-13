module namespace e = 'http://elifesciences.org/modules/validate';
import module namespace session = "http://basex.org/modules/session";
import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace svrl = 'http://elifesciences.org/modules/svrl-converter';
import module namespace api = 'http://elifesciences.org/modules/api-clients';
import module namespace util = 'http://elifesciences.org/modules/utilities';
declare namespace svrl-ns = "http://purl.oclc.org/dsdl/svrl";

(: Schematron :)

declare
  %rest:path("/schematron/preprint")
  %rest:POST("{$xml}")
  %output:method("json")
function e:validate-preprint($xml)
{
  let $xsl := doc('./schematron/rp-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  return svrl:svrl2json($xml,$svrl)
};

declare
  %rest:path("/schematron/manifest")
  %rest:POST("{$xml}")
  %output:method("json")
function e:validate-manifest($xml)
{
  let $xsl := doc('./schematron/meca-manifest-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  return svrl:svrl2json($xml,$svrl)
};

declare
  %rest:path("/schematron/pre")
  %rest:POST("{$xml}")
  %output:method("json")
function e:validate-pre($xml)
{
  let $xsl := doc('./schematron/pre-JATS-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  return svrl:svrl2json($xml,$svrl)
};

declare
  %rest:path("/schematron/dl")
  %rest:POST("{$xml}")
  %output:method("json")
function e:validate-dl($xml)
{
  let $xsl := doc('./schematron/dl-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  return svrl:svrl2json($xml,$svrl)
};

declare
  %rest:path("/schematron/final")
  %rest:POST("{$xml}")
  %output:method("json")
function e:validate-final($xml)
{
  let $xsl := doc('./schematron/final-JATS-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  return 
  (: Extra check for Glencoe Metadata :)
  if ($xml//*:media[@mimetype="video"]) then (svrl:svrl2json-final($xml,$svrl))
  else svrl:svrl2json($xml,$svrl)
};

declare function e:transform($xml, $xsl)
{
  xslt:transform($xml, $xsl)
};

(: XSL :)

declare
  %rest:path("/xsl")
  %rest:POST("{$xml}")
function e:transform-preprint($xml as item())
{
  let $doctype := '<!DOCTYPE article PUBLIC "-//NLM//DTD JATS (Z39.96) Journal Archiving and Interchange DTD v1.3 20210610//EN" "JATS-archivearticle1-mathml3.dtd">'
  let $options := map{'indent':'no',
                    'omit-xml-declaration':'yes'}
  let $xsl := doc('./schematron/preprint-changes.xsl')
  let $ror-xml := api:introduce-rors($xml)
  return 
  if ($ror-xml[.instance of xs:string]) then (
    '<?xml version="1.0" encoding="UTF-8"?>&#xa;'||$doctype||'&#xa;'||
    xslt:transform-text(util:strip-preamble($ror-xml),$xsl,$options)
  )
  else if ($ror-xml[.instance of document-node()]) then (
    '<?xml version="1.0" encoding="UTF-8"?>&#xa;'||$doctype||'&#xa;'||
    xslt:transform-text($ror-xml,$xsl,$options)
  )
  else (error(xs:QName("basex:error"),'Input must be supplied as a string or XML document.'))
};

declare
  %rest:path("/xsl-silent")
  %rest:POST("{$xml}")
function e:transform-preprint-silent($xml as item())
{
  let $doctype := '<!DOCTYPE article PUBLIC "-//NLM//DTD JATS (Z39.96) Journal Archiving and Interchange DTD v1.3 20210610//EN" "JATS-archivearticle1-mathml3.dtd">'
  let $options := map{'indent':'no',
                    'omit-xml-declaration':'yes'}
  let $xsl := doc('./schematron/preprint-silent-changes.xsl')
  return 
  if ($xml[.instance of xs:string]) then (
    '<?xml version="1.0" encoding="UTF-8"?>&#xa;'||$doctype||'&#xa;'||
    xslt:transform-text(util:strip-preamble($xml),$xsl,$options)
  )
  else if ($xml[.instance of document-node()]) then (
    '<?xml version="1.0" encoding="UTF-8"?>&#xa;'||$doctype||'&#xa;'||
    xslt:transform-text($xml,$xsl,$options)
  )
  else (error(xs:QName("basex:error"),'Input must be supplied as a string or XML document.'))
};
