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
let rootName = xml.evaluate('/*',xml,nsResolver,9).singleNodeValue.nodeName;
let xmlContent = xml.evaluate('/descendant::article[1]',xml,nsResolver,9).singleNodeValue.outerHTML;

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

// adds editor line numbers in data-editor-line attribute to trs
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
      }
      else {
        console.log("'" + xpath + "'" + " is not an XPath. Cannot search or mark Editor for message with id " 
        + getCellValue(tr,2));
      }
    }
  });
  callback();
}

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
    if (!isNaN(line)) {
      line = parseInt(line);
      jumpToLine(line);
      editor.setCursor({line,ch:0});
      markLine(line);
    }
  }
}

// scrolls to line in editor view
function jumpToLine(i) { 
  let t = editor.charCoords({line: i, ch: 0}, "local").top; 
  let middleHeight = (editor.getScrollerElement().offsetHeight / 2) - 300; 
  editor.scrollTo(null, t - middleHeight - 10); 
}
// highlights selected line
function markLine(i) {
  editor.addLineClass(i,"wrap","mark");
  setTimeout(() => {editor.removeLineClass(i,"wrap","mark")}, 2000);
} 

// EVENT LISTENERS

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