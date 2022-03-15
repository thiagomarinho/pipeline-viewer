let userThemePreferenceIsDefined = localStorage.getItem("darkMode") != undefined && localStorage.getItem("darkMode") != "";
let userThemePreferenceIsDark = localStorage.getItem("darkMode") === "enabled";
let osThemePreferenceIsDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;

if (userThemePreferenceIsDefined) {
  if (userThemePreferenceIsDark) {
    initialThemeSwitch();
  }
} else if (osThemePreferenceIsDark) {
  initialThemeSwitch();
}

function initialThemeSwitch() {
  document.body.classList.add("dark");
  switchCytoscapeTheme();
  document.querySelector('#theme-switch').innerHTML = "🌙"
}

function switchMode(el) {
  const bodyClass = document.body.classList;

  bodyClass.contains("dark")
    ? ((el.innerHTML = "☀️"), bodyClass.remove("dark"), localStorage.setItem("darkMode", "disabled"))
    : ((el.innerHTML = "🌙"), bodyClass.add("dark"), localStorage.setItem("darkMode", "enabled"));

    switchCytoscapeTheme();
}

function switchCytoscapeTheme() {
  let cy = document.getElementById('cy');

  if (cy) {
    if (document.body.classList.contains("dark")) {
      cy.style.background = "black"
    } else {
      cy.style.background = "white"
    }
  }
}