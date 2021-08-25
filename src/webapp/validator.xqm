module namespace e = 'http://elifesciences.org/modules/validate';
import module namespace session = "http://basex.org/modules/session";
import module namespace rest = "http://exquery.org/ns/restxq";
declare namespace svrl = "http://purl.oclc.org/dsdl/svrl";

(: Schematron :)

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

(: DTD :)

declare
  %rest:path("/dtd")
  %rest:POST("{$data}")
  %output:method("json")
function e:validate-dtd($data as item()+)
{
  let $flavours := ("archiving","authoring","publishing")
  let $param-count := count($data)
  return
    if ($param-count = 2) then (
      if (not($data[. instance of document-node()])) then 
          error(xs:QName("basex:error"),'An xml file must be supplied to validate')
      else if (not($data[. instance of xs:string and .=$flavours])) then 
          error(xs:QName("basex:error"),'If two parameters are specified, then one must be a string which is one of the jats flavours: '||string-join($flavours,', '))
      
      else (
        let $xml := $data[. instance of document-node()]
        let $type := $data[. instance of xs:string]
        let $version := e:get-version($xml)
        let $dtd := e:get-dtd($version,$type)
        let $report :=  validate:dtd-report($xml,$dtd)
        
        return e:dtd2json($report)
      ))  
    
    (: default is archiving if no type is provided :)
    else if ($param-count = 1) then (
      if (not($data[. instance of document-node()])) then 
          error(xs:QName("basex:error"),'An xml file must be supplied to validate') 
      else (
        let $xml := $data[. instance of document-node()]
        let $type := "archiving"
        let $version := e:get-version($xml)
        let $dtd := e:get-dtd($version,$type)
        let $report :=  validate:dtd-report($xml,$dtd)
        
        return e:dtd2json($report)
      )
    )
      
    else if ($param-count gt 2) then 
      error(xs:QName("basex:error"),'Too many parameters supplied: '||$param-count)
    
    else error(xs:QName("basex:error"),'An xml file must be supplied to validate')
};

(: get dtd version from dtd-version attribute on root.
   if the attribute is missing the default version is 1.2 :)
declare function e:get-version($xml){
  if ($xml//*:article/@dtd-version) then $xml//*:article/@dtd-version
  else '1.2'
};

declare function e:get-dtd($version,$type){
  let $cat := doc(file:base-dir()||'dtds/catalogue.xml')
  let $dtd-folder := file:base-dir()||'dtds/'||$type||'/'
  return
  switch ($type)
      case "publishing" return let $dtd-file := $cat//*:publishing/*:dtd[@version=$version]/@uri
                               return ($dtd-folder||$version||'/'||$dtd-file)
      case "authoring" return let $dtd-file := $cat//*:authoring/*:dtd[@version=$version]/@uri
                               return ($dtd-folder||$version||'/'||$dtd-file)
      (: default is archiving :)
      default return let $dtd-file := $cat//*:archiving/*:dtd[@version=$version]/@uri
                     return ($dtd-folder||$version||'/'||$dtd-file)
};

declare function e:dtd2json($report){
   if ($report//*:status/text() = 'valid') then json:parse('{"status": "valid"}')
   else json:parse(concat(
       '{"status": "invalid",',
       '"errors": [', 
       string-join(for $error in $report//*:message
                     return ('{'||
                            ('"line": "'||$error/@line/string()||'",')||
                            ('"column": "'||$error/@column/string()||'",')||
                            ('"message": "'||replace($error/data(),'"',"'")||'"')||
                            '}')
                   ,','),
       ']}'))
};

(: get Xpath from node. Used for Glencoe error messages :)
declare function e:getXpath($node as node()) {
  let $root := $node/ancestor::*[last()]/name()
  let $parents := ('/'||$root||'[1]/'|| string-join(
                     for $a in $node/ancestor::*[name()!=$root]
                     let $name := $a/name()
                     let $pos := count($a/parent::*/*[name()=$name]) - count($a/following-sibling::*[name()=$name])
                     return $name||'['||$pos||']','/'))
  
  let $pos :=  count($node/parent::*/*[name()=$node/name()]) - count($node/following-sibling::*[name()=$node/name()])
  let $self := ('/'||$node/name()||'['||$pos||']')
  return ($parents||$self)
};


(: HTML pages:)

declare
  %rest:path("/")
  %rest:GET
  %output:method("html")
function e:upload()
{
  let $script := <script src="../static/form.js" defer=""></script>
   
  return e:index($script,<div/>,<div/>)
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
                     <div id="popup">
                       <div id="popupMessage">
                         <div id="popup-icons">
                           <button class="close"><i class="ri-close-line"></i></button>
                         </div>
                       </div>
                      </div>
                      <div id="editor">
                        <textarea id="code">{serialize($xml,map{'method':'xml','indent':'yes'})}</textarea>
                      </div>
                      <div id="results">
                        <div class="table-scroll">
                        {e:dtd2result($xml),
                        e:svrl2result($svrl)}
                        </div>
                      </div>
                    </div>
  let $button := <button id="pubDateBtn" class="loader" hidden="">Validate Pub Date</button>
  let $scripts := (<link href="../static/codemirror/lib/codemirror.css" rel="stylesheet"/>,
                   <link href="../static/codemirror/addon/dialog/dialog.css" rel="stylesheet"/>,
                   <script src="../static/codemirror/lib/codemirror.js"></script>,
                   <script src="../static/codemirror/mode/xml/xml.js"></script>,
                   <script src="../static/codemirror/addon/search/jump-to-line.js"></script>,
                   <script src="../static/codemirror/addon/search/search.js"></script>,
                   <script src="../static/codemirror/addon/search/searchcursor.js"></script>,
                   <script src="../static/codemirror/addon/dialog/dialog.js"></script>,
                   <script src="../static/codemirror/addon/fold/xml-fold.js"></script>,
                   <script src="../static/codemirror/addon/edit/matchtags.js"></script>,
                   <script src="../static/form.js" defer=""></script>,
                   <script src="../static/editor.js" defer=""></script>)
                   
  return e:index($scripts,$button,$container)
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
                      <div id="popup">
                       <div id="popupMessage">
                         <div id="popup-icons">
                           <button class="close"><i class="ri-close-line"></i></button>
                         </div>
                       </div>
                      </div>
                      <div id="editor">
                        <textarea id="code">{serialize($xml,map{'method':'xml','indent':'yes'})}</textarea>
                      </div>
                      <div id="results">
                        <div class="table-scroll">
                        {e:dtd2result($xml),
                         if ($xml//*:media[@mimetype="video"]) then (e:svrl2result-video($xml,$svrl))
                         else e:svrl2result($svrl)}
                        </div>
                      </div>
                    </div>
  let $button := <button id="pubDateBtn" class="loader">Validate Pub Date</button>
  let $scripts := (<link href="../static/codemirror/lib/codemirror.css" rel="stylesheet"/>,
                   <link href="../static/codemirror/addon/dialog/dialog.css" rel="stylesheet"/>,
                   <script src="../static/codemirror/lib/codemirror.js"></script>,
                   <script src="../static/codemirror/mode/xml/xml.js"></script>,
                   <script src="../static/codemirror/addon/search/jump-to-line.js"></script>,
                   <script src="../static/codemirror/addon/search/search.js"></script>,
                   <script src="../static/codemirror/addon/search/searchcursor.js"></script>,
                   <script src="../static/codemirror/addon/dialog/dialog.js"></script>,
                   <script src="../static/codemirror/addon/fold/xml-fold.js"></script>,
                   <script src="../static/codemirror/addon/edit/matchtags.js"></script>,
                   <script src="../static/form.js" defer=""></script>,
                   <script src="../static/editor.js" defer=""></script>)
  
   return e:index($scripts,$button,$container)
};

declare function e:dtd2result($xml) as element(div) {
  let $version := e:get-version($xml)
  let $dtd := e:get-dtd($version,"archiving")
  let $report := validate:dtd-report($xml,$dtd)
  let $status := $report//*:status/text()
  let $image-name := if ($status="valid") then ("valid") else 'error'
  let $table := if ($status="valid") then ()
                else (<table><tbody>{
                  for $x at $p in $report//*:message[@level="Error"]
                  let $class := if ($p mod 2 = 0) then ('error even') else ('error odd')
                  return 
                  <tr class="{$class}" data-editor-line="{number($x/@line/string()) - 2}">
                    <td class="align-middle">
                      <input class="unticked" type="checkbox" value=""/>
                    </td>
                    <td class="message">{data($x)}</td>
                  </tr>
                }</tbody></table>)
  
  return <div id="dtd">
            <div class="status">
              <img src="{('../static/'||$image-name||'.svg')}" class="results-status"/>
              <span>DTD</span>
            </div>
            {$table}
         </div>
};

declare function e:svrl2result($svrl) as element(div) {
  let $image-name := if ($svrl//*[@role="error"]) then 'error'
                     else if ($svrl//*[@role="warning"]) then 'warning'
                     else if ($svrl//*[@role="info"]) then 'info'
                     else 'valid'
  let $table := <table>
    <thead>
      <tr>
        <th><img src="../static/arrows.svg"/></th>
        <th>Type</th>
        <th>ID</th>
        <th hidden="">XPath</th>
      <th>Message</th>
    </tr>    
    </thead>
    <tbody>{e:get-table-rows($svrl)}</tbody>
</table>
  
  return <div id="schematron">
          <div class="status">
            <img src="{('../static/'||$image-name||'.svg')}" class="results-status"/>
            <span>Schematron</span>
          </div>
          {$table}
        </div>
};

declare function e:svrl2result-video($xml,$svrl) as element(div)*
{
  let $doi := $xml//*:article-meta//*:article-id[@pub-id-type="doi"]/string()
  let $glencoe := e:get-glencoe($doi)
  let $glencoe-rows := e:get-glencoe-rows($glencoe,$xml) 
  let $table-rows := e:get-table-rows($svrl)       
  let $table := <table>
   <thead>
     <tr>
      <th><img src="../static/arrows.svg"/></th>
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
  
  let $image-name := if ($glencoe-rows//*:tr[@class="error"]) then 'error'
                     else if ($svrl//*[@role="error"]) then 'error'
                     else if ($svrl//*[@role="warning"]) then 'warning'
                     else if ($svrl//*[@role="info"]) then 'info'
                     else 'valid'
   
   return <div id="schematron">
            <div class="status">
              <img src="{('../static/'||$image-name||'.svg')}" class="results-status"/>
              <span>Schematron</span>
            </div>
            {$table}
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

declare function e:get-glencoe-rows($glencoe,$xml) as element(tr)* {
  if ($glencoe//*:error) then <tr class="error">
                                  <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                                  <td>Error</td>
                                  <td>unknown</td>
                                  <td class="xpath" hidden="">/article[1]</td>
                                  <td class="message">There is no Glencoe metadata for this article but it contains videos. Please esnure that the Glencoe data is correct.</td>
                                </tr>
                                
    else (for $vid in $xml//*:media[@mimetype="video"]
          let $id := $vid/@id
          return if ($glencoe/*[local-name()=$id and *:video__id[.=$id] and ends-with(*:solo__href,$id)]) then ()
          else <tr class="error">
                  <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                  <td>Error</td>
                  <td>unknown</td>
                  <td class="xpath" hidden="">{e:getXpath($vid)}</td>
                  <td class="message">{'There is no metadata in Glencoe for the video with id "'||$id||'".'}</td>
                </tr>)
};

declare
function e:index($scripts as element()*, $middle-header-elem as element(), $elem as element()*) as element(html) {
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <link rel="icon" type="image/png" sizes="32x32" href="../static/favicon-32x32.56d32e31.png"/>
    <link rel="preconnect" href="https://fonts.gstatic.com"/>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;700&amp;display=swap" rel="stylesheet"/>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css"/>
    <link href="https://cdn.jsdelivr.net/npm/remixicon@2.5.0/fonts/remixicon.css" rel="stylesheet"/>
    <link href="../static/styles.css" rel="stylesheet"/>
    {$scripts}
    <title>XML Validator</title>
</head>
  <body>
    <div id="root">
      <header>
        <div id="home-wrapper">
          <a href="/">
            <img src="static/elife.svg" class="img-thumbnail"/>
          </a>
          <h1>XML Validator</h1>
        </div>
        {$middle-header-elem}
        <form id="form1" method="POST" enctype="multipart/form-data">
          <div id="dropContainer" class="form-group">
              <i class="ri-upload-2-line"></i><span id="uploadStatus">Upload XML</span>
              <input id="files" type="file" name="xml" accept="application/xml"/>
          </div>
         <div id="buttons" class="form-group">
            <label>Schematron</label>
            <div>
              <button id="preBtn" class="loader" disabled="" formaction="/pre-result">Pre</button>
              <button id="finalBtn" class="loader" disabled="" formaction="/final-result">Final</button>
            </div>
          </div>
        </form>
      </header>
    {$elem}
    </div>
  </body>
</html>
};