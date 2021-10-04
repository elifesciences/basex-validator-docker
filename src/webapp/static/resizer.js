const resizer = document.getElementById("resizer");
let x = 0;
let leftWidth = 0;
const leftSide = document.getElementById("editor");
const rightSide = document.getElementById("results");
const mouseMoveHandler = function (e) {
  e.preventDefault();
  const dx = e.clientX - x;
  const calcLeftWidth = ((leftWidth + dx) * 100) / resizer.parentNode.getBoundingClientRect().width;
  const newLeftWidth = (calcLeftWidth > 15) ? (calcLeftWidth < 85) ? calcLeftWidth + 1: 85 : 15;
  leftSide.style["flex-basis"] = `${newLeftWidth}%`;
  rightSide.style["flex-basis"] = `${100-newLeftWidth}%`;
};
const mouseDownHandler = function (e) {
  x = e.clientX;
  leftWidth = leftSide.getBoundingClientRect().width;
  document.body.style.setProperty("cursor","col-resize","important");
  document.addEventListener("mousemove", mouseMoveHandler);
  document.addEventListener("mouseup", mouseUpHandler);
};
const mouseUpHandler = function () {
  document.body.style.removeProperty("cursor");
  document.removeEventListener("mousemove", mouseMoveHandler);
  document.removeEventListener("mouseup", mouseUpHandler);
};
resizer.addEventListener("mousedown", mouseDownHandler);