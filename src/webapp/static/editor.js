"use strict";

// namespaces in elife jats
const namespaces = {
  "ali" : "http://www.niso.org/schemas/ali/1.0/",
  "mml": "http://www.w3.org/1998/Math/MathML",
  "xlink": "http://www.w3.org/1999/xlink"
};

// breakpoints to add to editor
let breakpoints = [];

let editor = CodeMirror.fromTextArea(document.getElementById("code"), {
  mode: "xml",
  lineNumbers: true,
  lineWrapping: true,
  readOnly: true,
  dragDrop: false,
  spellcheck: false,
  autocorrect: false,
  matchTags: {bothTags: true},
  gutters: [
    "CodeMirror-linenumbers",
    "breakpoints"
  ],
  extraKeys: {
    "Cmd-F": "findPersistent",
    "Ctrl-F": "findPersistent"
  }
});

editor.setSize("100%","100%");

let xml = parseXml();
// if the root node has a preceding processing-instruction
let hasPI = document.getElementById("code").innerHTML.startsWith("&lt;?");
let root = xml.evaluate('/*',xml,nsResolver,9).singleNodeValue;
let rootName = root.nodeName;
let xmlContent = root.outerHTML;
let articleId = xml.evaluate('/descendant::article[1]//article-meta/article-id[@pub-id-type="publisher-id"]',xml,nsResolver,9).singleNodeValue.innerHTML;
let articleType = xml.evaluate('/descendant::article[1]/@article-type',xml,nsResolver,9).singleNodeValue.value;

addEditorLines(addBreakPoints);

editor.on("gutterClick", function(cm, n) {
  let info = cm.lineInfo(n);
  cm.setGutterMarker(n, "breakpoints", info.gutterMarkers ? null : makeBreakpoint("custom"));
});

// parse xml in textarea for xpath querying
function parseXml() {
  let xmlString = document.getElementById("code").innerHTML
                  .replaceAll("&lt;","<").replaceAll("&gt;",">")
                  .replaceAll("&amp;lt;","&lt;")
                  .replaceAll("&amp;gt;","&gt;")
                  .replaceAll("&nbsp;"," ")
  let parser = new DOMParser();
  let xml = parser.parseFromString(xmlString,"text/xml");
  return xml;
}

// adds editor line/character numbers in data-editor-line/data-editor-ch attributes to trs
function addEditorLines(callback) {
  Array.from(document.querySelectorAll("#schematron tbody tr")).forEach((tr) => {
    let xpath = getCellValue(tr,3);
    if (xpath) {
      if (xpath.startsWith("/")) {
        xpath = xpath.includes('namespace-uri()') ? changeXpathType(xpath) : xpath;
        let node = xml.evaluate(xpath,xml,nsResolver,9);
        let line = (node.singleNodeValue != null) ? getEditorLine(node) : null;
        if (line == null) {console.log(xpath + ' not found in xml.')};
        tr.setAttribute("data-editor-line",line);
        let ch = getEditorChar(line,node);
        tr.setAttribute("data-editor-ch",ch);
      }
      else {
        console.log("'" + xpath + "'" + " is not an XPath. Cannot search or mark Editor for message with id " 
        + getCellValue(tr,2));
      }
    }
  });
  callback();
}

// Add breakpoints to editor for each of the dtd/schematron messages
function addBreakPoints() {
  let lineArray = [];
  Array.from(document.querySelectorAll("tbody tr")).forEach((tr) => {
    let line = tr.getAttribute("data-editor-line");
    if (/^\d+$/.test(line)) {
      line = parseInt(line)
      let type = tr.className.split(" ")[0];
      let message = (tr.parentNode.parentNode.parentNode.getAttribute("id") === "schematron") ? getCellValue(tr,4) : getCellValue(tr,1);
      let obj = {type,line,message};
      lineArray.push(obj);
  }});
  let uniqueLines = [...new Set(lineArray.map(item => item.line))];
  uniqueLines.forEach(value => {
    let types = [];
    let messages = [];
    lineArray.forEach(obj => {
      if (obj.line === value) {
        types.push(obj.type);
        messages.push(obj.message);
      }
    });
    let obj = {
      "line": value,
      types,
      messages
    };
    breakpoints.push(obj);
  });
  for (let key in breakpoints) {
    addBreakPoint(breakpoints[key]);
  }
}

// add breakpoint to editor based on object in breakpoints
function addBreakPoint(obj) {
  let type;
  (obj.types.includes("error")) ? type = "error" : (obj.types.includes("warning")) ? type = "warning" : (obj.types.includes("info")) ? type = "info" : type = null;
  editor.setGutterMarker(obj.line,"breakpoints", makeBreakpoint(type,obj.messages));
};

/* makes breakpoint marker div to add to editor
    type ~~ error, warning, info or null
    message? ~~ message in td, to show on hover
*/
function makeBreakpoint(type,messages) {
  if (type) {
    let marker = document.createElement("div");
    let img = document.createElement("img");
    marker.className = "breakpoint";
    img.src = '../static/' + type + '.svg';
    marker.appendChild(img);
    if (messages) {
      let div = document.createElement("div");
      div.className = "breakpoint-messages";
      marker.appendChild(div);
      for (let message of messages) {
        let p = document.createElement("p");
        p.className = "breakpoint-message";
        p.innerHTML = message;
        div.appendChild(p);
      }
    }
    return marker;
  }
  else {
    return null
  }
}

// Returns line number for Editor 
function getEditorLine(node) {
  let str = node.singleNodeValue.outerHTML;
  if (str.startsWith("<" + rootName + " ")) {
    return (hasPI) ? 1 : 0;
  }
  /* Use parent node line, to account for numerous elements 
     within the DOM containing the same content */
  else {
    let content = chunkSearchString(str);
    let parentContent = node.singleNodeValue.parentNode.outerHTML;
    let precedingParentXml = xmlContent.split(chunkSearchString(parentContent))[0];
    let parentLine = precedingParentXml.split("\n").length - 1;
    let precedingXml = removeNS(parentContent).split(content)[0];
    let line = precedingXml.split("\n").length;
    return (hasPI) ? (parentLine + line) : (parentLine + line) - 1;
  }
}

// td message -> editor
function scrollToEditor(e) {
  let row = e.target.parentNode;
  if (row.className.includes("completed") || !row.hasAttribute("data-editor-line")) {
    return null
  }
  else {
    let line = row.getAttribute('data-editor-line');
    let ch = row.getAttribute('data-editor-ch') || 0;
    if (!isNaN(line)) {
      line = parseInt(line);
      jumpToLine(line,ch);
      editor.setCursor({line,ch});
      markLine(line);
    }
  }
}

// scrolls to line in editor view
function jumpToLine(line,ch) {
  let t = editor.charCoords({line, ch}, "local").top; 
  let middleHeight = (editor.getScrollerElement().offsetHeight / 2) - 250; 
  editor.scrollTo(null, t - middleHeight - 10);
}

// highlights selected line
function markLine(i) {
  editor.addLineClass(i,"wrap","mark");
  setTimeout(() => {editor.removeLineClass(i,"wrap","mark")}, 1000);
} 

/* checks the data available in lax for the article and compares with what's in the xml.
   The messages are appended to the popup */
async function validateLaxData() {
  pubDateBtn.setAttribute("disabled",'');
  let messages = [];
  if (/^\d{5,6}$/.test(articleId)) {
    const uri = `https://api.elifesciences.org/articles/${articleId}`;
    const data = await fetchData(uri);
    console.log(data);
    const pubDateObj = validatePubdate(data);
    messages.push(pubDateObj);
    if (data.title !== "not found") {
      const subjectsObj = validateSubjects(data);
      const authorObj = validateAuthors(data);
      messages.push(subjectsObj,authorObj);
    }
  }
  else {
    messages.push({"type":"error","message":`'${articleId}' is not a valid article id. Cannot validate against data in lax.`});
  }
  if (articleType === "correction" || articleType === "retraction") {
    const relatedArticle = xml.evaluate('/descendant::article[1]//article-meta/related-article/@xlink:href',xml,nsResolver,9);
    if (relatedArticle.singleNodeValue) {
      const relatedArticleDoi = relatedArticle.singleNodeValue.value;
      const relatedArticleId = relatedArticleDoi.split("ife.")[1]
      const box = xml.evaluate('/descendant::article[1]/body[1]/boxed-text[1]',xml,nsResolver,9)
      if (/^\d{5,6}$/.test(relatedArticleId)) {
        const relatedUri = `https://api.elifesciences.org/articles/${relatedArticleId}`;
        const relatedData = await fetchData(relatedUri);
        const relatedAuthArr = relatedData.authors.map(a =>
          a.name.index.split(",")[0].concat(' ').concat(a.name.index.split(",")[1].replace(/[^(?<=\s)A-ZÀ-ÝĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮİIĲĴĶĹĻĽĿŁŃŅŇNŊŌŎ0ŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŸŹŻŽ\-]/g,'').replace(/\s+/g,'')));
        const relatedTitle = relatedData.title.replace(/<\/?.*?>/g,'')
        const relatedPubDate = new Date(relatedData.published);
        const relatedPubYear = relatedPubDate.getFullYear();
        const relatedPubMonth = relatedPubDate.toLocaleString('default', { month: 'long' });
        const relatedPubDay = relatedPubDate.getDate();
        const generatedBoxText = `${relatedAuthArr.join(', ')}. ${relatedPubYear}. ${relatedTitle}. eLife ${relatedData.volume}:${relatedData.elocationId}. doi: ${relatedData.doi}. Published ${relatedPubDay} ${relatedPubMonth} ${relatedPubYear}`
        if (box.singleNodeValue) {
          const boxText = box.singleNodeValue.textContent.replace(/\s+/g,' ').trim();
          console.log(boxText);
          console.log(generatedBoxText);
          if (generatedBoxText == boxText) {
            messages.push({"type":"info","message":`box text is correct based on the published data for the related article`});
          }
          else {messages.push({"type":"error","message":`box text is incorrect based on the published data for the related article. The text should be '${generatedBoxText}'`});}
        }
        else {messages.push({"type":"error","message":`No boxed text within article to check against`});}
      }
      else {messages.push({"type":"error","message":`related article doi is not a proper eLife doi ${relatedArticleDoi}`});}
    }
    else {messages.push({"type":"error","message":`${articleType} article type, but no related article`});}
  }
  else {console.log(`${articleType} article type, so no related article`)}
  messages.forEach((obj) => {
    const div = document.createElement("div");
    const icon = document.createElement("img");
    icon.setAttribute("src",`../static/${obj.type}.svg`);
    const p = document.createElement("p");
    p.innerHTML = obj.message;
    div.appendChild(icon);
    div.appendChild(p);
    popupMessage.appendChild(div);
  })
  popup.style.display = "block";
  document.addEventListener('keydown',escClose);
  pubDateBtn.innerHTML = "Check published data";
  pubDateBtn.removeAttribute("disabled");
}

async function fetchData(uri) {
  console.log(`Fetching data from ${uri}...`);
  return fetch(uri)
    .then(res => res.json())
    .then(json => json)
    .catch(error => console.log(error))
}

// checks the pubdate against certain conditions
function validatePubdate(data) {
    let obj = {};
    const laxIso = (data.published) ? data.published.split("T")[0] : null;
    const pubDateXpath = '//article-meta/pub-date[@date-type="pub" or @date-type="publication"]';
    const xmlPubDate = xml.evaluate(pubDateXpath,xml,nsResolver,9).singleNodeValue;
    const xmlIso = (xmlPubDate) ? (xmlPubDate.children.length === 3) ? getIso(xmlPubDate) : null : null;
    if (laxIso) {
      if (xmlIso) {
        if (xmlIso === laxIso) {
          obj.type = "info";
          obj.message = `XML pub date matches the 
          <a href="https://doi.org/${data.doi}" target="_blank">${data.status.toUpperCase()} already published</a>.`;
        }
        else {
          obj.type = "error";
          obj.message = `XML pub date (${xmlIso}) does not match the 
          <a href="https://doi.org/${data.doi}" target="_blank">${data.status.toUpperCase()} already published</a> (${laxIso}).`;
        }
      }
      else {
        obj.type = "error";
        obj.message = `No pub date in the XML, but ${data.status.toUpperCase()} 
        <a href="https://doi.org/${data.doi}" target="_blank">has been published</a> on ${laxIso}.`;
      }
    }
    else if (xmlIso) {
      const isoToday = new Date().toISOString().split("T")[0];
      if (xmlIso < isoToday) {
        obj.type = "error";
        obj.message = `This article has not yet been published, but XML pub date is in the past (${xmlIso}). 
        The pub date needs to be changed to today's date (${isoToday}) at the earliest.`;
      }
      else if (xmlIso === isoToday) {
        obj.type = "info";
        obj.message = `This article has not yet been published and the XML pub date is today's date (${xmlIso}). 
        This VOR will need to be published today, or the pub date needs to be changed.`;
      }
      else if (!isTuesday(xmlIso)) {
        obj.type = "warning";
        obj.message = `This article has not yet been published and the XML pub date is in the future (${xmlIso}), 
        but it is not on a Tuesday (for Press). Is that correct?`;
      }
      else {
        obj.type = "info";
        obj.message = `This article has not yet been published and the XML pub date is in the future, on a Tuesday (${xmlIso}).`;
      }
    }
    else {
      obj.type = "error";
      obj.message = `No published version and no pub date in the XML.`;
    }
    return obj;
}

function getIso(node) {
  const year = node.getElementsByTagName("year")[0].innerHTML;
  const month = node.getElementsByTagName("month")[0].innerHTML;
  const day = node.getElementsByTagName("day")[0].innerHTML;
  return `${year}-${month}-${day}`
}

function isTuesday(isoString) {
  const date = new Date(isoString);
  return (date.getDay() === 2) ? true : false;
}

// checks the subjects in lax against xml
function validateSubjects(data) {
  let obj = {};
  let laxSubjects = [];
  let xmlSubjects = [];
  (data.subjects) ? data.subjects.forEach(obj=>laxSubjects.push(obj.name)) : null;
  const subjectsXpath = '//article-meta/article-categories/subj-group[@subj-group-type="heading"]/subject';
  const result = xml.evaluate(subjectsXpath,xml,nsResolver,6);
  for (let i = 0; i < result.snapshotLength; i++) {
    xmlSubjects.push(result.snapshotItem(i).textContent);
  }
  if (laxSubjects.sort().join('')===xmlSubjects.sort().join('')) {
    obj.type = "info";
    obj.message = `Published ${data.status.toUpperCase()} and XML MSAs are the same.`;
  }
  else {
    obj.type = "warning";
    obj.message = `Published ${data.status.toUpperCase()} and XML MSAs are not the same.<br>
                   <b>${data.status.toUpperCase()} MSAs</b>: ${laxSubjects.sort().join('; ')}<br>
                   <b>XML MSAs</b>: ${xmlSubjects.sort().join('; ')}`;
  }
  return obj;
}

// Compares published author count with xml.
function validateAuthors(data) {
  let obj = {};
  const laxAuthorCount = data.authors.length;
  const authorsXpath = 'count(//article-meta/contrib-group[1]/contrib[@contrib-type="author"])';
  const xmlAuthorCount = xml.evaluate(authorsXpath,xml,nsResolver,1).numberValue;
  if (laxAuthorCount === xmlAuthorCount) {
    obj.type = "info";
    obj.message = `Published ${data.status.toUpperCase()} has the same number of authors as this XML.`;
  }
  else {
    obj.type = "warning";
    obj.message = `Published ${data.status.toUpperCase()} has ${laxAuthorCount} authors, whereas this XML has ${xmlAuthorCount}.
                   Which is correct?`;
  }
  return obj;
}

function escClose(e) {
  (e.key === "Escape") ? closePopup() : null;
}

function closePopup() {
  popup.style.display = "none";
  popupMessage.querySelectorAll('*:not(:first-child)').forEach(p => p.remove());
  document.removeEventListener('keydown',escClose);
}

// EVENT LISTENERS

// validate publication date
document.querySelector('#pubDateBtn').addEventListener('click',validateLaxData);

// close popup
document.querySelector('.close').addEventListener('click',closePopup);

// message -> line in editor
document.querySelectorAll('.message').forEach(td => {
  td.addEventListener('click',scrollToEditor);
});

// toggle del in rows
document.querySelectorAll('.align-middle input').forEach(td => {
  td.addEventListener('click',updateRow);
});

// order table by headers
document.querySelectorAll('th').forEach(th => th.addEventListener('click', (() => {
  let tbody = th.closest('table').querySelectorAll('tbody')[0];
  Array.from(tbody.querySelectorAll('tr'))
      .sort(comparer(Array.from(th.parentNode.children).indexOf(th), this.asc = !this.asc))
      .forEach((tr,i) => reorderRows(tbody,tr,i));
})));

// HELPER FUNCTIONS

function nsResolver(prefix) {
  return namespaces[prefix] || null;
}

// ensures odd/even classes are reshuffled
function reorderRows(tbody,tr,i) {
  let parity = tr.className.split(" ")[1];
  let newParity = (i + 1) % 2 ? "odd" : "even";
  if (parity !== newParity) {
    if (tr.className.includes("completed")) {
      tr.className = tr.className.split(" ")[0] + " " + newParity + " completed";
    }
    else {
      tr.className = tr.className.split(" ")[0] + " " + newParity;
    }
  }
  tbody.appendChild(tr);
}

// toggle the "complete" status of the row
function updateRow(e) {
  let row = e.target.parentNode.parentNode;
  row.classList.toggle("completed");
  (e.target.getAttribute("value") === "z") ? e.target.setAttribute("value","a") : e.target.setAttribute("value","z"); 
  if (row.hasAttribute("data-editor-line")) {
    let line = row.getAttribute("data-editor-line");
    let type = row.className.split(" ")[0];
    let message = (row.parentNode.parentNode.parentNode.getAttribute("id") === "schematron") ? getCellValue(row,4) : getCellValue(row,1);
    updateBreakpoint(line,type,message,row.className.includes("completed"));
  }
}

/* remove or re-add breakpoint depending on row "complete" status
    line ~~ int - line in editor
    type ~~ error, warning, info, null
    message ~~ dtd/schematron message from the row
    completedStatus ~~ boolean - if removing or re-adding breakpoint
*/
function updateBreakpoint(line,type,message,completedStatus) {
  let breakpointObj = breakpoints.find(obj => {
    return obj.line == line;
  });
  let typeIndex = breakpointObj.types.findIndex(element => element == type);
  let messageIndex = breakpointObj.messages.findIndex(element => element == message);
  if (completedStatus) {
    breakpointObj.types.splice(typeIndex, 1);
    breakpointObj.messages.splice(messageIndex, 1);
  }
  else {
    breakpointObj.types.push(type);
    breakpointObj.messages.push(message);
  }
  addBreakPoint(breakpointObj);
}

// Get the character that the node starts on in the relevant editor line
function getEditorChar(line,node) {
  if (line) {
    const content = removeNS(node.singleNodeValue.outerHTML.split("\n")[0]).substring(0,200);
    const editorContent = editor.getLine(line);
    const ch = editorContent.split(content)[0].length;
    return (editorContent.length === ch) ? ch - 1: ch;
  }
}

function getCellValue(tr, idx) {
  return (tr.children[idx].children[0] == undefined) 
    ? tr.children[idx].innerText || tr.children[idx].textContent
    : tr.children[idx].children[0].getAttribute("value") || tr.children[idx].innerText || tr.children[idx].textContent; 
}

function comparer(idx, asc) { 
    return function(a, b) { 
        return function(v1, v2) {
            return (v1 !== '' && v2 !== '' && !isNaN(v1) && !isNaN(v2)) 
                ? v1 - v2 
                : v1.toString().localeCompare(v2);
        }(getCellValue(asc ? a : b, idx), getCellValue(asc ? b : a, idx));
    }
}

// parent function for changeXpathToken
function changeXpathType(xpath) {
  let xpathArray = xpath.split('*:')
  for (let i = 0; i < xpathArray.length; i++) {
    xpathArray[i].includes('namespace-uri()') ? xpathArray.splice(i,1,changeXpathToken(xpathArray[i])) : null;
  }
  return xpathArray.join("");
}

/* changes xpath tokens in the format: /*:math[namespace-uri()='http://www.w3.org/1998/Math/MathML'][1]
  to: /mml:math[1]   */
function changeXpathToken(token) {
  let ns; 
  for (let key in namespaces) {
    if (token.includes(namespaces[key])) {
      ns = key
    }
  }
  let tokenArray = token.split("[")
  return (ns + ':' + tokenArray[0] + "[" + tokenArray[2])
}

/* splits large xml snippets into smaller sections 
   for searhcing in Editor */
function chunkSearchString(str){
  let array = str.split(/\n/g);
  array.splice(9, array.length);
  let newStr = removeNS(array.join("\n"));
  return newStr;
}

/* removes namespaces such as xmlns:xlink="http://www.w3.org/1999/xlink" 
   from outerHTML strings for searching */
function removeNS(str) {
  return (str.startsWith("<" + rootName + " ")) 
    ? str
    : str.replaceAll(` xmlns:xlink="http://www.w3.org/1999/xlink"`,"")
         .replaceAll(` xmlns:ali="http://www.niso.org/schemas/ali/1.0/"`,"")
         .replaceAll(` xmlns:mml="http://www.w3.org/1998/Math/MathML"`,"");
}