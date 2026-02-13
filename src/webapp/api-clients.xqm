module namespace api = 'api-clients';
import module namespace util = 'utilities' at 'utilities.xqm';

declare function api:get-glencoe($doi){
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

declare function api:get-assessment-terms-from-api($id){
  let $json := try {
    http:send-request(
      <http:request method='get' href="{('https://api.elifesciences.org/reviewed-preprints/'||$id)}" timeout='2'>
        <http:header name="User-Agent" value="basex-validator"/>
      </http:request>)//*:json}
    (: Return error for timeout :)
    catch * { json:parse('{"error": "timeout"}') }
  return <terms>{
            for $x in $json/*:elifeAssessment/*[local-name()=('significance','strength')]
            let $type := $x/local-name()
            order by $type
            let $terms :=  for $term in $x/*
                           let $rank := util:assessment-term-to-number($term)
                           return <term rank="{$rank}">{data($term)}</term>
            let $rank := sum(for $term in $terms return number($term/@rank))
            return element {$type} {attribute {'rank'} {$rank}, $terms}
        }</terms>
};

declare function api:get-preprint-rows($event as element()*, $is-prc as xs:boolean) as element(tr)* {
  let $iso-xml-date := $event/*:date/@iso-8601-date
  let $preprint-link := $event/*:self-uri[@content-type="preprint"]/@*:href
  let $doi := if (matches($preprint-link,'^https://doi.org/')) then (replace($preprint-link,'^https://doi.org/','')) 
              else $preprint-link
  let $response := if (matches($doi,'^10\.\d{4,9}/[-._;()/:A-Za-z0-9&lt;&gt;\+#&amp;&apos;`~–−]+$')) then api:get-doi-api-res($doi,$is-prc)
                   else <res status="Not sent" message="{($doi||' is not a proper doi, so the preprint pub date cannot be verified.')}" iso-date=""/>
  let $source := $response/@source/string()
  let $iso-date := $response/@iso-date
  return switch($response/@status)
           case "200" return (
                  if ($iso-date='') then (
                    <tr class="info odd">
                           <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                           <td>Warning</td>
                           <td>preprint-doi-date</td>
                           <td class="xpath" hidden="">/article[1]/front[1]/article-meta[1]/pub-history[1]/event[1]</td>
                           <td class="message">{("Preprint is registered at "||$source||" but they do not have a full published date in the metadata. Check the date of the preprint here: ",<a href="{'https://doi.org/'||$doi}" target="_blank">{$doi}</a>," to see if it matches the XML date: "||$iso-xml-date||".")}</td>
                       </tr>
                  )
                  else if ($iso-date=$iso-xml-date) then (
                        <tr class="info odd">
                           <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                           <td>Info</td>
                           <td>preprint-doi-date</td>
                           <td class="xpath" hidden="">/article[1]/front[1]/article-meta[1]/pub-history[1]/event[1]</td>
                           <td class="message">{("Preprint date in the XML ("||$iso-date||") matches the details registered at "||$source||".")}</td>
                       </tr>
                      )
                  else if ($response/@is-warning="true" and $iso-date!=$iso-xml-date) then (
                         <tr class="warning odd">
                           <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                           <td>Warning</td>
                           <td>preprint-doi-date</td>
                           <td class="xpath" hidden="">/article[1]/front[1]/article-meta[1]/pub-history[1]/event[1]</td>
                           <td class="message">{("Preprint date in the XML does not match the latest indexed version at "||$source||". Is this correct? (it may be correct, as the latest indexed version may not be the version that was submitted)? The XML has '"||$iso-xml-date||"' whereas "||$source||" has '"||$iso-date,"'. (",<a href="{'https://doi.org/'||$doi}" target="_blank">{$doi}</a>,")")}</td>
                         </tr>
                  )
                  else (<tr class="error odd">
                         <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                         <td>Error</td>
                         <td>preprint-doi-date</td>
                         <td class="xpath" hidden="">/article[1]/front[1]/article-meta[1]/pub-history[1]/event[1]</td>
                         <td class="message">{("Preprint date in the XML does not match the details at "||$source||". XML has '"||$iso-xml-date||"' whereas "||$source||" has '"||$iso-date,"'. (",<a href="{'https://doi.org/'||$doi}" target="_blank">{$doi}</a>,")")}</td>
                       </tr>)
         )
         case "404" return (
           <tr class="warning odd">
             <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
             <td>Warning</td>
             <td>preprint-doi-date</td>
             <td class="xpath" hidden="">/article[1]/front[1]/article-meta[1]/pub-history[1]/event[1]</td>
             <td class="message">{("Preprint DOI '",<a href="{'https://doi.org/'||$doi}" target="_blank">{$doi}</a>,"' not found at crossref or datacite. Is it correct? Some preprint servers use separate DOI minting services.")}</td>
       </tr>
         )
         default return (<tr class="warning odd">
                           <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                           <td>Warning</td>
                           <td>preprint-doi-date</td>
                           <td class="xpath" hidden="">/article[1]/front[1]/article-meta[1]/pub-history[1]/event[1]</td>
                           <td class="message">{("Something went wrong with the request for preprint details from "||$source||". Status: "||$response/@status/string()||" Message: "||$source)}</td>
                         </tr>)
};

declare function api:get-doi-api-res($doi as xs:string, $is-prc as xs:boolean) as element(res){
  (: Try crossref head-only first :)
  let $is-warning := if ($is-prc) then 'true' else 'false'
  let $head-res := try{http:send-request(<http:request method="get" href="{'https://api.crossref.org/works/'||web:encode-url($doi)||'?mailto:production@elifesciences.org'}" status-only="true"/>)}
                   catch * {<http:response status="{('basex code: '||$err:code)}" message="{$err:description}" source="basex"/>}
  let $status := $head-res/@status/string()
  return if ($status="200") then (
                        let $json := try{http:send-request(<http:request method="get" href="{'https://api.crossref.org/works/'||web:encode-url($doi)||'?mailto:production@elifesciences.org'}" timeout="1"/>)}
                                     catch * {<json err-code="{$err:code}" err-desc="{$err:description}"><posted><date-parts><_>1970</_><_>01</_><_>01</_></date-parts></posted><accepted><date-parts><_>1970</_><_>01</_><_>01</_></date-parts></accepted></json>}
                        let $date-parts := if ($is-prc) then ($json//*:json//*:accepted/*:date-parts/_)
                                           else $json//*:json//*:posted/*:date-parts/_
                        let $iso-date := string-join(for $t at $p in $date-parts/_ 
                                           order by $p ascending 
                                           return if (string-length($t)=1) then '0'||$t
                                                  else $t
                                           ,'-')
                        return if ($json/@err-code) then <res status="{('basex code: '||$json/@err-code/string())}" message="{$json/@err-code/string()}" source="basex"/>
                               else <res status="{$status}" is-warning="{$is-warning}" message="{$json/@message/string()}" iso-date="{$iso-date}" source="crossref"/>
                        )
        else if ($status="404") then (
          (: If not found at Crossref, then try DataCite :)
          let $head-res := try {http:send-request(<http:request method="get" href="{'https://api.datacite.org/dois/'||web:encode-url($doi)}" timeout="1" status-only="true"/>)}
                        catch * {<http:response status="{('basex code: '||$err:code)}" message="{$err:description}"/>}
           let $status := $head-res/@status/string()
           return if ($status="200") then (
               (: If found at DataCite :)
               let $json := try {http:send-request(<http:request method="get" href="{'https://api.datacite.org/dois/'||web:encode-url($doi)}" timeout="2"/>)}
                            catch * {<json err-code="{$err:code}" err-desc="{$err:description}"><dates><_><date>1970-01-01T</date><dateType>Submitted</dateType></_></dates></json>}
               let $date := if ($is-prc) then ($json//*:dates/_[dateType='Submitted'][last()]/date/substring-before(.,'T'))
                            else $json//*:dates/_[dateType='Submitted'][1]/date/substring-before(.,'T')
               return if ($json/@err-code) then <res status="{('basex code: '||$json/@err-code/string())}" message="{$json/@err-code/string()}" source="basex"/>
                      else if (matches($date,'\d{4}-\d{2}-\d{2}')) 
                         then <res status="{$status}" message="{$head-res/@message/string()}" is-warning="{$is-warning}" iso-date="{$date}" source="dataCite"/>
                      else <res status="{$status}" message="{$head-res/@message/string()}" iso-date="" source="dataCite"/>
                  )
                  (: If not found at DataCite or there was some other error :)
                  else <res status="{$status}" message="{$head-res/@message/string()}" iso-date="" source="dataCite"/>
            )
        (: Some other error at Crossref :)
        else <res status="{$status}" message="{$head-res/@message/string()}" iso-date="" source="crossref"/>
};

declare function api:get-assessment-rows($xml) as element(tr)* {
  let $id := $xml//*:article//*:article-id[@pub-id-type="publisher-id"]/data()
  let $prev-terms := api:get-assessment-terms-from-api($id)
  let $prev-terms-set := distinct-values($prev-terms//*:term)
  let $curr-terms := util:get-assessment-terms-from-xml($xml)
  let $curr-terms-set := distinct-values($curr-terms//*:term)
  return if (count($prev-terms-set) = count($curr-terms-set) 
              and (every $item in $prev-terms-set satisfies $item = $curr-terms-set))
            then (<tr class="info odd">
                   <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
                   <td>Info</td>
                   <td>assessment-comparison</td>
                   <td class="xpath" hidden="">/article[1]</td>
                   <td class="message">Assessment terms are the same as the most recently published Reviewed Preprint</td>
             </tr>)
         else (
           <tr class="warning odd">
             <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
             <td>Warning</td>
             <td>assessment-comparison</td>
             <td class="xpath" hidden="">/article[1]/sub-article[1]/front-stub[1]/kwd-group[1]</td>
             <td class="message">The Assessment terms in this VOR are not the same as those in the most recently published Reviewed preprint. Is that correct? VOR: {string-join($curr-terms-set,'; ')}. RP: {string-join($prev-terms-set,'; ')}.</td>
             </tr>
         )
};

declare function api:get-ror-rows($xml) as element(tr)* {
  let $non-ror-count := count($xml//*:aff[not(institution-wrap[*:institution-id]) and descendant::institution and (ancestor::*:article-meta or ancestor::*:contrib[@contrib-type="reviewer"] or ancestor::*:contrib[@contrib-type="author" and role[@specific-use="referee"]])])
  let $isEvenTotal := $non-ror-count mod 2 = 0
  (: If there are <= 100 affiliations without RORs :)
  return if ($non-ror-count le 100) then (
    let $ror-client-id := fn:environment-variable('ROR_CLIENT_ID')
    for $result at $pos in (
      for $aff in $xml//*:aff[not(institution-wrap[*:institution-id]) and descendant::institution and (ancestor::*:article-meta or ancestor::*:contrib[@contrib-type="reviewer"] or ancestor::*:contrib[@contrib-type="author" and role[@specific-use="referee"]])]
      let $xpath := util:getXpath($aff)
      let $display := string-join($aff/descendant::*[not(local-name()=('label','institution-id','institution-wrap','named-content'))],', ')
      let $json := try {
                 http:send-request(
                 <http:request method='get' href="{('https://api.ror.org/v2/organizations?affiliation='||web:encode-url($display)||'&amp;single_search')}" timeout='2'>
                   <http:header name="Client-Id" value="{$ror-client-id}"/>
                 </http:request>)//*:json}
               catch * {<json><number__of__results>0</number__of__results></json>}
      let $results := api:extract-ror-matches($json)
      let $message := if ($json//*:number__of__results[@flag="error"]) then ' There was an error fetching possible matches from the ROR API.'
                      else api:generate-ror-td-message($results)
      return <wrap>
               <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
               <td>Warning</td>
               <td>ror-api-check</td>
               <td class="xpath" hidden="">{$xpath}</td>
               <td class="message">The affiliation {$display} does not have a ROR ID.{$message}</td>
             </wrap>)
    (: get the correct colour for the row based on the number of results returned.
     since these are placed ontop of existing schematron results:
      even total = odd, even, odd etc.
      odd total = even, odd, even etc. :)
    let $isEven := $pos mod 2 = 0
    let $type := if ($isEvenTotal) then (
                  if ($isEven) then 'even'
                  else 'odd'
               )
               else (
                 if ($isEven) then 'odd'
                 else 'even' 
               )
    return <tr class="{'warning '||$type}">{$result/*}</tr>
  )
  (: If there are > 100 affiliations without RORs :)
  else <tr class="info odd">
         <td class="align-middle"><input class="unticked" type="checkbox" value=""/></td>
         <td>Info</td>
         <td>ror-api-check</td>
         <td class="xpath" hidden="">/article[1]</td>
         <td class="message">{'Too many affiliations without ROR ids ('||$non-ror-count||') to check against the ROR API'}</td>
       </tr>
};

declare function api:introduce-rors($xml as item()) {
  let $ror-client-id := fn:environment-variable('ROR_CLIENT_ID')
  let $node := if ($xml[.instance of xs:string]) then parse-xml($xml)
               else $xml
  let $new-xml := 
    copy $copy := $node
    modify(
      for $aff in $copy//*:article-meta//*:aff[not(descendant::*:institution-id[@institution-id-type="ror"]) and *:institution]
      let $display := string-join($aff/node()[not(local-name()=('label','institution-id','institution-wrap'))],'')
      let $json := try {
                 http:send-request(
                 <http:request method='get' href="{('https://api.ror.org/v2/organizations?affiliation='||web:encode-url($display)||'&amp;single_search')}" timeout='2'>
                   <http:header name="Client-Id" value="{$ror-client-id}"/>
                 </http:request>)//*:json}
               catch * {<json><number__of__results>0</number__of__results></json>}
      let $results := api:extract-ror-matches($json)
      return if (not(exists($results))) then ()
      else (
        let $institution-wrap := api:generate-ror-institution-wrap($results,$aff)
        return replace node $aff/*:institution[1] with $institution-wrap
       ),
       
       for $funding-source in $copy//*:article-meta/*:funding-group//*:funding-source[not(descendant::*:institution-id[@institution-id-type="ror"]) and not(normalize-space(*:named-content[@content-type="funder-id"])!='')]
       let $query-content := if ($funding-source//*:institution-id[@institution-id-type="FundRef"])
                            then tokenize($funding-source//*:institution-id[@institution-id-type="FundRef"],'/')[last()]
                            else normalize-space($funding-source/text()[matches(.,'\S')][1])
       let $query := if ($funding-source//*:institution-id[@institution-id-type="FundRef"])
                           then 'query='||$query-content
                     else 'affiliation='||web:encode-url($query-content)
       let $json := try {
                 http:send-request(
                 <http:request method='get' href="{('https://api.ror.org/v2/organizations?'||$query)}" timeout='2'>
                   <http:header name="Client-Id" value="{$ror-client-id}"/>
                 </http:request>)//*:json}
               catch * {<json><number__of__results>0</number__of__results></json>}
        let $results := api:extract-ror-matches($json)
        return if (not(exists($results))) then ()
        else (
          let $inner-node := if ($funding-source//*:institution) then $funding-source//*:institution
                             else $query-content
          let $institution-wrap := api:generate-ror-institution-wrap($results,$inner-node)
          return replace node $funding-source with 
                 <funding-source>{('&#xa;',$institution-wrap,'&#xa;')}</funding-source>
               )
    )
    return $copy
  return $new-xml
};

declare function api:extract-ror-matches($response as item()) as element()* {
  if (number($response//*:number__of__results) = 0) then ()
  else if ($response//*:items/_[*:chosen='true']) then $response//*:items/_[*:chosen='true']
  (: Assumes the ROR 'query' param is used :)
  else if (number($response//*:number__of__results) = 1 and $response//*:items/_[not(*:score)])
      then $response//*:items/_
  else (for $result in $response//*:items/_[number(*:score[1]) ge 0.8]
        order by $result/*:score[1] descending
        return $result)[position() lt 4]
};

declare function api:generate-ror-institution-wrap($results as item()*, $node as item()) as element(){
  <institution-wrap>{
    for $result at $p in $results
    return (
      if (not($result/*:organization)) then (
        '&#xa;',
        <institution-id institution-id-type="ror">{$result/*:id/data()}</institution-id>,
        '&#xa;'
      )
    else (
      let $option := if ($result/*:chosen='true') then 'Chosen option'
                     else 'Option '||$p
      let $score := if ($result[not(*:chosen='true')]/*:score) 
                        then 'Closeness score = '||$result/*:score[1]/data()||' | '
                    else ()
      let $org := if (not($result/*:organization)) then $result
                  else $result/*:organization
      let $name := $org/*:names/_[*:types/*='ror_display'][1]/*:value[1]/data()
      let $cities := string-join($org/*:locations//*:name,'; ')
      let $countries := string-join($org/*:locations//*:country__name,'; ')
      let $ror-id := $org/*:id/data()
      let $comment := comment {$option||': '||$score||'Name = '||$name||' | Cities = '||$cities||' | Countries = '||$countries}
      return ('&#xa;',
            $comment,
            '&#xa;',
            <institution-id institution-id-type="ror">{$ror-id}</institution-id>
          )
       )
     ),
     if ($node instance of text() or $node instance of xs:string) then <institution>{$node}</institution>
     else if ($node instance of element(institution)) then $node
     else if ($node instance of element(aff)) then $node/institution[1]
     else ()
   }</institution-wrap>
};

declare function api:generate-ror-td-message($results as item()*) as item()* {
    if (not(exists($results))) then (' No (confident) ROR ID matches have been found.')
    else (
        let $result-display := 
                for $res in $results
                let $id := if ($res/*:organization) then $res/*:organization/*:id
                           else $res/*:id
                let $name := if ($res/*:organization) then $res/*:organization/*:names/_[*:types/*='ror_display'][1]/*:value[1]/data()
                             else $res/*:names/_[*:types/*='ror_display'][1]/*:value[1]/data()
                let $a := <a href="{$id}" target="_blank">{$name}</a>
                let $score := if ($res[not(*:chosen='true')]/*:score) then '(Closeness score '||$res/*:score[1]||')'
                              else '(Chosen match)' 
                return ($a,' ',$score,' ')
        return (' However possible ROR IDs are: ',$result-display)
    ) 
};