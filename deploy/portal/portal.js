(function () {
	const grid = document.getElementById("grid");
	const year = document.getElementById("year");
	const stats = document.getElementById("stats");

	if (year) year.textContent = "© " + new Date().getFullYear();

	const arrow = '<svg viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';

	function escapeHtml(s) {
		return String(s)
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function renderStats(projects) {
		if (!stats) return;
		const live = projects.filter(function (p) { return p.enabled !== false; }).length;
		const total = projects.length;
		stats.innerHTML =
			'<span><span class="dot"></span>' + live + ' 个可访问</span>' +
			"<span>" + total + " 个项目</span>";
	}

	function render(projects) {
		if (!grid) return;
		renderStats(projects);
		grid.innerHTML = "";

		projects.forEach(function (p, i) {
			const enabled = p.enabled !== false;
			const accent = p.color || "#5eead4";
			const a = document.createElement("a");
			a.className = "card" + (enabled ? "" : " disabled");
			a.href = enabled ? String(p.path || "#") : "#";
			a.style.setProperty("--card-accent", accent);
			a.style.animationDelay = (i * 0.07) + "s";
			a.setAttribute("aria-label", String(p.title || "项目"));
			a.innerHTML =
				'<span class="tag">' + escapeHtml(String(p.tag || "项目")) + "</span>" +
				"<h2>" + escapeHtml(String(p.title || "")) + "</h2>" +
				"<p>" + escapeHtml(String(p.desc || "")) + "</p>" +
				'<span class="enter">' + (enabled ? "进入项目" : "即将上线") + arrow + "</span>";
			grid.appendChild(a);
		});
	}

	fetch("projects.json", { cache: "no-store" })
		.then(function (r) { return r.json(); })
		.then(render)
		.catch(function () {
			render([
				{ title: "OUR STORY", desc: "回忆馆", tag: "回忆馆", path: "/story/", color: "#f472b6", enabled: true },
				{ title: "Shell Survivor", desc: "生存射击游戏", tag: "游戏", path: "/game/", color: "#5eead4", enabled: true }
			]);
		});
})();
