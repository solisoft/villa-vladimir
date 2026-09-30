// Room photos open in a slideshow: click a photo, then arrows, keys or swipe.
//
// The page holds a <dialog id="slideshow"> listing its photos; every link with
// data-slideshow-index opens it at that photo. Listeners sit on the document,
// so they keep working after Soli's instant navigation swaps the page.
(function () {
  if (window.vvSlideshow) return;
  window.vvSlideshow = true;

  let current = 0;
  let slides = [];
  let touchStartX = null;

  function box() {
    return document.getElementById("slideshow");
  }

  function show(index) {
    const dialog = box();
    current = (index + slides.length) % slides.length;
    const slide = slides[current];
    const image = dialog.querySelector("[data-slideshow-image]");
    image.src = slide.src;
    image.alt = slide.alt;
    dialog.querySelector("[data-slideshow-caption]").textContent = slide.alt;
    dialog.querySelector("[data-slideshow-count]").textContent = current + 1 + " / " + slides.length;
    [current + 1, current - 1].forEach(function (neighbour) {
      new Image().src = slides[(neighbour + slides.length) % slides.length].src;
    });
  }

  function open(index) {
    const dialog = box();
    slides = Array.from(dialog.querySelectorAll("[data-slide]")).map(function (item) {
      return { src: item.dataset.src, alt: item.dataset.alt };
    });
    show(index);
    dialog.showModal();
  }

  document.addEventListener("click", function (event) {
    const link = event.target.closest("[data-slideshow-index]");
    const dialog = box();
    if (link && dialog) {
      event.preventDefault();
      open(Number(link.dataset.slideshowIndex));
      return;
    }
    if (!dialog || !dialog.open) return;
    if (event.target.closest("[data-slideshow-prev]")) show(current - 1);
    else if (event.target.closest("[data-slideshow-next]")) show(current + 1);
    else if (event.target.closest("[data-slideshow-close]") || event.target.hasAttribute("data-slideshow-stage")) {
      dialog.close();
    }
  });

  document.addEventListener("keydown", function (event) {
    const dialog = box();
    if (!dialog || !dialog.open) return;
    if (event.key === "ArrowLeft") show(current - 1);
    if (event.key === "ArrowRight") show(current + 1);
  });

  document.addEventListener("touchstart", function (event) {
    const dialog = box();
    touchStartX = dialog && dialog.open ? event.touches[0].clientX : null;
  }, { passive: true });

  document.addEventListener("touchend", function (event) {
    if (touchStartX === null) return;
    const distance = event.changedTouches[0].clientX - touchStartX;
    touchStartX = null;
    if (Math.abs(distance) > 40) show(distance < 0 ? current + 1 : current - 1);
  }, { passive: true });
})();
