module namespace svrl = 'svrl-converter';
import module namespace api = 'api-clients' at 'api-clients.xqm';
import module namespace util = 'utilities' at 'utilities.xqm';

declare function svrl:svrl2json($xml,$svrl)
{ 
  let $assessment-warnings := util:get-assessment-terms-warning-json($xml)
  let $errors :=
      concat(
         '"errors": [',
         string-join(
         for $error in $svrl//*[@role="error"]
         return concat(
                '{',
                ('"path": "'||$error/@location/string()||'",'),
                ('"type": "'||$error/@role/string()||'",'),
                ('"message": "'||util:get-message($error)||'"'),
                '}'
              )
          ,','),
        ']'
      )
  let $warnings := 
     concat(
         '"warnings": [',
         string-join(
           ($assessment-warnings,
           for $warn in $svrl//*[@role=('info','warning','warn')]
           return concat(
                '{',
                ('"path": "'||$warn/@location/string()||'",'),
                ('"type": "'||$warn/@role/string()||'",'),
                ('"message": "'||util:get-message($warn)||'"'),
                '}'
              )
          ),','),
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
declare function svrl:svrl2json-final($xml,$svrl){
  let $assessment-warnings := util:get-assessment-terms-warning-json($xml)
  let $doi := $xml//*:article-meta//*:article-id[@pub-id-type="doi" and not(@specific-use)]/string()
  let $glencoe := api:get-glencoe($doi)
  let $glencoe-errors := 
  string-join(
           if ($glencoe//*:error) then ('{"path": "unknown", "type": "error", "message": "There is no Glencoe metadata for this article but it contains videos. Please ensure that the Glencoe data is correct."}')
         else (
           for $vid in $xml//*:media[@mimetype="video"]
           let $id := $vid/@id
           return if ($glencoe/*[local-name()=$id and *:video__id[.=$id] and ends-with(*:solo__href,$id)]) then ()
           else concat(
                '{',
                ('"path": "unknown",'),
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
                ('"message": "'||util:get-message($error)||'"'),
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
         ($assessment-warnings,
         for $warn in $svrl//*[@role=('info','warning','warn')]
         return concat(
                '{',
                ('"path": "'||$warn/@location/string()||'",'),
                ('"type": "'||$warn/@role/string()||'",'),
                ('"message": "'||util:get-message($warn)||'"'),
                '}'
              )
        ),','),
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

declare function svrl:svrl2result($xml,$svrl) as element(div) {
  let $is-prc := util:is-prc($xml)
  let $preprint-event := $xml//*:article-meta/*:pub-history/*:event[*:self-uri[@content-type="preprint" and @*:href!='']][1]
  let $preprint-rows := if ($preprint-event) then api:get-preprint-rows($preprint-event,$is-prc) else ()
  let $assessment-rows := if ($is-prc) then api:get-assessment-rows($xml) else()
  let $ror-rows := api:get-ror-rows($xml)
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
    <tbody>{$preprint-rows,$assessment-rows,$ror-rows,svrl:get-table-rows($svrl)}</tbody>
</table>
  
  let $image-name := if ($table//*:tr[contains(@class,'error')]) then "error"
                     else if ($table//*:tr[contains(@class,'warning')]) then "warning"
                     else if ($table//*:tr[contains(@class,'info')]) then "info"
                     else "valid"
  return <div id="schematron">
          <div class="status">
            <img src="{('../static/'||$image-name||'.svg')}" class="results-status"/>
            <span>Schematron</span>
          </div>
          {$table}
        </div>
};

declare function svrl:svrl2result-video($xml,$svrl) as element(div)*
{
  let $is-prc := util:is-prc($xml)
  let $doi := $xml//*:article-meta//*:article-id[@pub-id-type="doi" and not(@specific-use)]/string()
  let $glencoe := api:get-glencoe($doi)
  let $glencoe-rows := svrl:get-glencoe-rows($glencoe,$xml)
  let $preprint-event := $xml//*:article-meta/*:pub-history/*:event[*:self-uri[@content-type="preprint"]]
  let $preprint-rows := if ($preprint-event) then api:get-preprint-rows($preprint-event,$is-prc) else ()
  let $assessment-rows := if ($is-prc) then api:get-assessment-rows($xml) else()
  let $ror-rows := api:get-ror-rows($xml)
  let $table-rows := svrl:get-table-rows($svrl)       
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
     {($glencoe-rows,$preprint-rows,$assessment-rows,$ror-rows,$table-rows)}
   </tbody>
</table>
  
  let $image-name := if ($table//*:tr[contains(@class,'error')]) then "error"
                     else if ($table//*:tr[contains(@class,'warning')]) then "warning"
                     else if ($table//*:tr[contains(@class,'info')]) then "info"
                     else "valid"
   
   return <div id="schematron">
            <div class="status">
              <img src="{('../static/'||$image-name||'.svg')}" class="results-status"/>
              <span>Schematron</span>
            </div>
            {$table}
          </div>
};

declare function svrl:get-table-rows($svrl) as element(tr)* {
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

declare function svrl:get-glencoe-rows($glencoe,$xml) as element(tr)* {
  if ($glencoe//*:error) then <tr class="error">
                                  <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                                  <td>Error</td>
                                  <td>unknown</td>
                                  <td class="xpath" hidden="">/article[1]</td>
                                  <td class="message">There is no Glencoe metadata for this article but it contains videos. Please ensure that the Glencoe data is correct.</td>
                                </tr>
                                
    else (for $vid in $xml//*:media[@mimetype="video"]
          let $id := $vid/@id
          return if ($glencoe/*[local-name()=$id and *:video__id[.=$id] and ends-with(*:solo__href,$id)]) then ()
          else <tr class="error">
                  <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                  <td>Error</td>
                  <td>unknown</td>
                  <td class="xpath" hidden="">{util:getXpath($vid)}</td>
                  <td class="message">{'There is no metadata in Glencoe for the video with id "'||$id||'".'}</td>
                </tr>)
};
