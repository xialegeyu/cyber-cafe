const cafeScene = document.querySelector("#cafeScene");
const avatarLayers = document.querySelectorAll(".avatar-layer");
const seatAButton = document.querySelector("#seatAButton");
const seatBButton = document.querySelector("#seatBButton");
const standButton = document.querySelector("#standButton");

function setSeat(activeSeat) {
  cafeScene.dataset.activeSeat = activeSeat;

  avatarLayers.forEach((avatarLayer) => {
    const isSeatAAvatar = avatarLayer.classList.contains("seat-a-layer");
    const isSeatBAvatar = avatarLayer.classList.contains("seat-b-layer");
    const shouldShow =
      (activeSeat === "a" && isSeatAAvatar) ||
      (activeSeat === "b" && isSeatBAvatar);

    avatarLayer.classList.toggle("is-hidden", !shouldShow);
  });

  seatAButton.setAttribute("aria-pressed", String(activeSeat === "a"));
  seatBButton.setAttribute("aria-pressed", String(activeSeat === "b"));
  standButton.setAttribute("aria-pressed", String(activeSeat === "none"));
}

seatAButton.addEventListener("click", () => setSeat("a"));
seatBButton.addEventListener("click", () => setSeat("b"));
standButton.addEventListener("click", () => setSeat("none"));

setSeat("none");
