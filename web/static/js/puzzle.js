(function () {
  "use strict";

  var SOLVED = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0];
  var CHALLENGE = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 14, 0];

  var board = [];
  var moves = 0;
  var mode = "RANDOM";

  var boardEl = document.getElementById("puzzle-board");
  var moveCounterEl = document.getElementById("move-counter");
  var modeEl = document.getElementById("puzzle-mode");
  var messageEl = document.getElementById("puzzle-message");
  var btnRandom = document.getElementById("btn-random");
  var btnChallenge = document.getElementById("btn-challenge");

  function emptyIndex() {
    return board.indexOf(0);
  }

  function neighbors(index) {
    var row = Math.floor(index / 4);
    var col = index % 4;
    var result = [];
    if (row > 0) result.push(index - 4);
    if (row < 3) result.push(index + 4);
    if (col > 0) result.push(index - 1);
    if (col < 3) result.push(index + 1);
    return result;
  }

  function isSolved() {
    for (var i = 0; i < 16; i++) {
      if (board[i] !== SOLVED[i]) return false;
    }
    return true;
  }

  function swap(a, b) {
    var tmp = board[a];
    board[a] = board[b];
    board[b] = tmp;
  }

  function shuffle() {
    board = SOLVED.slice();
    // Apply 200 random valid moves from solved state to guarantee solvability.
    var empty = 15;
    var prev = -1;
    for (var i = 0; i < 200; i++) {
      var adj = neighbors(empty);
      // Filter out the previous position to avoid undoing the last move.
      var choices = adj.filter(function (n) { return n !== prev; });
      var pick = choices[Math.floor(Math.random() * choices.length)];
      swap(empty, pick);
      prev = empty;
      empty = pick;
    }
  }

  function loadChallenge() {
    board = CHALLENGE.slice();
  }

  function move(index) {
    var empty = emptyIndex();
    if (neighbors(empty).indexOf(index) === -1) return;
    swap(index, empty);
    moves++;
    render();
    if (isSolved()) {
      messageEl.textContent = "*** SOLVED! ***";
    }
  }

  function render() {
    moveCounterEl.textContent = "MOVES: " + moves;
    modeEl.textContent = "MODE: " + mode;
    boardEl.innerHTML = "";

    for (var i = 0; i < 16; i++) {
      var tile = document.createElement("div");
      tile.className = "puzzle-tile";
      if (board[i] === 0) {
        tile.classList.add("empty");
      } else {
        tile.textContent = board[i];
        tile.dataset.index = i;
        tile.addEventListener("click", (function (idx) {
          return function () { move(idx); };
        })(i));
      }
      boardEl.appendChild(tile);
    }
  }

  function startRandom() {
    mode = "RANDOM";
    moves = 0;
    messageEl.textContent = "";
    shuffle();
    render();
    btnRandom.classList.add("active");
    btnChallenge.classList.remove("active");
  }

  function startChallenge() {
    mode = "CHALLENGE";
    moves = 0;
    messageEl.textContent = "";
    loadChallenge();
    render();
    btnChallenge.classList.add("active");
    btnRandom.classList.remove("active");
  }

  // Arrow key support: move tile relative to the empty space.
  document.addEventListener("keydown", function (e) {
    var empty = emptyIndex();
    var row = Math.floor(empty / 4);
    var col = empty % 4;
    var target = -1;

    switch (e.key) {
      case "ArrowUp":    if (row < 3) target = empty + 4; break;
      case "ArrowDown":  if (row > 0) target = empty - 4; break;
      case "ArrowLeft":  if (col < 3) target = empty + 1; break;
      case "ArrowRight": if (col > 0) target = empty - 1; break;
      default: return;
    }

    if (target >= 0 && target < 16) {
      e.preventDefault();
      move(target);
    }
  });

  btnRandom.addEventListener("click", startRandom);
  btnChallenge.addEventListener("click", startChallenge);

  // Start with a random board.
  startRandom();
})();
