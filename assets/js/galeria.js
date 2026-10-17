// Lightbox da galeria.html: abre a foto ampliada num <dialog>.
// Sem JS, cada foto continua sendo um link para a imagem grande.
(() => {
	const grid = document.querySelector("[data-lightbox-grid]");
	if (!grid || typeof HTMLDialogElement !== "function") return;

	const links = [...grid.querySelectorAll(".photo-link")];
	const fotos = links.map((link) => {
		const img = link.querySelector("img");
		const legenda = link.closest("figure").querySelector("figcaption");
		return { src: link.href, alt: img.alt, legenda: legenda ? legenda.textContent : "" };
	});

	const dialog = document.createElement("dialog");
	dialog.className = "lightbox";
	dialog.setAttribute("aria-label", "Foto ampliada");
	dialog.innerHTML = `
		<figure class="lightbox-figure">
			<img class="lightbox-img" alt="">
			<figcaption class="lightbox-caption"><span class="lightbox-text"></span><span class="lightbox-count"></span></figcaption>
		</figure>
		<button type="button" class="lightbox-btn lightbox-close" data-acao="fechar">Fechar</button>
		<button type="button" class="lightbox-btn lightbox-prev" data-acao="anterior" aria-label="Foto anterior">‹</button>
		<button type="button" class="lightbox-btn lightbox-next" data-acao="proxima" aria-label="Próxima foto">›</button>
	`;
	document.body.append(dialog);

	const img = dialog.querySelector(".lightbox-img");
	const texto = dialog.querySelector(".lightbox-text");
	const contador = dialog.querySelector(".lightbox-count");
	let atual = 0;

	const mostrar = (indice) => {
		atual = (indice + fotos.length) % fotos.length;
		const foto = fotos[atual];
		img.src = foto.src;
		img.alt = foto.alt;
		texto.textContent = foto.legenda;
		contador.textContent = `${atual + 1} de ${fotos.length}`;
	};

	links.forEach((link, indice) => {
		link.addEventListener("click", (evento) => {
			evento.preventDefault();
			mostrar(indice);
			dialog.showModal();
		});
	});

	dialog.addEventListener("click", (evento) => {
		const acao = evento.target.dataset.acao;
		if (acao === "fechar" || evento.target === dialog) dialog.close();
		else if (acao === "anterior") mostrar(atual - 1);
		else if (acao === "proxima") mostrar(atual + 1);
	});

	dialog.addEventListener("keydown", (evento) => {
		if (evento.key === "ArrowLeft") mostrar(atual - 1);
		else if (evento.key === "ArrowRight") mostrar(atual + 1);
	});

	dialog.addEventListener("close", () => links[atual].focus());
})();
