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

declare
  %rest:path("/schematron")
  %rest:GET
  %output:method("html")
function e:upload()
{
  let $div := 
  <div class="col-12">
            <form id="form1" method="POST" enctype="multipart/form-data" onSubmit="disableBtn()">
                <div class="row justify-content-start">
                    <div class="form-group col-10">
                        <label for="InputFiles" class="col-md-2 control-label">Select file:</label>
                        <input type="file" name="xml" accept="application/xml"/>
                    </div>
                </div>
                <div class="form-group">
                    <label class="col-2">Schematron:</label>
                    <button id="preBtn" class="btn btn-primary" onclick="addSpinner(event)" type="submit" formaction="/schematron/pre-table">Pre</button>
                    <button id="finalBtn" class="btn btn-primary" onclick="addSpinner(event)" type="submit" formaction="/schematron/final-table">Final</button>
                </div>
            </form>
        </div> 
    
  return e:template($div) 
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

declare
  %rest:path("/schematron/pre-table")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("html")
function e:validate-pre-table($xml)
as element(html)
{
  let $xsl := doc('./schematron/pre-JATS-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  let $rows :=  e:svrl2table-rows($svrl)
  return e:template(e:table-template($rows))
};

declare
  %rest:path("/schematron/final-table")
  %rest:POST("{$xml}")
  %input:text("xml","encoding=UTF-8")
  %output:method("html")
function e:validate-final-table($xml)
as element(html)
{
  let $xsl := doc('./schematron/final-JATS-schematron.xsl')
  let $svrl :=  e:transform($xml, $xsl)
  (: Check for Glencoe metadata :)
  let $rows := if ($xml//*:media[@mimetype="video"]) then (e:svrl2table-rows-final($xml,$svrl))
               else e:svrl2table-rows($svrl)
  return e:template(e:table-template($rows))
};

declare function e:svrl2table-rows($svrl) as element(tr)*
{
  for $x in $svrl//*[@role=('error','warn','warning','info')]
  let $id-content := if ($x/@see) then <a href="{$x/@see/string()}" target="_blank">{$x/@id/string()}</a>
                  else $x/@id/string()
  return <tr>
          <td class="align-middle"><input class="unticked" type="checkbox" value="" onclick="updateRow(event)"/></td>
          <td class="align-middle">{$x/@role/string()}</td>
          <td class="align-middle">{$id-content}</td>
          <td class="breakable align-middle">{$x/@location/string()}</td>
          <td class="align-middle">{data($x/*:text)}</td>
        </tr>
};

declare function e:svrl2table-rows-final($xml,$svrl) as element(tr)*
{
  let $doi := $xml//*:article-meta//*:article-id[@pub-id-type="doi"]/string()
  let $glencoe := e:get-glencoe($doi)
  let $glencoe-rows := 
    if ($glencoe//*:error) then <tr>
                                  <td class="align-middle"><input class="unticked" type="checkbox" value="" onclick="updateRow(event)"/></td>
                                  <td class="align-middle">unknown</td>
                                  <td class="align-middle">error</td>
                                  <td class="breakable align-middle">unknown</td>
                                  <td class="align-middle">There is no Glencoe metadata for this article but it contains videos. Please esnure that the Glencoe data is correct.</td>
                                </tr>
    else (
           for $vid in $xml//*:media[@mimetype="video"]
           let $id := $vid/@id
           return if ($glencoe/*[local-name()=$id and *:video__id[.=$id] and ends-with(*:solo__href,$id)]) then ()
           else <tr>
                  <td class="align-middle"><input class="unticked" type="checkbox" value="" onclick="updateRow(event)"/></td>
                  <td class="align-middle">unknown</td>
                  <td class="align-middle">error</td>
                  <td class="breakable align-middle">unknown</td>
                  <td class="align-middle">{'There is no metadata in Glencoe for the video with id "'||$id||'".'}</td>
                </tr>
        )
   let $table-rows := e:svrl2table-rows($svrl)       
   return ($glencoe-rows,$table-rows)
};

declare function e:table-template($table-rows) as element(table){
  <table id="result" class="table table-striped table-bordered" style="width:100%">
    <thead>
        <tr>
            <th/>
            <th>Type</th>
            <th>ID</th>
            <th class="breakable">XPath</th>
            <th>Message</th>
        </tr>
    </thead>
    <tbody>
    {$table-rows}
    </tbody>
</table>  
};

declare
function e:template($elem as element())
as element(html) 
{
<html lang="en">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></meta>
        <meta charset="utf-8"></meta>
        <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"></meta>
        <link rel="icon" type="image/png" sizes="32x32" href="/static/favicon-32x32.56d32e31.png"/>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.5.2/css/bootstrap.css" crossorigin="anonymous"></link>
        <link rel="stylesheet" href="https://cdn.datatables.net/1.10.24/css/dataTables.bootstrap4.min.css" crossorigin="anonymous"></link>
        <style><![CDATA[.breakable {
        word-wrap: break-word;
        word-break: break-all;
        }
      .completed *{
      color:#ccc7c7be;
    }]]></style>
        <title>Schematron Validator</title>
  </head>
  <body>
  <div class="container">
    <div class="col-2"><a href="/schematron"><img src="../static/elife.svg" class="img-thumbnail"/></a></div>
    <div class="col-8">
        <h3>Schematron validator</h3>
    </div>
    {$elem}
    </div>
    <script src="https://code.jquery.com/jquery-3.5.1.js" crossorigin="anonymous"></script>
    <script src="https://cdn.datatables.net/1.10.24/js/jquery.dataTables.min.js" crossorigin="anonymous"></script>
    <script src="https://cdn.datatables.net/1.10.24/js/dataTables.bootstrap4.min.js" crossorigin="anonymous"></script>
    <script><![CDATA[$(document).ready(function() {
        $('#result').DataTable({
            paging: false,
            scrollX: true,
            scrollY: false,
            colReorder: false,
            order: [],
            autoWidth: false,
            columnDefs: [
              { "targets": 0, "width": "10px" },
              { "targets": 1, "width": "40px" },
              { "targets": 2, "width": "98px" },
              { "targets": 3, "width": "290px" },
              { "targets": 4, "width": "500px" }
            ],
            fixedColumns: true,
            autoWidth: false
        });
    });]]></script>
    <script><![CDATA[function disableBtn(){
          preBtn.setAttribute('disabled','');
          finalBtn.setAttribute('disabled','');
        };

        function addSpinner(e){
          let btn = e.target
          let btnText = btn.innerHTML
          btn.innerHTML = `<span class="spinner-grow spinner-grow-sm" role="status" aria-hidden="true"></span> ${btnText}`
        };
        
        function updateRow(e){
          let checkbox = e.target;
          if (checkbox.classList.contains("unticked")){
              checkbox.classList.toggle("unticked");
              let row = checkbox.parentNode.parentNode;
              for (let i = 1; i < row.cells.length; i++){
                let cell = row.cells[i]
                let content = cell.innerHTML;
                cell.innerHTML = `<del>${content}</del>`;
                cell.classList.toggle("completed");
              };
          }
          else {
            checkbox.classList.toggle("unticked");
            let row = checkbox.parentNode.parentNode;
            for (let i = 1; i < row.cells.length; i++){
                let cell = row.cells[i]
                let del = cell.childNodes[0];
                cell.innerHTML = del.innerHTML;
                cell.classList.toggle("completed");
            };
          };
        };   
    ]]></script>
  </body>
</html>
};