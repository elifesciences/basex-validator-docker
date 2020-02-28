module namespace e = 'http://elifesciences.org/modules/validate';
import module namespace session = "http://basex.org/modules/session";
import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace schematron = "http://github.com/Schematron/schematron-basex";
declare namespace svrl = "http://purl.oclc.org/dsdl/svrl";


declare
  %rest:path("/schematron/pre")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("json")
function e:validate-pre($xml)
{
  let $schema := doc('./schematron/pre-JATS-schematron.sch')
  let $sch := schematron:compile(e:update-refs($schema,$schema/base-uri()))
  let $svrl :=  e:validate($xml, $sch)
  
  return e:svrl2json($svrl)
  
};


declare
  %rest:path("/schematron/final")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("json")
function e:validate-final($xml)
{
  let $schema := doc('./schematron/final-JATS-schematron.sch')
  let $sch := schematron:compile(e:update-refs($schema,$schema/base-uri()))
  let $svrl :=  e:validate($xml, $sch)
  
  return e:svrl2json($svrl)
  
};

declare
  %rest:path("/schematron")
  %rest:GET
  %output:method("html")
function e:upload()
{
  let $div := 
   <div class="container">
    <div class="col-sm-2">
        <a href="/schematron">
            <img src="static/elife.jpg" class="img-thumbnail"/>
        </a>
    </div>
    <div class="col-md-10">
        <h3>Schematron validator</h3>
        <form id="form1" action="/schematron/pre" method="POST" enctype="multipart/form-data">
            <div class="row justify-content-start">
                <div class="form-group">
                    <label for="InputFiles" class="col-md-3 control-label">Select files</label>
                    <div class="col-md-3">
                         <input type="file" name="xml" accept="application/xml"/>
                    </div>
                </div>
            </div>
            <div class="row justify-content-start">
                <div class="form-group">
                    <label class="col-md-3">Choose Schematron</label>
                    <div class="col-md-4">
                        <input type="submit" value="Pre"/>
                        <input type="submit" formaction="/schematron/final" value="Final"/>
                    </div>
                </div>
            </div>
        </form>
    </div>
</div>
    
    return e:template($div)
    
};


declare function e:svrl2json($svrl){
  
  let $errors :=
      concat(
         '"errors": [',
         string-join(
         for $error in $svrl//*[@role="error"]
         return concat(
                '{',
                ('"path": "'||$error/@location/string()||'",'),
                ('"type": "'||$error/@role/string()||'",'),
                ('"message": "'||e:json-escape($error/*:text[1]/data())||'"'),
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
                ('"message": "'||e:json-escape($warn/*:text[1]/data())||'"'),
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

declare function e:update-refs($schema,$path2schema){
  let $filename := tokenize($path2schema,'/')[last()]
  let $folder := substring-before($path2schema,$filename)
  let $external-variables := distinct-values(
                      for $x in $schema//*[@test[contains(.,'document(')]]
                      let $variable := substring-before(substring-after($x/@test,'document($'),')')
                      return $variable
                    )
  return
  copy $copy := $schema
                modify(
                  for $x in $copy//*:let[@name=$external-variables]
                  return replace value of node $x/@value with concat("'",$folder,replace($x/@value/string(),"'",''),"'")
                )
                return $copy
  
};

declare function e:validate($xml,$schema){
  
  try {schematron:validate($xml, $schema)}
  (: Return psuedo-svrl to output error message for fatal xslt errors :)
  catch * { <schematron-output><successful-report id="validator-broken" location="unknown" role="error"><text>{'Error [' || $err:code || ']: ' || $err:description}</text></successful-report></schematron-output>}
};

declare
function e:template($div as element(div))
as element(html) 
{
  <html lang="en">
  <head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"/>

  <link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css' integrity='sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u' crossorigin='anonymous'/>
  <link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap-theme.min.css' integrity='sha384-rHyoN1iRsVXV4nD0JutlnGaslCJuC7uwjduW9SVrLvRYooPp2bWYgmgJQIXwl/Sp' crossorigin='anonymous'/>

  <title>Schematron Validator</title>
  </head>
  <body>
  {$div}
   <script src="https://code.jquery.com/jquery-3.4.1.slim.min.js" integrity="sha384-J6qa4849blE2+poT4WnyKhv5vZF5SrPo0iEjwBvKU7imGFAV0wwj1yYfoRSJoZ+n" crossorigin="anonymous"></script>
   <script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js" integrity="sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo" crossorigin="anonymous"></script>
   <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js" integrity="sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6" crossorigin="anonymous"></script>
  </body>
</html>
};