document.querySelectorAll('button').forEach(item => {
  item.addEventListener('click', addSpinner);
});
form1.addEventListener('submit',disableBtn);
function addSpinner(e){
  e.target.innerHTML = `<span class="spinner"><i class="fa fa-circle-o-notch fa-spin"></i></span> ${e.target.innerHTML}`;
  preBtn.classList.add('button-loading');
  finalBtn.classList.add('button-loading');
}
function disableBtn(){
  preBtn.setAttribute('disabled','');
  finalBtn.setAttribute('disabled','');
}
dropContainer.addEventListener('click',() => {files.click()});
document.ondragover = dropContainer.ondragenter = (e) => {e.preventDefault()};
document.ondrop = (e) => {
  e.preventDefault();
  files.files = e.dataTransfer.files;
  const fileName = e.dataTransfer.files[0].name;
  const type = e.dataTransfer.files[0].type;
  if (fileName.toLowerCase().endsWith(".xml") && (type === "application/xml" || type === "text/xml")) {
    const dT = new DataTransfer();
    dT.items.add(e.dataTransfer.files[0]);
    uploadStatus.innerHTML = fileName; 
    (uploadStatus.className = "warning") ? uploadStatus.classList.toggle("warning"): null;
  }
  else {
    uploadStatus.innerHTML = fileName + " is not an XML file";
    uploadStatus.className = "warning";
  }
};
files.addEventListener('change', (e) => {
  const fileName = e.target.files[0].name;
  uploadStatus.innerHTML = fileName;
})