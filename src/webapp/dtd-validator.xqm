module namespace dtd = 'dtd-validator';
import module namespace rest = "http://exquery.org/ns/restxq";

(: DTD :)

declare
  %rest:path("/dtd")
  %rest:POST("{$data}")
  %output:method("json")
function dtd:validate-dtd($data as item()+)
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
        let $version := dtd:get-version($xml)
        let $dtd := dtd:get-dtd($version,$type)
        let $report :=  validate:dtd-report($xml,$dtd)
        
        return dtd:dtd2json($report)
      ))  
    
    (: default is archiving if no type is provided :)
    else if ($param-count = 1) then (
      if (not($data[. instance of document-node()])) then 
          error(xs:QName("basex:error"),'An xml file must be supplied to validate') 
      else (
        let $xml := $data[. instance of document-node()]
        let $type := "archiving"
        let $version := dtd:get-version($xml)
        let $dtd := dtd:get-dtd($version,$type)
        let $report :=  validate:dtd-report($xml,$dtd)
        
        return dtd:dtd2json($report)
      )
    )
      
    else if ($param-count gt 2) then 
      error(xs:QName("basex:error"),'Too many parameters supplied: '||$param-count)
    
    else error(xs:QName("basex:error"),'An xml file must be supplied to validate')
};

(: get dtd version from dtd-version attribute on root.
   if the attribute is missing the default version is 1.3 :)
declare function dtd:get-version($xml){
  if (matches($xml//*:article/@dtd-version,'^1\.[0-3]d?[1-9]?$')) then $xml//*:article/@dtd-version
  else '1.4'
};

declare function dtd:get-dtd($version,$type){
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

declare function dtd:dtd2json($report){
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

declare function dtd:dtd2result($xml) as element(div) {
  let $version := dtd:get-version($xml)
  let $dtd := dtd:get-dtd($version,"archiving")
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
