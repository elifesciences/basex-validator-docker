module namespace e = 'http://elifesciences.org/modules/validate';
import module namespace session = "http://basex.org/modules/session";
import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace schematron = "http://github.com/Schematron/schematron-basex";
declare namespace svrl = "http://purl.oclc.org/dsdl/svrl";


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

(: get jats dtd version from dtd-version attribute on root.
   if the attribute is missing the default version is 1.3 :)
declare function e:get-version($xml){
  if (matches($xml//*:article/@dtd-version,'^1\.[0-3]d?[1-9]?$')) then $xml//*:article/@dtd-version
  else '1.3'
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

(: SCHEMATRON :)

declare
  %rest:path("/schematron")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("json")
function e:validate-pre($xml)
{
  let $schema := doc('./schematron/example.sch')
  let $sch := schematron:compile($schema)
  let $svrl :=  e:validate($xml,$sch)
  return e:svrl2json($svrl)
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
  let $status := if ($svrl//*[@role="error"]) then "invalid" else "valid"   
  let $json :=  
    concat(
      '{"status":"',$status,'",
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

declare function e:validate($xml,$schema){
  try {schematron:validate($xml, $schema)}
  (: Return psuedo-svrl to output error message for fatal xslt errors :)
  catch * { <schematron-output><successful-report id="validator-broken" location="unknown" role="error"><text>{'Error [' || $err:code || ']: ' || $err:description}</text></successful-report></schematron-output>}
};

(: HTML PAGES :)

declare
  %rest:path("/")
  %rest:GET
  %output:method("html")
  %output:html-version("5.0")
function e:upload()
{
  let $script := <script src="../static/form.js" defer=""></script>
   
  return e:index($script,<div/>,<div/>)
};

declare
  %rest:path("/validate")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("html")
  %output:html-version("5.0")
function e:validate-pre-result($xml)
as element(html)
{  
  let $schema := doc('./schematron/example.sch')
  let $sch := schematron:compile($schema)
  let $svrl :=  e:validate($xml,$sch)
  
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
                      <div id="resizer"></div>
                      <div id="results">
                        <div class="table-scroll">
                        {e:dtd2result($xml),
                        e:svrl2result($xml,$svrl)}
                        </div>
                      </div>
                    </div>
  let $button := <button id="pubDateBtn" class="loader" hidden="">Check published data</button>
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
                   <script src="../static/editor.js" defer=""></script>,
                   <script src="../static/resizer.js" defer=""></script>)
                   
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

declare function e:svrl2result($xml,$svrl) as element(div) {
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
              <button id="preBtn" class="loader" disabled="" formaction="/validate">Validate</button>
            </div>
          </div>
        </form>
      </header>
    {$elem}
    </div>
  </body>
</html>
};