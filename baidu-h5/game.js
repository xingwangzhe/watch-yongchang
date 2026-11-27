/*
 * 永昌守灯：standalone offline Baidu H5 mini experience.
 * Authored for xingwangzhe; no third-party runtime code or network resources.
 */
(function () {
  "use strict";

  var canvas = document.getElementById("field");
  var ctx = canvas.getContext("2d");
  var clockLabel = document.getElementById("clock");
  var scoreLabel = document.getElementById("score");
  var healthLabel = document.getElementById("health");
  var guide = document.getElementById("guide");
  var result = document.getElementById("result");
  var resultTitle = document.getElementById("result-title");
  var resultCopy = document.getElementById("result-copy");
  var startButton = document.getElementById("start");
  var restartButton = document.getElementById("restart");
  var attackButton = document.getElementById("attack");
  var dashButton = document.getElementById("dash");
  var autoButton = document.getElementById("auto");
  var stick = document.getElementById("stick");
  var nub = document.getElementById("nub");

  var width = 390;
  var height = 844;
  var pixelRatio = 1;
  var running = false;
  var elapsed = 0;
  var lastTime = 0;
  var spawnTimer = 0;
  var attackTimer = 0;
  var dashCooldown = 0;
  var dashTime = 0;
  var autoAttack = false;
  var attackHeld = false;
  var moveTouch = -1;
  var moveVector = { x: 0, y: 0 };
  var keys = Object.create(null);
  var enemies = [];
  var sparks = [];
  var hits = [];
  var score = 0;
  var state = null;
  var randomSeed = 20261127;
  var ATTACK_RANGE = 106;

  function random() {
    randomSeed = (randomSeed * 1664525 + 1013904223) >>> 0;
    return randomSeed / 4294967296;
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
    width = Math.max(1, rect.width);
    height = Math.max(1, rect.height);
    canvas.width = Math.round(width * pixelRatio);
    canvas.height = Math.round(height * pixelRatio);
    ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  }

  function newState() {
    return {
      x: width * 0.5,
      y: height * 0.52,
      hp: 5,
      invulnerable: 0,
      faceX: 1,
      faceY: 0,
      lanternPulse: 0,
    };
  }

  function beginRun() {
    randomSeed = 20261127;
    state = newState();
    enemies = [];
    sparks = [];
    hits = [];
    score = 0;
    elapsed = 0;
    spawnTimer = 0.1;
    attackTimer = 0;
    dashCooldown = 0;
    dashTime = 0;
    attackHeld = false;
    running = true;
    guide.hidden = true;
    result.hidden = true;
    lastTime = performance.now();
    updateLabels();
  }

  function finishRun(won) {
    running = false;
    attackHeld = false;
    resultTitle.textContent = won ? "灯火守到天明" : "灯火暂时熄了";
    resultCopy.textContent = won
      ? "你击退了 " + score + " 名来犯者，守住永昌这一夜。"
      : "你击退了 " + score + " 名来犯者。整顿灯火，再试一次。";
    result.hidden = false;
  }

  function updateLabels() {
    var remain = Math.max(0, 60 - Math.floor(elapsed));
    clockLabel.textContent = "守夜 " + String(Math.floor(remain / 60)).padStart(2, "0") + ":" + String(remain % 60).padStart(2, "0");
    scoreLabel.textContent = "击退 " + score;
    healthLabel.textContent = "灯火 " + "✦".repeat(Math.max(0, state ? state.hp : 5));
    autoButton.textContent = autoAttack ? "自动开" : "自动";
  }

  function spawnEnemy() {
    var edge = Math.floor(random() * 4);
    var margin = 26;
    var x = edge === 0 ? -margin : edge === 1 ? width + margin : random() * width;
    var y = edge === 2 ? -margin : edge === 3 ? height + margin : random() * height;
    enemies.push({ x: x, y: y, hp: 1, radius: 13 + random() * 3, speed: 34 + random() * 16, flash: 0, phase: random() * 6.28 });
  }

  function triggerDash() {
    if (!running || dashCooldown > 0) return;
    dashCooldown = 3.2;
    dashTime = 0.2;
    if (moveVector.x || moveVector.y) {
      state.faceX = moveVector.x;
      state.faceY = moveVector.y;
    }
    for (var i = 0; i < 12; i += 1) {
      sparks.push({ x: state.x, y: state.y, vx: -state.faceX * (32 + random() * 90), vy: -state.faceY * (32 + random() * 90), life: 0.24 + random() * 0.25, maxLife: 0.49, color: i % 2 ? "#efd78d" : "#8fc2a5" });
    }
  }

  function attack() {
    if (!running || attackTimer > 0) return;
    attackTimer = 0.32;
    state.lanternPulse = 0.16;
    var range = ATTACK_RANGE;
    var arc = Math.PI * 0.7;
    var facing = Math.atan2(state.faceY, state.faceX);
    var struck = false;
    enemies.forEach(function (enemy) {
      var dx = enemy.x - state.x;
      var dy = enemy.y - state.y;
      var distance = Math.sqrt(dx * dx + dy * dy);
      var angle = Math.atan2(dy, dx);
      var delta = Math.atan2(Math.sin(angle - facing), Math.cos(angle - facing));
      if (distance <= range && Math.abs(delta) <= arc * 0.5) {
        enemy.hp -= 1;
        enemy.flash = 0.12;
        struck = true;
        hits.push({ x: enemy.x, y: enemy.y, life: 0.18, maxLife: 0.18 });
        for (var j = 0; j < 6; j += 1) {
          var a = random() * Math.PI * 2;
          var speed = 32 + random() * 104;
          sparks.push({ x: enemy.x, y: enemy.y, vx: Math.cos(a) * speed, vy: Math.sin(a) * speed, life: 0.16 + random() * 0.16, maxLife: 0.32, color: j % 2 ? "#ffcf72" : "#ffe9bd" });
        }
      }
    });
    var killed = enemies.filter(function (enemy) { return enemy.hp <= 0; });
    score += killed.length;
    enemies = enemies.filter(function (enemy) { return enemy.hp > 0; });
    if (struck) state.lanternPulse = 0.23;
    updateLabels();
  }

  function moveInput() {
    var x = moveVector.x;
    var y = moveVector.y;
    if (keys.ArrowLeft || keys.KeyA) x -= 1;
    if (keys.ArrowRight || keys.KeyD) x += 1;
    if (keys.ArrowUp || keys.KeyW) y -= 1;
    if (keys.ArrowDown || keys.KeyS) y += 1;
    var length = Math.sqrt(x * x + y * y);
    if (length > 1) { x /= length; y /= length; }
    return { x: x, y: y };
  }

  function update(dt) {
    if (!running) return;
    elapsed += dt;
    var move = moveInput();
    if (move.x || move.y) { state.faceX = move.x; state.faceY = move.y; }
    var speed = dashTime > 0 ? 450 : 175;
    state.x = Math.max(24, Math.min(width - 24, state.x + move.x * speed * dt));
    state.y = Math.max(58, Math.min(height - 150, state.y + move.y * speed * dt));
    state.invulnerable = Math.max(0, state.invulnerable - dt);
    state.lanternPulse = Math.max(0, state.lanternPulse - dt);
    dashCooldown = Math.max(0, dashCooldown - dt);
    dashTime = Math.max(0, dashTime - dt);
    attackTimer = Math.max(0, attackTimer - dt);
    if (attackHeld || autoAttack) { if (attackTimer <= 0) attack(); }

    spawnTimer -= dt;
    if (spawnTimer <= 0) {
      spawnEnemy();
      spawnTimer = Math.max(0.48, 1.22 - elapsed * 0.009);
    }
    enemies.forEach(function (enemy) {
      var dx = state.x - enemy.x;
      var dy = state.y - enemy.y;
      var distance = Math.max(0.001, Math.sqrt(dx * dx + dy * dy));
      enemy.x += dx / distance * enemy.speed * dt;
      enemy.y += dy / distance * enemy.speed * dt;
      enemy.flash = Math.max(0, enemy.flash - dt);
      if (distance < 27 && state.invulnerable <= 0 && dashTime <= 0) {
        state.hp -= 1;
        state.invulnerable = 0.9;
        enemy.x -= dx / distance * 48;
        enemy.y -= dy / distance * 48;
        for (var i = 0; i < 10; i += 1) {
          var a = random() * Math.PI * 2;
          sparks.push({ x: state.x, y: state.y, vx: Math.cos(a) * 75, vy: Math.sin(a) * 75, life: 0.25, maxLife: 0.25, color: "#fa9c78" });
        }
        updateLabels();
      }
    });
    sparks.forEach(function (spark) { spark.x += spark.vx * dt; spark.y += spark.vy * dt; spark.life -= dt; });
    sparks = sparks.filter(function (spark) { return spark.life > 0; });
    hits.forEach(function (hit) { hit.life -= dt; });
    hits = hits.filter(function (hit) { return hit.life > 0; });
    if (state.hp <= 0) finishRun(false);
    else if (elapsed >= 60) finishRun(true);
    if (Math.floor(elapsed) !== Math.floor(elapsed - dt)) updateLabels();
  }

  function drawGround() {
    ctx.fillStyle = "#30483e";
    ctx.fillRect(0, 0, width, height);
    ctx.fillStyle = "#354c3e";
    for (var y = 0; y < height; y += 36) {
      for (var x = (Math.floor(y / 36) % 2) * 18; x < width; x += 36) {
        ctx.globalAlpha = 0.13;
        ctx.fillRect(x + 2, y + 3, 31, 29);
      }
    }
    ctx.globalAlpha = 1;
    ctx.strokeStyle = "#a4a06b";
    ctx.lineWidth = 14;
    ctx.beginPath(); ctx.moveTo(width * 0.18, 0); ctx.lineTo(width * 0.48, height * 0.34); ctx.lineTo(width * 0.31, height * 0.62); ctx.lineTo(width * 0.82, height); ctx.stroke();
    ctx.strokeStyle = "#d3ba72";
    ctx.lineWidth = 2;
    ctx.setLineDash([8, 8]);
    ctx.beginPath(); ctx.moveTo(width * 0.18, 0); ctx.lineTo(width * 0.48, height * 0.34); ctx.lineTo(width * 0.31, height * 0.62); ctx.lineTo(width * 0.82, height); ctx.stroke();
    ctx.setLineDash([]);
    drawHouse(width * 0.18, height * 0.24, 0.76);
    drawHouse(width * 0.8, height * 0.43, 0.65);
    drawHouse(width * 0.2, height * 0.75, 0.58);
  }

  function drawHouse(x, y, scale) {
    ctx.save(); ctx.translate(x, y); ctx.scale(scale, scale);
    ctx.fillStyle = "#172522"; ctx.beginPath(); ctx.ellipse(0, 11, 35, 20, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#b99a58"; ctx.fillRect(-23, -10, 46, 30);
    ctx.fillStyle = "#704943";
    ctx.beginPath(); ctx.moveTo(-35, -11); ctx.lineTo(0, -34); ctx.lineTo(35, -11); ctx.lineTo(0, 1); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = "#d2ab66"; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(-25, -10); ctx.lineTo(0, -28); ctx.lineTo(25, -10); ctx.stroke();
    ctx.fillStyle = "#443b2b"; ctx.fillRect(-4, 5, 8, 15);
    ctx.restore();
  }

  function drawPlayer(time) {
    var blink = state.invulnerable > 0 && Math.floor(time * 18) % 2 === 0;
    if (blink) return;
    var facing = Math.atan2(state.faceY, state.faceX);
    var radius = ATTACK_RANGE;
    ctx.save(); ctx.translate(state.x, state.y); ctx.rotate(facing);
    ctx.fillStyle = "#20292799"; ctx.beginPath(); ctx.ellipse(0, 9, 21, 13, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#d8c493"; ctx.fillRect(-11, -12, 22, 24);
    ctx.fillStyle = "#304b45"; ctx.fillRect(-14, -6, 28, 15);
    ctx.fillStyle = "#d4b66e"; ctx.fillRect(-10, -19, 20, 12);
    ctx.fillStyle = "#191e1b"; ctx.fillRect(-7, -16, 14, 5);
    ctx.fillStyle = "#e6c669"; ctx.beginPath(); ctx.moveTo(14, -4); ctx.lineTo(32, -1); ctx.lineTo(14, 2); ctx.closePath(); ctx.fill();
    ctx.fillStyle = "#ffe69b"; ctx.beginPath(); ctx.arc(29, -2, 3 + Math.sin(time * 9) * 1.1, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
    ctx.strokeStyle = state.lanternPulse > 0 ? "#ffe8a5cc" : "#f3d98b45";
    ctx.lineWidth = state.lanternPulse > 0 ? 3 : 1.5;
    ctx.beginPath(); ctx.arc(state.x, state.y, radius, facing - 0.38, facing + 0.38); ctx.stroke();
  }

  function drawEnemy(enemy, time) {
    ctx.save(); ctx.translate(enemy.x, enemy.y);
    var bob = Math.sin(time * 5 + enemy.phase) * 1.7;
    ctx.fillStyle = "#18221f99"; ctx.beginPath(); ctx.ellipse(0, 7, 15, 9, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = enemy.flash > 0 ? "#fff1cd" : "#7d493b";
    ctx.beginPath(); ctx.ellipse(0, bob, 10, 13, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#352d2a"; ctx.beginPath(); ctx.moveTo(-12, -3 + bob); ctx.lineTo(-9, -15 + bob); ctx.lineTo(0, -19 + bob); ctx.lineTo(9, -15 + bob); ctx.lineTo(12, -3 + bob); ctx.closePath(); ctx.fill();
    ctx.fillStyle = "#e7b27e"; ctx.fillRect(-3, -1 + bob, 2, 2); ctx.fillRect(3, -1 + bob, 2, 2);
    ctx.strokeStyle = "#d9c38f"; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(8, 1 + bob); ctx.lineTo(16, 10 + bob); ctx.stroke();
    ctx.restore();
  }

  function draw(time) {
    if (!ctx || !state) return;
    drawGround();
    ctx.fillStyle = "#e8cb7760"; ctx.beginPath(); ctx.arc(width * 0.5, height * 0.52, 45 + Math.sin(time * 2) * 2, 0, Math.PI * 2); ctx.fill();
    enemies.forEach(function (enemy) { drawEnemy(enemy, time); });
    drawPlayer(time);
    sparks.forEach(function (spark) { ctx.globalAlpha = Math.max(0, spark.life / spark.maxLife); ctx.fillStyle = spark.color; ctx.fillRect(spark.x - 2, spark.y - 2, 4, 4); });
    ctx.globalAlpha = 1;
    hits.forEach(function (hit) { var progress = 1 - hit.life / hit.maxLife; ctx.strokeStyle = "rgba(255,238,191," + (1 - progress) + ")"; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(hit.x, hit.y, 8 + progress * 24, 0, Math.PI * 2); ctx.stroke(); });
    if (dashCooldown > 0) {
      ctx.fillStyle = "#17211ddd"; ctx.fillRect(width - 86, height - 252, 48, 4);
      ctx.fillStyle = "#e4c56e"; ctx.fillRect(width - 86, height - 252, 48 * (1 - dashCooldown / 3.2), 4);
    }
  }

  function frame(now) {
    var dt = Math.min(0.05, Math.max(0, (now - lastTime) / 1000));
    lastTime = now;
    update(dt);
    draw(now / 1000);
    window.requestAnimationFrame(frame);
  }

  function point(event) {
    var rect = stick.getBoundingClientRect();
    return { x: event.clientX - (rect.left + rect.width / 2), y: event.clientY - (rect.top + rect.height / 2) };
  }

  function updateStick(event) {
    var p = point(event);
    var len = Math.sqrt(p.x * p.x + p.y * p.y) || 1;
    var max = 42;
    var ratio = Math.min(1, max / len);
    var px = p.x * ratio;
    var py = p.y * ratio;
    nub.style.transform = "translate(" + px + "px," + py + "px)";
    moveVector = { x: px / max, y: py / max };
  }

  startButton.addEventListener("click", beginRun);
  restartButton.addEventListener("click", beginRun);
  dashButton.addEventListener("pointerdown", function (event) { event.preventDefault(); triggerDash(); });
  autoButton.addEventListener("pointerdown", function (event) { event.preventDefault(); autoAttack = !autoAttack; updateLabels(); });
  attackButton.addEventListener("pointerdown", function (event) { event.preventDefault(); attackHeld = true; attack(); });
  ["pointerup", "pointercancel", "pointerleave"].forEach(function (name) { attackButton.addEventListener(name, function () { attackHeld = false; }); });
  stick.addEventListener("pointerdown", function (event) { event.preventDefault(); if (moveTouch >= 0) return; moveTouch = event.pointerId; stick.setPointerCapture(event.pointerId); updateStick(event); });
  stick.addEventListener("pointermove", function (event) { if (event.pointerId === moveTouch) updateStick(event); });
  ["pointerup", "pointercancel"].forEach(function (name) { stick.addEventListener(name, function (event) { if (event.pointerId !== moveTouch) return; moveTouch = -1; moveVector = { x: 0, y: 0 }; nub.style.transform = "translate(0,0)"; }); });
  window.addEventListener("keydown", function (event) {
    if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].indexOf(event.code) >= 0) event.preventDefault();
    keys[event.code] = true;
    if (event.code === "Space" && !event.repeat) triggerDash();
    if (event.code === "KeyJ" || event.code === "Enter") attackHeld = true;
    if (event.code === "KeyK" && !event.repeat) { autoAttack = !autoAttack; updateLabels(); }
  });
  window.addEventListener("keyup", function (event) { keys[event.code] = false; if (event.code === "KeyJ" || event.code === "Enter") attackHeld = false; });
  window.addEventListener("blur", function () { keys = Object.create(null); attackHeld = false; });
  window.addEventListener("resize", resize);
  resize();
  state = newState();
  updateLabels();
  draw(0);
  window.requestAnimationFrame(function (now) { lastTime = now; frame(now); });
}());
