// FRONTEND: carrossel e fetch do agendamentos

let slideIndex = 0;
const slides = document.querySelectorAll('.slide');

function showSlide(n) {
  slides.forEach((slide) => {
    slide.classList.remove('active');
  });

  slideIndex = (n + slides.length) % slides.length;
  slides[slideIndex].classList.add('active');
}

function plusSlides(n) {
  showSlide(slideIndex + n);
}

setInterval(() => {
  plusSlides(1);
}, 5000);

showSlide(slideIndex);