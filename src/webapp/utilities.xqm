module namespace util = 'http://elifesciences.org/modules/utilities';
import module namespace api = 'http://elifesciences.org/modules/api-clients';

declare function util:json-escape($string){
  normalize-space(replace(replace($string,'\\','\\\\'),'"','\\"'))
};

declare function util:get-message($node){
  if ($node[@see]) then util:json-escape((data($node)||' '||$node/@see))
  else util:json-escape(data($node))
};

declare function util:is-prc($xml) as xs:boolean{
  if ($xml//*:article[1]//*:article-meta/*:custom-meta-group/*:custom-meta[*:meta-name='publishing-route']/*:meta-value='prc') then true()
  else false()
};

declare function util:get-assessment-terms-from-xml($xml){
  <terms>{
    for $kwd-group in $xml//*:sub-article[@article-type="editor-report"]/*:front-stub/*:kwd-group
    let $type := if ($kwd-group/@kwd-group-type="evidence-strength") then 'strength' else 'significance'
    order by $type
    let $terms :=  for $term in $kwd-group/*:kwd
                   let $rank := util:assessment-term-to-number($term)
                   return <term rank="{$rank}">{lower-case(data($term))}</term>
    let $rank := sum(for $term in $terms return number($term/@rank))
    return element {$type} {attribute {'rank'} {$rank}, $terms}
  }</terms>
};

declare function util:assessment-term-to-number($term){
    switch (lower-case($term))
        (: Strength :)
        case "inadequate" return -2
        case "incomplete" return -1
        case "solid" return 1
        case "convincing" return 2
        case "compelling" return 3
        case "exceptional" return 4
        (: Significance :)
        case "useful" return 1
        case "valuable" return 2
        case "important" return 3
        case "fundamental" return 4
        case "landmark" return 5
        default return -9
};

declare function util:get-assessment-terms-warning-json($xml){
  let $id := $xml//*:article//*:article-id[@pub-id-type="publisher-id"]/data()
  let $prev-terms := api:get-assessment-terms-from-api($id)
  let $prev-terms-set := distinct-values($prev-terms//*:term)
  let $curr-terms := util:get-assessment-terms-from-xml($xml)
  let $curr-terms-set := distinct-values($curr-terms//*:term)
  return
  (:vor:)
  if ($xml//*:article-version[@article-version-type="publication-state"]='version of record') then (
      if (count($prev-terms-set) = count($curr-terms-set) and (every $item in $prev-terms-set satisfies $item = $curr-terms-set)) then concat(
                '{',
                ('"path": "\/article[1]\/sub-article[1]\/front-stub[1]\/kwd-group[1]",'),
                ('"type": "warning",'),
                ('"message": "The Assessment terms in this VOR are not the same as those in the most recently published Reviewed preprint. Is that correct? VOR: '||string-join($curr-terms-set,'; ')||'. RP: '||string-join($prev-terms-set,'; ')||'."'),
                '}'
              )
      else ()
    )
  (:Revised reviewed preprint:)
  else if (matches($xml//*:article-meta/*:article-id[@pub-id-type="doi" and @specific-use="version"][1],'[2-9]$')) then (
    if ((number($prev-terms/*:strength/@rank) gt number($curr-terms/*:strength/@rank)) or (number($prev-terms/*:significance/@rank) gt number($curr-terms/*:significance/@rank)))
    then concat(
                '{',
                ('"path": "\/article[1]\/sub-article[1]\/front-stub[1]\/kwd-group[1]",'),
                ('"type": "warning",'),
                ('"message": "The Assessment terms in this Revised Reviewed Preprint are lower than those in the previous version. Is that correct? Current: '||string-join($curr-terms-set,'; ')||'. Previous: '||string-join($prev-terms-set,'; ')||'."'),
                '}'
              )
  )
};

(: get Xpath from node. Used for Glencoe error messages :)
declare function util:getXpath($node as node()) {
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

declare function util:strip-preamble($xml as xs:string){
  if (contains($xml,'<!DOCTYPE'))
    then ('<article'||substring-after($xml,'<article'))
  else ($xml)
};
