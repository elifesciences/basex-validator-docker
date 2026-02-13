module namespace html = 'http://elifesciences.org/modules/html-generator';
import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace dtd = 'http://elifesciences.org/modules/dtd-validator';
import module namespace svrl = 'http://elifesciences.org/modules/svrl-converter';

(: HTML pages:)

declare
  %rest:path("/")
  %rest:GET
  %output:method("html")
  %output:html-version("5.0")
function html:upload()
{
  let $script := <script src="../static/form.js" defer=""></script>
   
  return html:index($script,<div/>,<div/>)
};

declare
  %rest:path("/pre-result")
  %rest:POST("{$xml}")
  %output:method("html")
  %output:html-version("5.0")
function html:validate-pre-result($xml)
as element(html)
{  
  let $xsl := doc('./schematron/pre-JATS-schematron.xsl')
  let $svrl :=  html:transform($xml, $xsl)
  
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
                        {dtd:dtd2result($xml),
                        svrl:svrl2result($xml,$svrl)}
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
                   
  return html:index($scripts,$button,$container)
};

declare
  %rest:path("/final-result")
  %rest:POST("{$xml}")
  %output:method("html")
  %output:html-version("5.0")
function html:validate-final-result($xml)
as element(html)
{
  let $xsl := doc('./schematron/final-JATS-schematron.xsl')
  let $svrl :=  html:transform($xml, $xsl)
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
                        {dtd:dtd2result($xml),
                         if ($xml//*:media[@mimetype="video"]) then (svrl:svrl2result-video($xml,$svrl))
                         else svrl:svrl2result($xml,$svrl)}
                        </div>
                      </div>
                    </div>
  let $button := <button id="pubDateBtn" class="loader">Check published data</button>
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
  
   return html:index($scripts,$button,$container)
};

declare function html:transform($xml,$schema)
{  
  try {xslt:transform($xml, $schema)}
  (: Return psuedo-svrl to output error message for fatal xslt errors :)
  catch * { <schematron-output><successful-report id="validator-broken" location="unknown" role="error"><text>{'Error [' || $err:code || ']: ' || $err:description}</text></successful-report></schematron-output>}
};

declare
function html:index($scripts as element()*, $middle-header-elem as element(), $elem as element()*) as element(html) {
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <link rel="icon" type="image/png" sizes="32x32" href="../static/favicon-32x32.56d32e31.png"/>
    <link rel="preconnect" href="https://fonts.gstatic.com"/>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;700&amp;display=swap" rel="stylesheet"/>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/fa.min.css"/>
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
