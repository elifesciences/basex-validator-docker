document.querySelectorAll('button').forEach(item => {
  item.addEventListener('click', addSpinner);
});
document.querySelector("#form1").addEventListener('submit',disableBtn);
function disableBtn(){
    preBtn.setAttribute('disabled','');
    finalBtn.setAttribute('disabled','');
}
function addSpinner(e){
  e.target.innerHTML = `<span class="spinner"><i class="fa fa-circle-o-notch fa-spin"></i></span> ${e.target.innerHTML}`;
  preBtn.classList.add('button-loading');
  finalBtn.classList.add('button-loading');
}