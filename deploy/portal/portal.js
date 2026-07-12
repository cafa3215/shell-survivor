(function () {
	const grid = document.getElementById("grid");
	const year = document.getElementById("year");
	if (year) year.textContent = "© " + new Date().getFullYear();

	function render(projects) {
		if (!grid) return;
		grid.innerHTML = "";
		for (const p of projects) {
			const enabled = p.enabled !== false;
			const a = document.createElement("a");
			a.className = "card" + (enabled ? "" : " disabled");
			a.href = enabled ? String(p.path || "#") : "#";
			a.setAttribute("aria-label", String(p.title || "项目"));
			a.innerHTML =
				'<span class="tag">' + escapeHtml(String(p.tag || "项目")) + "</span>" +
				"<h2>" + escapeHtml(String(p.title || "")) + "</h2>" +
				"<p>" + escapeHtml(String(p.desc || "")) + "</p>" +
				'<span class="enter">' + (enabled ? "进入 →" : "即将上线") + "</span>";
			grid.appendChild(a);
		}
	}

	function escapeHtml(s) {
		return s
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	fetch("projects.json", { cache: "no-store" })
		.then(function (r) { return r.json(); })
		.then(render)
		.catch(function () {
			render([
				{ title: "OUR STORY", desc: "回忆馆", tag: "回忆馆", path: "/story/", enabled: true },
				{ title: "Shell Survivor", desc: "生存射击游戏", tag: "游戏", path: "/game/", enabled: true }
			]);
		});
})();
