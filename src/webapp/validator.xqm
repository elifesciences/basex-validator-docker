module namespace e = 'http://elifesciences.org/modules/validate';
import module namespace session = "http://basex.org/modules/session";
import module namespace rest = "http://exquery.org/ns/restxq";
declare namespace svrl = "http://purl.oclc.org/dsdl/svrl";

declare
  %rest:path("/schematron/pre")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("json")
function e:validate-pre($xml)
{
  let $xsl := doc('./schematron/pre-JATS-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  return e:svrl2json($svrl)
};

declare
  %rest:path("/schematron/dl")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("json")
function e:validate-dl($xml)
{
  let $xsl := doc('./schematron/dl-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  return e:svrl2json($svrl)
};

declare
  %rest:path("/schematron/final")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("json")
function e:validate-final($xml)
{
  let $xsl := doc('./schematron/final-JATS-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  return 
  (: Extra check for Glencoe Metadata :)
  if ($xml//*:media[@mimetype="video"]) then (e:svrl2json-final($xml,$svrl))
  else e:svrl2json($svrl)
};

declare function e:svrl2json($svrl)
{ 
  let $errors :=
      concat(
         '"errors": [',
         string-join(
         for $error in $svrl//*[@role="error"]
         return concat(
                '{',
                ('"path": "'||$error/@location/string()||'",'),
                ('"type": "'||$error/@role/string()||'",'),
                ('"message": "'||e:get-message($error)||'"'),
                '}'
              )
          ,','),
        ']'
      )
  let $warnings := 
     concat(
         '"warnings": [',
         string-join(
         for $warn in $svrl//*[@role=('info','warning','warn')]
         return concat(
                '{',
                ('"path": "'||$warn/@location/string()||'",'),
                ('"type": "'||$warn/@role/string()||'",'),
                ('"message": "'||e:get-message($warn)||'"'),
                '}'
              )
          ,','),
        ']'
      )
      
  let $json :=  
    concat(
      '{
        "results": {',
      $errors,
      ',',
      $warnings,
      '} }'
    )
  return json:parse($json)
};

(: Contains check for Glencoe metadata :)
declare function e:svrl2json-final($xml,$svrl){
  let $doi := $xml//*:article-meta//*:article-id[@pub-id-type="doi"]/string()
  let $glencoe := e:get-glencoe($doi)
  let $glencoe-errors := 
  string-join(
           if ($glencoe//*:error) then ('{"path": "unknown", "type": "error", "message": "There is no Glencoe metadata for this article but it contains videos. Please esnure that the Glencoe data is correct."}')
         else (
           for $vid in $xml//*:media[@mimetype="video"]
           let $id := $vid/@id
           return if ($glencoe/*[local-name()=$id and *:video__id[.=$id] and ends-with(*:solo__href,$id)]) then ()
           else concat(
                '{',
                ('"path": "unkown",'),
                ('"type": "error",'),
                ('"message": "There is no metadata in Glencoe for the video with id '||concat("'",$id,"'")||'."'),
                '}'
              )
         ),',')
  let $sch-errors := string-join(
         for $error in $svrl//*[@role="error"]
         return concat(
                '{',
                ('"path": "'||$error/@location/string()||'",'),
                ('"type": "'||$error/@role/string()||'",'),
                ('"message": "'||e:get-message($error)||'"'),
                '}'
              )
          ,',')
  
  let $errors :=
      concat(
         '"errors": [', 
          string-join(
            (if ($glencoe-errors='') then () else $glencoe-errors,
             if ($sch-errors='') then () else $sch-errors)
            ,','),
        ']'
      )
let $warnings := 
     concat(
         '"warnings": [',
         string-join(
         for $warn in $svrl//*[@role=('info','warning','warn')]
         return concat(
                '{',
                ('"path": "'||$warn/@location/string()||'",'),
                ('"type": "'||$warn/@role/string()||'",'),
                ('"message": "'||e:get-message($warn)||'"'),
                '}'
              )
          ,','),
        ']'
      )
      
let $json :=  
    concat(
      '{
        "results": {',
      $errors,
      ',',
      $warnings,
      '} }'
    )
return json:parse($json)
};

declare function e:json-escape($string){
  normalize-space(replace(replace($string,'\\','\\\\'),'"','\\"'))
};

declare function e:get-message($node){
  if ($node[@see]) then e:json-escape((data($node)||' '||$node/@see))
  else e:json-escape(data($node))
};

declare function e:get-glencoe($doi){
  try {
    http:send-request(
  <http:request method='get' href="{('https://movie-usa.glencoesoftware.com/metadata/'||$doi)}" timeout='2'>
    <http:header name="From" value="production@elifesciences.org"/>
    <http:header name="Referer" value="https://basex-validator--staging.elifesciences.org/schematron/final"/>
    <http:header name="User-Agent" value="basex-validator"/>
  </http:request>)//*:json}
  
  (: Return error for timeout :)
  catch * { json:parse('{"error": "Not found"}') }
   
};

declare function e:transform($xml,$schema)
{  
  try {xslt:transform($xml, $schema)}
  (: Return psuedo-svrl to output error message for fatal xslt errors :)
  catch * { <schematron-output><successful-report id="validator-broken" location="unknown" role="error"><text>{'Error [' || $err:code || ']: ' || $err:description}</text></successful-report></schematron-output>}
};


(: HTML pages:)

declare
  %rest:path("/")
  %rest:GET
  %output:method("html")
function e:upload()
{
  let $form := <form id="form1" method="POST" enctype="multipart/form-data">
                 <div class="form-group">
                   <label for="files">Select file:</label>
                   <input id="files" type="file" name="xml" accept="application/xml"/>
                 </div>
                 <div class="form-group">
                    <label class="col-2">Schematron:</label>
                    <button id="preBtn" formaction="/pre-result">Pre</button>
                    <button id="finalBtn" formaction="/final-result">Final</button>
                 </div>
               </form>
  let $script := <script src="../static/form.js"></script>
   
  return e:template(($form,$script))
};

declare
  %rest:path("/pre-result")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("html")
function e:validate-pre-result($xml)
as element(html)
{
  let $xsl := doc('./schematron/pre-JATS-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  let $container := <div class="container">
                    <div id="editor">
                      <textarea id="code">{serialize($xml,map{'method':'xml','indent':'yes'})}</textarea>
                    </div>
                    {e:svrl2result($svrl)}
                    </div>
  let $scripts := (<script src="../static/codemirror/lib/codemirror.js"></script>,
                   <script src="../static/codemirror/mode/xml/xml.js"></script>,
                   <script src="../static/codemirror/addon/search/jump-to-line.js"></script>,
                   <script src="../static/codemirror/addon/search/search.js"></script>,
                   <script src="../static/codemirror/addon/search/searchcursor.js"></script>,
                   <script src="../static/codemirror/addon/dialog/dialog.js"></script>,
                   <script src="../static/editor.js"></script>)
  let $elems := ($container,$scripts)
  return e:template($elems)
};

declare
  %rest:path("/final-result")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("html")
function e:validate-final-result($xml)
as element(html)
{
  let $xsl := doc('./schematron/final-JATS-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  let $container := <div class="container">
                    <div id="editor">
                      <textarea id="code">{serialize($xml,map{'method':'xml','indent':'yes'})}</textarea>
                    </div>
                    {if ($xml//*:media[@mimetype="video"]) then (e:svrl2result-video($xml,$svrl))
                     else e:svrl2result($svrl)}
                    </div>
  let $scripts := (<script src="../static/codemirror/lib/codemirror.js"></script>,
                   <script src="../static/codemirror/mode/xml/xml.js"></script>,
                   <script src="../static/codemirror/addon/search/jump-to-line.js"></script>,
                   <script src="../static/codemirror/addon/search/search.js"></script>,
                   <script src="../static/codemirror/addon/search/searchcursor.js"></script>,
                   <script src="../static/codemirror/addon/dialog/dialog.js"></script>,
                   <script src="../static/editor.js"></script>)
  let $elems := ($container,$scripts)
  return e:template($elems)
};

declare
function e:svrl2result($svrl) as element(div) {
  let $table := <table>
    <thead>
      <tr>
        <th/>
        <th>Type</th>
        <th>ID</th>
        <th hidden="">XPath</th>
      <th>Message</th>
    </tr>    
    </thead>
    <tbody>{e:get-table-rows($svrl)}</tbody>
</table>
  
  return <div id="results">
            <div id="table-scroll">{$table}</div>
        </div>
};

declare function e:svrl2result-video($xml,$svrl) as element(div)*
{
  let $doi := $xml//*:article-meta//*:article-id[@pub-id-type="doi"]/string()
  let $glencoe := e:get-glencoe($doi)
  let $glencoe-rows := 
    if ($glencoe//*:error) then <tr class="error">
                                  <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                                  <td>Error</td>
                                  <td>unknown</td>
                                  <td class="xpath" hidden="">unknown</td>
                                  <td class="message">There is no Glencoe metadata for this article but it contains videos. Please esnure that the Glencoe data is correct.</td>
                                </tr>
    else (
           for $vid in $xml//*:media[@mimetype="video"]
           let $id := $vid/@id
           return if ($glencoe/*[local-name()=$id and *:video__id[.=$id] and ends-with(*:solo__href,$id)]) then ()
           else <tr class="error">
                  <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                  <td>Error</td>
                  <td>unknown</td>
                  <td class="xpath" hidden="">{$id}</td>
                  <td class="message">{'There is no metadata in Glencoe for the video with id "'||$id||'".'}</td>
                </tr>
        )
   
   let $table-rows := e:get-table-rows($svrl)       
   let $table := <table>
   <thead>
     <tr>
      <th/>
      <th>Type</th>
      <th>ID</th>
      <th hidden=""/>
      <th>Message</th>
      </tr>
   </thead>
   <tbody>
     {($glencoe-rows,$table-rows)}
   </tbody>
</table>
   
   return <div id="results">
            <div id="table-scroll">{$table}</div>
        </div>
};

declare function e:get-table-rows($svrl) as element(tr)* {
  for $x at $p in $svrl//*[@role=('error','warn','warning','info')]
    let $id-content := if ($x/@see) then <a href="{$x/@see/string()}" target="_blank">{$x/@id/string()}</a>
                  else $x/@id/string()
    let $type := (upper-case(substring($x/@role,1,1))||substring($x/@role,2))
    let $class := if ($p mod 2 = 0) then ($x/@role||' even') else ($x/@role||' odd')
    return <tr class="{$class}">
            <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
            <td>{$type}</td>
            <td>{$id-content}</td>
            <td class="xpath" hidden="">{$x/@location/string()}</td>
            <td class="message">{data($x/*:text)}</td>
           </tr>
};

declare
function e:template($elem as element()*) as element(html) {
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <link rel="icon" type="image/png" sizes="32x32" href="../static/favicon-32x32.56d32e31.png"/>
    <link rel="preconnect" href="https://fonts.gstatic.com"/>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;700&amp;display=swap" rel="stylesheet"/>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css"/>
    <link href="../static/styles.css" rel="stylesheet"/>
    <link href="../static/codemirror/lib/codemirror.css" rel="stylesheet"/>
    <link href="../static/codemirror/addon/dialog/dialog.css" rel="stylesheet"/>
    <title>XML Validator</title>
</head>
  <body>
    <div id="root">
      <div class="header">
        <div id="home-wrapper">
          <a href="/"><img src="../static/elife.svg" class="img-thumbnail"/></a>
        </div>
        <span id="title">XML Validator</span>
      </div>
    {$elem}
    </div>
  </body>
</html>
};